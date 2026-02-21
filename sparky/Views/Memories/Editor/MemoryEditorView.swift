

//
//  MemoryEditorView.swift
//  sparky
//
//  Created by Codex on 09/03/24.
//

import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import QuickLook
import Combine

struct MemoryEditorView: View {

    enum Mode {

        case create(mind: Mind?, template: MemoryEditorTemplate)

        case edit(memory: Memory)

    }



    @Environment(\.dismiss) private var dismiss

    @StateObject var viewModel: MemoryEditorViewModel



    @State private var showAddLinkSheet = false





    @State private var showErrorAlert = false



    @State private var isPresentingPhotoLibrary = false

    @State private var photoPickerItems: [PhotosPickerItem] = []

    @State private var isPresentingCamera = false

    @State private var photoLoadingContentIDs: Set<UUID> = []

    @State private var pendingPhotoContentID: UUID?

    @State private var pendingLinkContentID: UUID?

    @State private var isPresentingFileImporter = false

    @State private var pendingFileContentID: UUID?

    @State private var fileImportingContentIDs: Set<UUID> = []

    @FocusState private var focusedDraftID: UUID?

    @FocusState private var isTitleFocused: Bool

    @State private var isEditingEnabled: Bool

    @State private var isNotesOpen: Bool

    @State private var isChecklistOpen: Bool

    @State private var isMediaOpen: Bool

    @State var isPhotoViewerPresented = false

    @State var selectedAttachmentIndex = 0

    @State var selectedPhotoContentID: UUID?

    @State private var filePreviewItem: FilePreviewItem?

    @State private var isShowingFilePreview = false

    @State private var isShowingAudioRecorder = false

    @State private var audioAttachmentToPlay: Memory.Attachment?



    @State private var navigationPath = NavigationPath()



    @State private var showDeleteConfirmation = false

