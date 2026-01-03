

//
//  MemoryEditorView.swift
//  i-cant-miss
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
        case create(space: SpaceModel?, template: MemoryEditorTemplate)
        case edit(memory: MemoryModel)
    }

    @Environment(\.dismiss) private var dismiss
    @StateObject var viewModel: MemoryEditorViewModel
    @State private var showDateAndTimeSheet = false

    @State private var showAddLinkSheet = false
    @State private var showLocationPicker = false
    @State private var showPersonSheet = false
    @State private var showSequentialSheet = false


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
    @State var isPhotoViewerPresented = false
    @State var selectedAttachmentIndex = 0
    @State var selectedPhotoContentID: UUID?
    @State private var filePreviewItem: FilePreviewItem?
    @State private var isShowingFilePreview = false
    @State private var isShowingAudioRecorder = false

    @State private var navigationPath = NavigationPath()

    @State private var showDeleteConfirmation = false
    @Namespace private var toolbarGlassNamespace
    @ObservedObject private var spaceService: SpaceService


    private let mode: Mode
    private let environment: AppEnvironment
    private let initialTitle: String

    init(environment: AppEnvironment, mode: Mode, initialTitle: String = "") {
        self.mode = mode
        self.environment = environment
        self.initialTitle = initialTitle
        self.spaceService = environment.spaceService
        switch mode {
        case let .create(space, template):
            _viewModel = StateObject(wrappedValue: MemoryEditorViewModel(
                environment: environment,
                attachmentStore: environment.attachmentStore,
                memory: nil,
                defaultSpace: space,
                template: template,
                initialTitle: initialTitle
            ))
            _isEditingEnabled = State(initialValue: true)
        case let .edit(memory):
            _viewModel = StateObject(wrappedValue: MemoryEditorViewModel(
                environment: environment,
                attachmentStore: environment.attachmentStore,
                memory: memory,
                defaultSpace: memory.space,
                template: .blank
            ))
            _isEditingEnabled = State(initialValue: true)
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
            .sheet(isPresented: $showDateAndTimeSheet, content: dateAndTimeSheet)
            .sheet(isPresented: $showAddLinkSheet, content: linkSheet)
            .sheet(isPresented: $showLocationPicker, content: locationSheet)
            .sheet(isPresented: $showPersonSheet, content: personSheet)
            .sheet(isPresented: $showSequentialSheet, content: sequentialSheet)
            .sheet(isPresented: $isShowingAudioRecorder) {
                AudioRecorderSheet(onSave: { data, url in
                    _ = viewModel.addAudioAttachment(data: data, sourceURL: url)
                })
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
            .onChange(of: viewModel.isPinned) { _, _ in
                handleMetadataSaveIfNeeded()
            }
            .onChange(of: viewModel.selectedSpaceID) { _, _ in
                handleMetadataSaveIfNeeded()
            }
            .onChange(of: viewModel.status) { _, _ in
                handleMetadataSaveIfNeeded()
            }
            .onChange(of: viewModel.autoCompleteChecklist) { _, _ in
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

    private var memoryLookup: [UUID: MemoryModel] {
        Dictionary(uniqueKeysWithValues: viewModel.environment.memoryService.memories.map { ($0.id, $0) })
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
        viewModel.isSaving || viewModel.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !viewModel.hasChanges
    }

    private var editorContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                titleSectionRow

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
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
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

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        viewModel.isPinned.toggle()
                    } label: {
                        Label(viewModel.isPinned ? "Unpin" : "Pin",
                              systemImage: viewModel.isPinned ? "pin.fill" : "pin")
                        .foregroundStyle(viewModel.isPinned ? Color.accentColor : .primary)
                    }
                    .accessibilityLabel(viewModel.isPinned ? "Unpin memory" : "Pin memory")



                    Section("Details") {
                        Picker(selection: $viewModel.status) {
                            ForEach(MemoryStatus.allCases) { status in
                                Text(status.rawValue.capitalized).tag(status)
                            }
                        } label: {
                            Label(viewModel.status.rawValue.capitalized, systemImage: "circle.circle")
                        }
                        .pickerStyle(.menu)
                    }

                } label: {
                    Image(systemName: "ellipsis")
                }
            }

            if case .edit = mode {
                ToolbarItemGroup(placement: .bottomBar) {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
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
                spaceService: spaceService,
                environment: environment,
                isTitleFocused: $isTitleFocused
            )

            triggersCard

            MemoryEditorNotesCard(
                viewModel: viewModel,
                isEditingEnabled: isEditingEnabled
            )

            MemoryEditorChecklistCard(
                viewModel: viewModel,
                isEditingEnabled: isEditingEnabled,
                focusedDraftID: $focusedDraftID
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .animation(.easeInOut(duration: 0.3), value: viewModel.triggers.count)
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

    private func presentPhotoViewerForFixedPhotos(at index: Int, clickedAttachment: MemoryModel.Attachment) {
        selectedAttachmentIndex = index
        selectedPhotoContentID = UUID()
        isPhotoViewerPresented = true
    }

    private var triggersCard: some View {
        TriggersCard(
            viewModel: viewModel,
            showDateAndTimeSheet: $showDateAndTimeSheet,
            showLocationPicker: $showLocationPicker,
            showPersonSheet: $showPersonSheet,
            showSequentialSheet: $showSequentialSheet,
            memoryLookup: memoryLookup
        )
    }




    // Simplified for fixed model - photos go directly to viewModel.photoAttachments
    private func handleCapturedImage(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.85) else { return }
        let _ = viewModel.addPhotoAttachment(data: data)
        isPresentingCamera = false
        pendingPhotoContentID = nil
        cleanupPendingContentTargets()
    }

    // Simplified for fixed model - links go directly to viewModel.linkAttachments
    func handleLinkAdded(_ url: URL) {
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

    private func presentFilePreview(for attachment: MemoryModel.Attachment) {
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
        Color(.systemBackground)
    }



    private var cardBounceAnimation: Animation {
        .interpolatingSpring(stiffness: 240, damping: 18, initialVelocity: 0.35)
    }

    private var cardBounceTransition: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.9, anchor: .center)
                .combined(with: .opacity),
            removal: .scale(scale: 0.75, anchor: .center)
                .combined(with: .opacity)
        )
    }

    private func handleAttachmentTap(_ attachment: MemoryModel.Attachment) {
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
    let environment = AppEnvironment(persistence: PersistenceController.preview)
    environment.bootstrap()
    return MemoryEditorView(environment: environment, mode: .create(space: nil, template: .blank))
}
