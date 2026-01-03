

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
    @StateObject private var viewModel: MemoryEditorViewModel
    @State private var showDateAndTimeSheet = false

    @State private var showAddLinkSheet = false
    @State private var showLocationPicker = false
    @State private var showPersonSheet = false
    @State private var showSequentialSheet = false

    @State private var showPhotoOptionsSheet = false
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
    @State private var isPhotoViewerPresented = false
    @State private var selectedAttachmentIndex = 0
    @State private var selectedPhotoContentID: UUID?
    @State private var filePreviewItem: FilePreviewItem?
    @State private var isShowingFilePreview = false
    @State private var isAudioCardVisible = false
    @State private var navigationPath = NavigationPath()
    @State private var showSpaceComposer = false
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
            .sheet(isPresented: $showPhotoOptionsSheet, content: photoOptionsSheet)

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
        List {
            titleSectionRow

            if shouldShowPhotosCard {
                photosCardView
                    .transition(cardBounceTransition)
            }

            if shouldShowLinksCard {
                linksCardView
                    .transition(cardBounceTransition)
            }

            if shouldShowAudioCard {
                audioCardView
                    .transition(cardBounceTransition)
            }

            if shouldShowFilesCard {
                filesCardView
                    .transition(cardBounceTransition)
            }
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

                    Section("Attachments") {
                        Button {
                            showPhotoOptionsSheet = true
                        } label: {
                            Label("Add Photo", systemImage: "photo")
                        }
                        .disabled(!isPhotoActionsEnabled)

                        Button {
                            handleAddContentSelection(.links)
                        } label: {
                            Label("Add Link", systemImage: MemoryEditorContentType.links.iconName)
                        }

                        Button {
                            handleAddContentSelection(.files)
                        } label: {
                            Label("Add File", systemImage: MemoryEditorContentType.files.iconName)
                        }
                        .disabled(viewModel.isSaving || isPresentingFileImporter || !fileImportingContentIDs.isEmpty)

                        Button {
                            handleAddContentSelection(.audio)
                        } label: {
                            Label("Add Audio", systemImage: MemoryEditorContentType.audio.iconName)
                        }
                    }

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
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .background(Color.clear)
        .listSectionSpacing(0)
        .listRowSeparator(.hidden)
        .environment(\.defaultMinListRowHeight, 0)
        .animation(cardBounceAnimation, value: shouldShowChecklistCard)
        .animation(cardBounceAnimation, value: shouldShowRichTextCard)
        .animation(cardBounceAnimation, value: shouldShowPhotosCard)
        .animation(cardBounceAnimation, value: shouldShowLinksCard)
        .animation(cardBounceAnimation, value: shouldShowFilesCard)
        .animation(cardBounceAnimation, value: shouldShowAudioCard)
    }

    private var titleSectionRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            titleCard

            triggersCard

            if shouldShowRichTextCard {
                notesCard
            }

            if shouldShowChecklistCard {
                checklistCard
            }
        }
        .padding(.horizontal, 20)
        .listRowSeparator(.hidden)
        .listRowInsets(.init(top: 20, leading: 0, bottom: 16, trailing: 0))
        .listRowBackground(Color.clear)
        .animation(.easeInOut(duration: 0.3), value: viewModel.triggers.count)
    }

    // MARK: - Fixed Content Card Views

    private var noteCard: some View {
        MemoryEditorRichTextCard(
            text: $viewModel.note,
            isEditable: isEditingEnabled
        )
        .padding(.horizontal, 20)
        .listRowSeparator(.hidden)
        .listRowInsets(.init(top: 0, leading: 0, bottom: 16, trailing: 0))
        .listRowBackground(Color.clear)
    }





    private var photosCardView: some View {
        MemoryEditorPhotosCard(
            attachments: $viewModel.photoAttachments,
            isLoading: isLoadingPhotos,
            isEditable: isEditingEnabled,
            onRemoveAttachment: { id in
                viewModel.removePhotoAttachment(id: id)
            },
            onAttachmentTap: { index, attachment in
                presentPhotoViewerForFixedPhotos(at: index, clickedAttachment: attachment)
            },
            onAddFromLibrary: { addPhotosFromLibraryFixed() },
            onAddFromCamera: { addPhotosFromCameraFixed() },
            isAddMenuEnabled: true
        )
        .padding(.horizontal, 20)
        .listRowSeparator(.hidden)
        .listRowInsets(.init(top: 0, leading: 0, bottom: 16, trailing: 0))
        .listRowBackground(Color.clear)
    }

    private var linksCardView: some View {
        MemoryEditorLinksCard(
            links: $viewModel.linkAttachments,
            isEditable: isEditingEnabled,
            onRemoveLink: { id in
                viewModel.removeLinkAttachment(id: id)
            }
        )
        .padding(.horizontal, 20)
        .listRowSeparator(.hidden)
        .listRowInsets(.init(top: 0, leading: 0, bottom: 16, trailing: 0))
        .listRowBackground(Color.clear)
    }

    private var audioCardView: some View {
        MemoryEditorAudioCard(
            clips: $viewModel.audioAttachments,
            isEditable: isEditingEnabled,
            onAddClip: { data, url in
                _ = viewModel.addAudioAttachment(data: data, sourceURL: url)
            },
            onRemoveClip: { id in
                viewModel.removeAudioAttachment(id: id)
            }
        )
        .padding(.horizontal, 20)
        .listRowSeparator(.hidden)
        .listRowInsets(.init(top: 0, leading: 0, bottom: 16, trailing: 0))
        .listRowBackground(Color.clear)
    }

    private var filesCardView: some View {
        MemoryEditorFilesCard(
            files: $viewModel.fileAttachments,
            isEditable: isEditingEnabled,
            isImporting: isImportingFiles,
            onImport: { beginFileImportFixed() },
            onRemove: { id in
                viewModel.removeFileAttachment(id: id)
            },
            onPreview: { presentFilePreview(for: $0) }
        )
        .padding(.horizontal, 20)
        .listRowSeparator(.hidden)
        .listRowInsets(.init(top: 0, leading: 0, bottom: 16, trailing: 0))
        .listRowBackground(Color.clear)
    }



    private var isLoadingPhotos: Bool {
        !photoLoadingContentIDs.isEmpty
    }

    private var isImportingFiles: Bool {
        !fileImportingContentIDs.isEmpty
    }



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


    // MARK: - Title Card (Independent)

    private var titleCard: some View {
        HStack(alignment: .center, spacing: 12) {
            Menu {
                Picker("Space", selection: $viewModel.selectedSpaceID) {
                    Label("No Space", systemImage: "square.grid.2x2")
                        .tag(nil as UUID?)

                    ForEach(spacesForPicker) { space in
                        Label(space.name, systemImage: space.iconName ?? "square.grid.2x2")
                            .tag(Optional(space.id))
                    }
                }

                Divider()

                Button {
                    showSpaceComposer = true
                } label: {
                    Label("Create New Space", systemImage: "plus.circle")
                }
            } label: {
                Image(systemName: viewModel.selectedSpace?.iconName ?? "square.grid.2x2")
                    .foregroundStyle(selectedSpaceColor)
                    .frame(width: 36, height: 36)
                    .glassEffect(.regular.tint(selectedSpaceColor.opacity(0.15)))
            }
            .sheet(isPresented: $showSpaceComposer) {
                SpaceComposerView(environment: environment)
            }

            TextField("Memory", text: $viewModel.title, axis: .vertical)
                .font(.custom("Vollkorn-Regular", size: 20))
                .multilineTextAlignment(.leading)
                .submitLabel(.done)
                .focused($isTitleFocused)
                .onSubmit {
                    isTitleFocused = false
                }
                .onChange(of: viewModel.title) { _, newValue in
                    guard newValue.contains(where: { $0.isNewline }) else { return }
                    let sanitized = newValue
                        .split(whereSeparator: \.isNewline)
                        .joined(separator: " ")
                    if sanitized != newValue {
                        viewModel.title = sanitized
                    }
                    DispatchQueue.main.async {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        isTitleFocused = false
                    }
                }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }

    // MARK: - Notes Card

    private var notesCard: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $viewModel.note)
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled(false)
                .frame(minHeight: 120)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .disabled(!isEditingEnabled)
                .scrollContentBackground(.hidden)
                .background(Color.clear)

            if viewModel.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(isEditingEnabled ? "Write something memorable…" : "No notes captured for this memory.")
                    .foregroundStyle(Color(uiColor: .placeholderText))
                    .padding(.top, 16)
                    .padding(.horizontal, 16)
                    .allowsHitTesting(false)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }

    // MARK: - Checklist Card

    private var checklistCard: some View {
        VStack(spacing: 12) {
             ForEach($viewModel.checkItems) { $item in
                SynapseView(
                    item: $item,
                    isEditable: isEditingEnabled,
                    onToggle: { viewModel.toggleChecklistCompletion(for: item.id) },
                    onDelete: { viewModel.removeChecklistItem(itemID: item.id) },
                    focusedField: $focusedDraftID
                )
            }
            .onMove { source, destination in
                viewModel.moveChecklistItem(from: source, to: destination)
            }

            if isEditingEnabled {
                AddSynapseButton {
                     viewModel.addChecklistItem(title: "", detail: "")
                     focusedDraftID = viewModel.checkItems.last?.id
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }

    // MARK: - Obsolete card functions removed - now using fixed card views (noteCard, checklistCardView, etc.)

    // Removed: addRichTextButton and addChecklistButton - these are now always visible as fixed cards

    private var addLinkButton: some View {
        Button {
            handleAddContentSelection(.links)
        } label: {
            Image(systemName:  MemoryEditorContentType.links.iconName)
                .font(.system(size: 20, weight: .semibold))
                .frame(width: 48, height: 48)
                .glassEffect(.regular.interactive())
                .glassEffectUnion(id: "editorToolbar", namespace: toolbarGlassNamespace)
                .foregroundStyle(!viewModel.linkAttachments.isEmpty ? Color.accentColor : .primary)
        }
        .accessibilityLabel("Add link")
    }

    private var addFilesButton: some View {
        Button {
            handleAddContentSelection(.files)
        } label: {
            Image(systemName: MemoryEditorContentType.files.iconName)
                .font(.system(size: 20, weight: .semibold))
                .frame(width: 48, height: 48)
                .glassEffect(.regular.interactive())
                .glassEffectUnion(id: "editorToolbar", namespace: toolbarGlassNamespace)
                .foregroundStyle(!viewModel.fileAttachments.isEmpty ? Color.accentColor : .primary)
        }
        .disabled(viewModel.isSaving || isPresentingFileImporter || !fileImportingContentIDs.isEmpty)
        .accessibilityLabel("Add files")
    }

    private var addAudioButton: some View {
        Button {
            handleAddContentSelection(.audio)
        } label: {
            Image(systemName: MemoryEditorContentType.audio.iconName)
                .font(.system(size: 20, weight: .semibold))
                .frame(width: 48, height: 48)
                .glassEffect(.regular.interactive())
                .glassEffectUnion(id: "editorToolbar", namespace: toolbarGlassNamespace)
                .foregroundStyle(!viewModel.audioAttachments.isEmpty ? Color.accentColor : .primary)
        }
        .accessibilityLabel("Add audio")
    }

    private var addPhotoMenuButton: some View {
        Button {
            showPhotoOptionsSheet = true
        } label: {
            Image(systemName: "photo")
                .font(.system(size: 20, weight: .semibold))
                .frame(width: 48, height: 48)
                .glassEffect(.regular.interactive())
                .glassEffectUnion(id: "editorToolbar", namespace: toolbarGlassNamespace)
                .foregroundStyle(photoToolbarForegroundColor)
        }
        .disabled(!isPhotoActionsEnabled)
        .accessibilityLabel("Add photo")
    }

    private var photoToolbarForegroundColor: Color {
        guard isPhotoActionsEnabled else { return .secondary }
        return !viewModel.photoAttachments.isEmpty ? Color.accentColor : Color.primary
    }

    private var isPhotoActionsEnabled: Bool {
        !viewModel.isSaving && pendingPhotoContentID == nil && photoLoadingContentIDs.isEmpty
    }

    private func canAddPhotos() -> Bool {
        guard isEditingEnabled else { return false }
        guard !viewModel.isSaving else { return false }
        guard pendingPhotoContentID == nil else { return false }
        guard !isPresentingPhotoLibrary && !isPresentingCamera else { return false }
        guard photoLoadingContentIDs.isEmpty else { return false }
        return true
    }

    // Simplified for fixed content model - content types are always available as fixed sections
    private func handleAddContentSelection(_ type: MemoryEditorContentType) {
        guard isEditingEnabled else { return }
        switch type {
        case .richText:
            // Note section is always shown via fixed card
            break
        case .checklist:
            // Add a new Synapse item
            viewModel.addChecklistItem(title: "", detail: "")
            focusedDraftID = viewModel.checkItems.last?.id
        case .photos:
            pendingPhotoContentID = nil
            isPresentingPhotoLibrary = true
        case .links:
            pendingLinkContentID = nil
            showAddLinkSheet = true
        case .audio:
            // Show the audio card when toolbar button is tapped
            withAnimation(cardBounceAnimation) {
                isAudioCardVisible = true
            }
        case .files:
            pendingFileContentID = nil
            beginFileImportFixed()
        }
    }


    private func handleCameraToolbarTap() {
        guard isEditingEnabled else { return }
        pendingPhotoContentID = nil
        isPresentingCamera = true
    }

    private func handleLibraryToolbarTap() {
        guard isEditingEnabled else { return }
        pendingPhotoContentID = nil
        isPresentingPhotoLibrary = true
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
    private func handleLinkAdded(_ url: URL) {
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
    private func presentPhotoViewer(at index: Int, clickedAttachment: MemoryModel.Attachment) {
        guard index >= 0 else { return }

        isPhotoViewerPresented = false
        selectedPhotoContentID = nil
        selectedAttachmentIndex = 0

        let rawAttachments = viewModel.photoAttachments
        guard !rawAttachments.isEmpty else { return }
        guard rawAttachments.indices.contains(index) else { return }

        let flattenedAttachments = flattenAttachments(rawAttachments)
        guard !flattenedAttachments.isEmpty else { return }

        let safeIndex: Int
        if let flattenedIndex = flattenedAttachments.firstIndex(where: { $0.id == clickedAttachment.id }) {
            safeIndex = flattenedIndex
        } else {
            safeIndex = min(max(0, index), flattenedAttachments.count - 1)
        }

        guard flattenedAttachments.indices.contains(safeIndex) else { return }

        selectedPhotoContentID = UUID()
        selectedAttachmentIndex = safeIndex
        isPhotoViewerPresented = true
    }

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

    private var spacesForPicker: [SpaceModel] {
        spaceService.spaces
    }

    private var selectedSpaceColor: Color {
        if let hex = viewModel.selectedSpace?.colorHex,
           let color = Color(hex: hex) {
            return color
        }
        return .gray
    }

    private var baseBackground: Color {
        Color(.systemBackground)
    }



    private var shouldShowRichTextCard: Bool {
        !viewModel.note.isEmpty || isEditingEnabled
    }

    private var shouldShowChecklistCard: Bool {
        !viewModel.checkItems.isEmpty || isEditingEnabled
    }

    private var shouldShowPhotosCard: Bool {
        !viewModel.photoAttachments.isEmpty
    }

    private var shouldShowLinksCard: Bool {
        !viewModel.linkAttachments.isEmpty
    }

    private var shouldShowFilesCard: Bool {
        !viewModel.fileAttachments.isEmpty
    }

    private var shouldShowAudioCard: Bool {
        !viewModel.audioAttachments.isEmpty || isAudioCardVisible
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





    @ViewBuilder
    private var photoViewerContent: some View {
        let attachments = getPhotoAttachmentsForViewer()
        Group {
            if !attachments.isEmpty {
                let safeIndex = min(max(selectedAttachmentIndex, 0), attachments.count - 1)
                MemoryEditorPhotoCarouselView(
                    attachments: attachments,
                    initialIndex: safeIndex
                ) {
                    isPhotoViewerPresented = false
                    selectedPhotoContentID = nil
                    selectedAttachmentIndex = 0
                }
            } else {
                photoViewerErrorView
            }
        }
        .onAppear {
            let attachments = getPhotoAttachmentsForViewer()
            if attachments.isEmpty {
                isPhotoViewerPresented = false
                selectedPhotoContentID = nil
                selectedAttachmentIndex = 0
            } else {
                let safeIndex = min(max(selectedAttachmentIndex, 0), attachments.count - 1)
                if safeIndex != selectedAttachmentIndex {
                    selectedAttachmentIndex = safeIndex
                }
            }
        }
    }

    // Simplified for fixed model - using viewModel.photoAttachments directly
    private func getPhotoAttachmentsForViewer() -> [MemoryModel.Attachment] {
        let rawAttachments = viewModel.photoAttachments
        guard !rawAttachments.isEmpty else { return [] }
        return flattenAttachments(rawAttachments)
    }

    private func flattenAttachments(_ attachments: [MemoryModel.Attachment]) -> [MemoryModel.Attachment] {
        attachments.filter { $0.kind == .photo && !$0.data.isEmpty }
    }

    private var photoViewerErrorView: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("Unable to load photos")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.8))
                    Text("The photos are no longer available.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) {
                        isPhotoViewerPresented = false
                    } label: {
                        Label("Close", systemImage: "xmark")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func dateAndTimeSheet() -> some View {
        NavigationStack {
            ScheduledTriggerEditorScreen(viewModel: viewModel)
        }
        .presentationDetents([.medium])
    }

    @ViewBuilder
    private func locationSheet() -> some View {
        NavigationStack {
            LocationTriggerEditorScreen(viewModel: viewModel)
        }
    }

    @ViewBuilder
    private func linkSheet() -> some View {
        MemoryEditorAddLinkSheet { url in
            handleLinkAdded(url)
        }
        .presentationDetents([.height(200)])
    }

    @ViewBuilder
    private func personSheet() -> some View {
        NavigationStack {
            PersonTriggerEditorScreen(viewModel: viewModel)
        }
        .presentationDetents([.medium])
    }

    @ViewBuilder
    private func sequentialSheet() -> some View {
        NavigationStack {
            SequentialTriggerEditorScreen(
                viewModel: viewModel,
            )
        }
        .presentationDetents([.large])
    }



    @ViewBuilder
    private func photoOptionsSheet() -> some View {
        NavigationStack {
            HStack(spacing: 16) {
                Button {
                    showPhotoOptionsSheet = false
                    handleLibraryToolbarTap()
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.stack")
                            .font(.system(size: 24, weight: .semibold))
                        Text("Library")
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .glassEffect(in: .rect(cornerRadius: 24.0))
                }
                .disabled(!isPhotoActionsEnabled)

                Button {
                    showPhotoOptionsSheet = false
                    handleCameraToolbarTap()
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "camera")
                            .font(.system(size: 24, weight: .semibold))
                        Text("Camera")
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .glassEffect(in: .rect(cornerRadius: 24.0))
                }
                .disabled(!isPhotoActionsEnabled)
            }
            .padding()
            .navigationTitle("Add Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        showPhotoOptionsSheet = false
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
        .presentationDetents([.height(200)])
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