    @Namespace private var toolbarGlassNamespace

    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)





    private let mode: Mode

    private let environment: AppEnvironment

    private let initialTitle: String

    private let startEditing: Bool



    init(environment: AppEnvironment, mode: Mode, initialTitle: String = "", startEditing: Bool = false) {

        self.mode = mode

        self.environment = environment

        self.initialTitle = initialTitle

        self.startEditing = startEditing

        switch mode {

        case let .create(mind, template):

            let vm = MemoryEditorViewModel(

                environment: environment,

                attachmentStore: environment.attachmentStore,

                memory: nil,

                defaultMind: mind,

                template: template,

                initialTitle: initialTitle

            )

            _viewModel = StateObject(wrappedValue: vm)

            _isEditingEnabled = State(initialValue: true)

            _isNotesOpen = State(initialValue: !vm.note.isEmpty)

            _isChecklistOpen = State(initialValue: !vm.checkItems.isEmpty)

            _isMediaOpen = State(initialValue: vm.hasAnyAttachment)

        case let .edit(memory):

            let vm = MemoryEditorViewModel(

                environment: environment,

                attachmentStore: environment.attachmentStore,

                memory: memory,

                defaultMind: memory.mind,

                template: .blank

            )

            _viewModel = StateObject(wrappedValue: vm)

            _isEditingEnabled = State(initialValue: startEditing)

            _isNotesOpen = State(initialValue: !vm.note.isEmpty)

            _isChecklistOpen = State(initialValue: !vm.checkItems.isEmpty)

            _isMediaOpen = State(initialValue: vm.hasAnyAttachment)

        }

    }



    var body: some View {

        NavigationStack(path: $navigationPath) {

            editorStack

        }

    }



    private var editorStack: some View {

        let lifecycleConfigured = baseEditorContainer

            .scrollDismissesKeyboard(.interactively)

            .onAppear {

                Task {

                    await viewModel.loadLatestDataIfNeeded()

                }

            }

            .alert("Unable to save", isPresented: $showErrorAlert) {

                Button("OK", role: .cancel) {

                    viewModel.errorMessage = nil

                }

            } message: {

                if let errorMessage = viewModel.errorMessage {

                    Text(errorMessage)

                }

            }

            .onChange(of: viewModel.errorMessage) { _, newValue in

                showErrorAlert = newValue != nil

            }

            .alert("Delete Memory", isPresented: $showDeleteConfirmation) {

                Button("Cancel", role: .cancel) { }

                Button("Delete", role: .destructive) {

                    Task {

                        await deleteMemory()

                    }

                }

            } message: {

                Text("Are you sure you want to delete this memory? This action cannot be undone.")

            }



        let sheetConfigured = lifecycleConfigured

            .sheet(isPresented: $showAddLinkSheet, content: linkSheet)

            .sheet(isPresented: $isShowingAudioRecorder) {

                AudioRecorderSheet(onSave: { data, url in

                    feedbackGenerator.impactOccurred()

                    _ = viewModel.addAudioAttachment(data: data, sourceURL: url)

                })

            }

            .sheet(item: $audioAttachmentToPlay) { attachment in

                AudioPlayerSheet(audioData: attachment.data)

            }





        let attachmentConfigured = sheetConfigured

            .fullScreenCover(isPresented: $isPresentingCamera) {

                CameraCaptureView(

                    onCapture: { image in

                        handleCapturedImage(image)

                        isPresentingCamera = false

                    },

                    onCancel: {

                        isPresentingCamera = false

                    }

                )

                .ignoresSafeArea(.all)

            }

            .photosPicker(isPresented: $isPresentingPhotoLibrary,

                          selection: $photoPickerItems,

                          matching: .images)

            .fileImporter(isPresented: $isPresentingFileImporter,

                          allowedContentTypes: [.item],

                          allowsMultipleSelection: true) { result in

                switch result {

                case .success(let urls):

                    Task {

                        await importFiles(from: urls)

                    }

                case .failure:

                    pendingFileContentID = nil

                    isPresentingFileImporter = false

                    cleanupPendingContentTargets()

                }

            }

            .fullScreenCover(isPresented: $isPhotoViewerPresented) {

                photoViewerContent

            }

            .fullScreenCover(isPresented: $isShowingFilePreview) {

                if let item = filePreviewItem {

                    FilePreviewController(item: item)

                        .ignoresSafeArea()

                }

            }



        let stateChangeConfigured = attachmentConfigured

            .onChange(of: isPhotoViewerPresented) { _, isPresented in

                if !isPresented {

                    selectedPhotoContentID = nil

                    selectedAttachmentIndex = 0

                }

            }

            .onChange(of: photoPickerItems) { _, newItems in

                guard !newItems.isEmpty else { return }

                Task {

                    await loadSelectedPhotos(from: newItems)

                }

            }

            .onChange(of: isPresentingPhotoLibrary) { _, isPresented in

                if !isPresented {

                    let hadItems = !photoPickerItems.isEmpty

                    photoPickerItems = []

                    if photoLoadingContentIDs.isEmpty && !hadItems {

                        pendingPhotoContentID = nil

                    }

                    cleanupPendingContentTargets()

                }

            }

            .onChange(of: isShowingFilePreview) { _, isPresented in

                if !isPresented {

                    filePreviewItem = nil

                }

            }

            .onChange(of: isPresentingCamera) { _, isPresented in

                if !isPresented {

                    if photoLoadingContentIDs.isEmpty {

                        pendingPhotoContentID = nil

                    }

                    cleanupPendingContentTargets()

                }

            }

            .onChange(of: isPresentingFileImporter) { _, isPresented in

                if !isPresented {

                    cleanupPendingContentTargets()

                }

            }

            .onChange(of: showAddLinkSheet) { _, isPresented in

                if !isPresented {

                    cleanupPendingContentTargets()

                }

            }



        let metadataSaveConfigured = stateChangeConfigured

            .onChange(of: viewModel.checkItems) { _, _ in

                handleMetadataSaveIfNeeded()

            }



        return metadataSaveConfigured



    }



    private func handleMetadataSaveIfNeeded() {

        guard !isEditingEnabled else { return }

        Task {

            await viewModel.saveMetadataOnly()

        }

    }



    private func deleteMemory() async {

        guard case let .edit(memory) = mode else { return }

        do {

            try await environment.memoryService.deleteMemory(id: memory.id)

            await MainActor.run {

                dismiss()

            }

        } catch {

            await MainActor.run {

                viewModel.errorMessage = "Failed to delete memory: \(error.localizedDescription)"

            }

        }

    }





    private var baseEditorContainer: some View {

        ZStack {

            baseBackground

                .ignoresSafeArea()



            editorContent

                .safeAreaInset(edge: .bottom) {

                    Color.clear.frame(height: 20)

                }

        }

    }



    private var navigationTitle: String {

        switch mode {

        case .create:

            return "New Memory"

        case .edit:

            return "Edit Memory"

        }

    }



    private var saveButtonTitle: String {

        switch mode {

        case .create:

            return "Create"

        case .edit:

            return "Save"

        }

    }



    private var isSaveDisabled: Bool {

        viewModel.isSaving
            || viewModel.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || viewModel.checkItems.contains(where: { $0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })

    }



    private var editorContent: some View {

        ScrollView {

            VStack(spacing: 12) {

                titleSectionRow



                if isEditingEnabled || viewModel.hasAnyAttachment {

                    VStack(spacing: 0) {

                        if isEditingEnabled {

                            sectionToggleHeader(

                                title: "Media",

                                icon: "photo",

                                isOn: mediaToggleBinding

                            )

                        }

                        if !isEditingEnabled || isMediaVisible {

                            if isEditingEnabled {

                                Divider().padding(.horizontal, 16)

                            }

                            MemoryEditorAttachmentsCard(

                                viewModel: viewModel,

                                isEditable: isEditingEnabled,

                                onAddPhoto: { addPhotosFromLibraryFixed() },

                                onAddCamera: { addPhotosFromCameraFixed() },

                                onAddLink: {

                                    pendingLinkContentID = nil

                                    showAddLinkSheet = true

                                },

                                onAddAudio: { isShowingAudioRecorder = true },

                                onAddFile: { beginFileImportFixed() },

                                onAttachmentTap: { attachment in

                                    handleAttachmentTap(attachment)

                                }

                            )

                        }

                    }

                    .cardStyle(cornerRadius: 24)

                    .padding(.horizontal, 20)

                    .transition(.opacity.combined(with: .move(edge: .top)))

                }

            }

            .padding(.bottom, 20)

        }

        .toolbar{

            ToolbarItem(placement: .cancellationAction) {

                Button(role: .cancel) {

                    dismiss()

                } label: {

                    Label("Cancel", systemImage: "xmark")

                }

            }



            ToolbarItem(placement: .confirmationAction) {

                if case .create = mode {

                    Button(role: .confirm) {

                        Task {

                            let success = await viewModel.save()

                            if success {

                                await MainActor.run {

                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

                                    isTitleFocused = false

                                    focusedDraftID = nil

                                    dismiss()

                                }

                            }

                        }

                    } label: {

                        Label(saveButtonTitle, systemImage: "checkmark")

                    }

                    .disabled(isSaveDisabled)

                }

            }



            ToolbarItemGroup(placement: .topBarTrailing) {

                if case .edit = mode {

                    if isEditingEnabled {

                    Button {

                        feedbackGenerator.impactOccurred()

                        viewModel.isPinned.toggle()

                    } label: {

                        Label(viewModel.isPinned ? "Unpin" : "Pin",

                              systemImage: viewModel.isPinned ? "pin.fill" : "pin")

                        .foregroundStyle(viewModel.isPinned ? Color.accentColor : .primary)

                    }

                    .accessibilityLabel(viewModel.isPinned ? "Unpin memory" : "Pin memory")



                    // Checkmark button: Save and switch to View

                    Button {

                        // Optimistic UI: Switch to View mode immediately

                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

                        isTitleFocused = false

                            focusedDraftID = nil

                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {

                                isEditingEnabled = false

                            }



                            // Perform save in background

                            Task {

                                _ = await viewModel.save()

                            }

                        } label: {

                            Label("Save", systemImage: "checkmark")

                        }

                        .disabled(isSaveDisabled)

                    } else {

                        // Pencil button: Switch to Edit

                        Button {

                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {

                                isEditingEnabled = true

                            }

                        } label: {

                            Label("Edit", systemImage: "pencil")

                        }

                    }

                }

            }







            if case .edit = mode, isEditingEnabled {

                ToolbarItemGroup(placement: .bottomBar) {

                    Button(role: .destructive) {

                        showDeleteConfirmation = true

                    } label: {

                        Image(systemName: "trash")

                            .foregroundStyle(.red)

                    }

                    Spacer()

                    Button {

                        feedbackGenerator.impactOccurred()

                        viewModel.toggleStatus()

                    } label: {

                        Label(viewModel.status.rawValue.capitalized, systemImage: viewModel.status == .active ? "circle" : "checkmark.circle.fill")

                            .labelStyle(.titleAndIcon)

                    }

                }

            }

            if case .edit = mode, !isEditingEnabled {

                ToolbarItemGroup(placement: .bottomBar) {

                    Spacer()

                    Button {

                        feedbackGenerator.impactOccurred()

                        viewModel.toggleStatus()

                        Task {

                            await viewModel.saveMetadataOnly()

                        }

                    } label: {

                        Label(viewModel.status.rawValue.capitalized, systemImage: viewModel.status == .active ? "circle" : "checkmark.circle.fill")

                            .labelStyle(.titleAndIcon)

                    }

                    Spacer()

                }

            }

        }

        .scrollContentBackground(.hidden)

        .scrollIndicators(.hidden)

        .background(Color.clear)





    }



    private var titleSectionRow: some View {

        VStack(alignment: .leading, spacing: 12) {

            MemoryEditorTitleCard(

                viewModel: viewModel,

                environment: environment,

                isTitleFocused: $isTitleFocused,

                isEditingEnabled: isEditingEnabled

            )

            if isEditingEnabled || !viewModel.note.isEmpty {

                VStack(spacing: 0) {

                    if isEditingEnabled {

                        sectionToggleHeader(

                            title: "Notes",

                            icon: "note.text",

                            isOn: notesToggleBinding

                        )

                    }

                    if !isEditingEnabled || isNotesVisible {

                        if isEditingEnabled {

                            Divider().padding(.horizontal, 16)

                        }

                        MemoryEditorNotesCard(

                            viewModel: viewModel,

                            isEditingEnabled: isEditingEnabled

                        )

                    }

                }

                .cardStyle(cornerRadius: 24)

                .transition(.opacity.combined(with: .move(edge: .top)))

            }

            if isEditingEnabled || !viewModel.checkItems.isEmpty {

                VStack(spacing: 0) {

                    if isEditingEnabled {

                        sectionToggleHeader(

                            title: "Checklist",

                            icon: "checklist",

                            isOn: checklistToggleBinding

                        )

                    }

                    if !isEditingEnabled || isChecklistVisible {

                        if isEditingEnabled {

                            Divider().padding(.horizontal, 16)

                        }

                        MemoryEditorChecklistCard(

                            viewModel: viewModel,

                            isEditingEnabled: isEditingEnabled,

                            focusedDraftID: $focusedDraftID

                        )

                    }

                }

                .cardStyle(cornerRadius: 24)

                .transition(.opacity.combined(with: .move(edge: .top)))

            }


            if isEditingEnabled || viewModel.hasAnyTrigger {

                triggersCard

                    .transition(.opacity.combined(with: .move(edge: .top)))

            }
            


        }

        .padding(.horizontal, 20)

        .padding(.top, 20)

        .animation(.easeInOut(duration: 0.3), value: viewModel.hasAnyTrigger)

    }



    // MARK: - Fixed Content Card Views



    private func addPhotosFromLibraryFixed() {

        pendingPhotoContentID = UUID() // Use temporary ID for triggering

        isPresentingPhotoLibrary = true

    }



    private func addPhotosFromCameraFixed() {

        pendingPhotoContentID = UUID()

        isPresentingCamera = true

    }



    private func beginFileImportFixed() {

        pendingFileContentID = UUID()

        isPresentingFileImporter = true

    }



    private func presentPhotoViewerForFixedPhotos(at index: Int, clickedAttachment: Memory.Attachment) {

        selectedAttachmentIndex = index

        selectedPhotoContentID = UUID()

        isPhotoViewerPresented = true

    }



    private var triggersCard: some View {

        TriggersCard(

            viewModel: viewModel,

            isEditable: isEditingEnabled

        )

    }



    // MARK: - Section Toggle Helpers



    private var isNotesVisible: Bool {

        isNotesOpen || !viewModel.note.isEmpty

    }



    private var isChecklistVisible: Bool {

        isChecklistOpen || !viewModel.checkItems.isEmpty

    }



    private var isMediaVisible: Bool {

        isMediaOpen || viewModel.hasAnyAttachment

    }



    private func sectionToggleHeader(title: String, icon: String, isOn: Binding<Bool>) -> some View {

        HStack {

            Label(title, systemImage: icon)

                .font(.body)

                .fontWeight(.medium)

            Spacer()

            Toggle("", isOn: isOn)

                .labelsHidden()

        }

        .padding(.horizontal, 16)

        .padding(.vertical, 12)

    }



    private var notesToggleBinding: Binding<Bool> {

        Binding(

            get: { isNotesVisible },

            set: { newValue in

                withAnimation(.easeInOut(duration: 0.3)) {

                    isNotesOpen = newValue

                    if !newValue {

                        viewModel.note = ""

                    }

                }

            }

        )

    }



    private var checklistToggleBinding: Binding<Bool> {

        Binding(

            get: { isChecklistVisible },

            set: { newValue in

                withAnimation(.easeInOut(duration: 0.3)) {

                    isChecklistOpen = newValue

                    if newValue && viewModel.checkItems.isEmpty {

                        viewModel.addChecklistItem(title: "")

                    }

                    if !newValue {

                        viewModel.checkItems.removeAll()

                    }

                }

            }

        )

    }



    private var mediaToggleBinding: Binding<Bool> {

        Binding(

            get: { isMediaVisible },

            set: { newValue in

                withAnimation(.easeInOut(duration: 0.3)) {

                    isMediaOpen = newValue

                    if !newValue {

                        viewModel.photoAttachments.removeAll()

                        viewModel.linkAttachments.removeAll()

                        viewModel.audioAttachments.removeAll()

                        viewModel.fileAttachments.removeAll()

                    }

                }

            }

        )

    }









    // Simplified for fixed model - photos go directly to viewModel.photoAttachments

    private func handleCapturedImage(_ image: UIImage) {

        guard let data = image.jpegData(compressionQuality: 0.85) else { return }

        feedbackGenerator.impactOccurred()

        let _ = viewModel.addPhotoAttachment(data: data)

        isPresentingCamera = false

        pendingPhotoContentID = nil

        cleanupPendingContentTargets()

    }



    // Simplified for fixed model - links go directly to viewModel.linkAttachments

    func handleLinkAdded(_ url: URL) {

        feedbackGenerator.impactOccurred()

        let _ = viewModel.addLinkAttachment(url: url)

        pendingLinkContentID = nil

        cleanupPendingContentTargets()

    }



    private func beginFileImport(to contentID: UUID?) {

        guard isEditingEnabled else { return }

        pendingFileContentID = contentID

        isPresentingFileImporter = true

        filePreviewItem = nil

        isShowingFilePreview = false

    }







    // Simplified for fixed model - files go directly to viewModel.fileAttachments

    private func importFiles(from urls: [URL]) async {

        guard !urls.isEmpty else {

            await MainActor.run {

                isPresentingFileImporter = false

                pendingFileContentID = nil

                cleanupPendingContentTargets()

            }

            return

        }



        for url in urls {

            let hasAccess = url.startAccessingSecurityScopedResource()

            defer {

                if hasAccess {

                    url.stopAccessingSecurityScopedResource()

                }

            }



            guard let data = try? Data(contentsOf: url) else { continue }

            await MainActor.run {

                feedbackGenerator.impactOccurred()

                let _ = viewModel.addFileAttachment(

                    data: data,

                    filename: url.lastPathComponent,

                    sourceURL: url

                )

            }

        }



        await MainActor.run {

            isPresentingFileImporter = false

            pendingFileContentID = nil

            cleanupPendingContentTargets()

        }

    }



    private func presentFilePreview(for attachment: Memory.Attachment) {

        guard !attachment.data.isEmpty else { return }

        let tempURL = FileManager.default.temporaryDirectory

            .appendingPathComponent("\(attachment.id.uuidString)_preview_\(attachment.filename ?? "file")")



        do {

            try attachment.data.write(to: tempURL, options: .atomic)

            filePreviewItem = FilePreviewItem(url: tempURL)

            isShowingFilePreview = true

        } catch {

            filePreviewItem = nil

            isShowingFilePreview = false

        }

    }



    // Simplified for fixed model - using viewModel.photoAttachments directly





    // Simplified for fixed model - photos go directly to viewModel.photoAttachments

    private func loadSelectedPhotos(from items: [PhotosPickerItem]) async {

        for item in items {

            do {

                if let image = try await item.loadTransferable(type: PhotoPickerLoadedImage.self) {

                    await MainActor.run {

                        feedbackGenerator.impactOccurred()

                        let _ = viewModel.addPhotoAttachment(data: image.data)

                    }

                }

            } catch {

                continue

            }

        }



        await MainActor.run {

            photoPickerItems = []

            photoLoadingContentIDs.removeAll()

            isPresentingPhotoLibrary = false

            pendingPhotoContentID = nil

            cleanupPendingContentTargets()

        }

    }



    // MARK: - Obsolete binding helpers removed - now using direct bindings to viewModel fixed properties



    // Simplified for fixed model - no longer need contentID-based lookups



    private func cleanupPendingContentTargets() {

        // Simplified cleanup for fixed content model

        // No longer need to track multiple content IDs - just reset pending states

        if let pendingPhotoID = pendingPhotoContentID,

           !isPresentingPhotoLibrary,

           !isPresentingCamera,

           !photoLoadingContentIDs.contains(pendingPhotoID),

           photoPickerItems.isEmpty {

            // Only clear if we're not in the middle of adding photos

            pendingPhotoContentID = nil

        }



        if let _ = pendingLinkContentID, !showAddLinkSheet {

            pendingLinkContentID = nil

        }



        if let _ = pendingFileContentID, !isPresentingFileImporter {

            pendingFileContentID = nil

        }

    }



    private func cleanupPendingContentTargetsAfterAttachment(for contentID: UUID, didAddAttachment: Bool) {

        photoLoadingContentIDs.remove(contentID)

        photoPickerItems = []

        isPresentingPhotoLibrary = false



        if pendingPhotoContentID == contentID {

            pendingPhotoContentID = nil

        }



        cleanupPendingContentTargets()

    }



    private var baseBackground: Color {

        Color.Theme.secondaryBackground

    }



    private func handleAttachmentTap(_ attachment: Memory.Attachment) {

        switch attachment.kind {

        case .photo:

            if let index = viewModel.photoAttachments.firstIndex(where: { $0.id == attachment.id }) {

                presentPhotoViewerForFixedPhotos(at: index, clickedAttachment: attachment)

            }

        case .link:

            if let url = attachment.url {

                 UIApplication.shared.open(url)

            }

        case .file:

            presentFilePreview(for: attachment)

        case .audio:

            audioAttachmentToPlay = attachment

        default: break

        }

    }

}



private struct EditingSwipeActionModifier: ViewModifier {

    let isEnabled: Bool

    let title: String

    let systemImage: String

    let accessibilityLabel: String

    let action: () -> Void



    @ViewBuilder

    func body(content: Content) -> some View {

        if isEnabled {

            content

                .swipeActions(edge: .trailing, allowsFullSwipe: true) {

                    Button(role: .destructive, action: action) {

                        Label(title, systemImage: systemImage)

                    }

                    .accessibilityLabel(accessibilityLabel)

                }

        } else {

            content

        }

    }

}



#Preview {

    let environment = AppEnvironment(dataController: DataController.preview)

    environment.bootstrap()

    return MemoryEditorView(environment: environment, mode: .create(mind: nil, template: .blank))

}
