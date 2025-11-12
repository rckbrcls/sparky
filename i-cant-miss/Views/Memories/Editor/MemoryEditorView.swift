//
//  MemoryEditorView.swift
//  i-cant-miss
//
//  Created by Codex on 09/03/24.
//

import PhotosUI
import SwiftUI
import UIKit

struct MemoryEditorView: View {
    enum Mode {
        case create(space: SpaceModel?, template: MemoryEditorTemplate)
        case edit(memory: MemoryModel)
        case view(memory: MemoryModel)
    }

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: MemoryEditorViewModel
    @State private var showDueDateSheet = false
    @State private var showExactTimeSheet = false
    @State private var showWeekdaySheet = false
    @State private var showTriggerPickerSheet = false
    @State private var showAddLinkSheet = false
    @State private var showLocationPicker = false
    @State private var showPersonSheet = false
    @State private var showSequentialSheet = false
    @State private var checklistDraftRows: [ChecklistDraftRow] = [ChecklistDraftRow()]
    @State private var isPresentingPhotoLibrary = false
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var isPresentingCamera = false
    @State private var isLoadingPhotos = false
    @FocusState private var focusedDraftID: UUID?
    @FocusState private var isTitleFocused: Bool
    @State private var hasEnabledRichTextManually = false
    @State private var hasInitializedContentState = false
    @State private var isEditingEnabled: Bool
    @State private var isPhotoViewerPresented = false
    @State private var selectedAttachmentIndex = 0
    @State private var navigationPath = NavigationPath()
    @Namespace private var toolbarGlassNamespace

    private let mode: Mode
    private let environment: AppEnvironment

    init(environment: AppEnvironment, mode: Mode) {
        self.mode = mode
        self.environment = environment
        switch mode {
        case let .create(space, template):
            _viewModel = StateObject(wrappedValue: MemoryEditorViewModel(
                environment: environment,
                attachmentStore: environment.attachmentStore,
                memory: nil,
                defaultSpace: space,
                template: template
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
        case let .view(memory):
            _viewModel = StateObject(wrappedValue: MemoryEditorViewModel(
                environment: environment,
                attachmentStore: environment.attachmentStore,
                memory: memory,
                defaultSpace: memory.space,
                template: .blank
            ))
            _isEditingEnabled = State(initialValue: false)
        }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                baseBackground
                    .ignoresSafeArea()
                readOnlyGradient
                    .opacity(isReadOnly ? 1 : 0)
                    .animation(.easeInOut(duration: 0.35), value: isReadOnly)
                    .allowsHitTesting(false)

                editorContent
            }
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                viewModel.loadLatestDataIfNeeded()
                initializeContentStateIfNeeded()
            }
            .alert("Unable to save", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { _ in viewModel.errorMessage = nil }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .sheet(isPresented: $showDueDateSheet, content: dueDateSheet)
            .sheet(isPresented: $showExactTimeSheet, content: exactTimeSheet)
            .sheet(isPresented: $showWeekdaySheet, content: weekdaySheet)
            .sheet(isPresented: $showTriggerPickerSheet) {
                MemoryTriggerPickerSheet(viewModel: viewModel)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $showAddLinkSheet, content: linkSheet)
            .sheet(isPresented: $showLocationPicker, content: locationSheet)
            .sheet(isPresented: $showPersonSheet, content: personSheet)
            .sheet(isPresented: $showSequentialSheet, content: sequentialSheet)
            .sheet(isPresented: $isPresentingCamera) {
                CameraCaptureView(
                    onCapture: { image in
                        handleCapturedImage(image)
                        isPresentingCamera = false
                    },
                    onCancel: {
                        isPresentingCamera = false
                    }
                )
            }
            .photosPicker(isPresented: $isPresentingPhotoLibrary,
                          selection: $photoPickerItems,
                          matching: .images)
            .fullScreenCover(isPresented: $isPhotoViewerPresented) {
                MemoryEditorPhotoCarouselView(
                    attachments: viewModel.attachments,
                    initialIndex: selectedAttachmentIndex
                ) {
                    isPhotoViewerPresented = false
                }
            }
            .onChange(of: viewModel.body) { _, newValue in
                guard !hasEnabledRichTextManually else { return }
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    hasEnabledRichTextManually = true
                }
            }
            .onChange(of: photoPickerItems) { _, newItems in
                guard !newItems.isEmpty else { return }
                Task {
                    await loadSelectedPhotos(from: newItems)
                }
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
        case .edit, .view:
            return isEditingEnabled ? "Edit Memory" : "Memory"
        }
    }

    private var saveButtonTitle: String {
        switch mode {
        case .create:
            return "Create"
        case .edit, .view:
            return "Save"
        }
    }

    private var isSaveDisabled: Bool {
        viewModel.isSaving || viewModel.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var editorContent: some View {
        List {
            titleSectionRow
            if shouldShowChecklistCard {
                checklistCardRow
                    .transition(cardBounceTransition)
            }
            if shouldShowRichTextCard {
                richTextCardRow
                    .transition(cardBounceTransition)
            }
            if shouldShowPhotosCard {
                photosCardRow
                    .transition(cardBounceTransition)
            }
            if shouldShowLinksCard {
                linksCardRow
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
                if isEditingEnabled {
                    Button(role: .confirm) {
                        commitChecklistDrafts()
                        Task {
                            let success = await viewModel.save()
                            if success {
                                await MainActor.run {
                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                    isTitleFocused = false
                                    focusedDraftID = nil
                                    withAnimation(.easeInOut(duration: 0.35)) {
                                        isEditingEnabled = false
                                    }
                                }
                            }
                        }
                    } label: {
                        Label(saveButtonTitle, systemImage: "checkmark")
                    }
                    .disabled(isSaveDisabled)
                } else if canEnableEditing {
                    Button {
                        enableEditing()
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                }
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
                        SpacePicker(selection: Binding(
                            get: { viewModel.selectedSpaceID ?? spacesForPicker.first?.id ?? SpaceModel.inbox.id },
                            set: { viewModel.selectedSpaceID = $0 }
                        ), spaces: spacesForPicker)

                        Picker(selection: $viewModel.status) {
                            ForEach(MemoryStatus.allCases) { status in
                                Text(status.rawValue.capitalized).tag(status)
                            }
                        } label: {
                            Label("Status", systemImage: "circle.circle")
                        }
                        .pickerStyle(.menu)

                        Picker(selection: $viewModel.priority) {
                            ForEach(MemoryPriority.allCases) { priority in
                                Label(priorityLabel(for: priority), systemImage: priority.iconName)
                                    .tag(priority)
                            }
                        } label: {
                            Label("Priority", systemImage: "flag.fill")
                        }
                        .pickerStyle(.menu)
                    }

                    Menu("Preferences") {
                        Toggle(isOn: $viewModel.autoCompleteChecklist) {
                            Label("Auto-complete when checklist is done", systemImage: "checkmark.circle")
                        }
                        .disabled(!viewModel.canToggleAutoComplete)
                        .foregroundStyle(viewModel.canToggleAutoComplete ? .primary : .secondary)

                        Toggle(isOn: $viewModel.isPinned) {
                            Label("Show in Today view", systemImage: "calendar")
                        }

                        Toggle(isOn: Binding(
                            get: { !viewModel.triggers.isEmpty },
                            set: { _ in }
                        )) {
                            Label("Enable notifications", systemImage: "bell.badge")
                        }
                        .disabled(true)
                        .foregroundStyle(.secondary)

                        Toggle(isOn: .constant(false)) {
                            Label("Archive when completed", systemImage: "archivebox")
                        }
                        .disabled(true)
                        .foregroundStyle(.secondary)
                    }

                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            GlassEffectContainer(spacing: 10) {
                HStack {
                    if isEditingEnabled {

                        HStack {
                            addRichTextButton
                            Spacer()
                            addChecklistButton
                            Spacer()
                            addPhotoLibraryButton
                            Spacer()
                            capturePhotoButton
                            Spacer()
                            addLinkButton
                        }

                    }
                    Spacer()
                    triggerToolbarButton
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 10)
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
    }

    private var titleSectionRow: some View {
        titleSection
            .padding(.horizontal, 20)
            .listRowSeparator(.hidden)
            .listRowInsets(.init(top: 20, leading: 0, bottom: 12, trailing: 0))
            .listRowBackground(Color.clear)
    }

    private var checklistCardRow: some View {
        checklistCard
            .padding(.horizontal, 20)
            .listRowSeparator(.hidden)
            .listRowInsets(.init(top: 0, leading: 0, bottom: 16, trailing: 0))
            .listRowBackground(Color.clear)
    }

    private var richTextCardRow: some View {
        richTextCard
            .padding(.horizontal, 20)
            .listRowSeparator(.hidden)
            .listRowInsets(.init(top: 0, leading: 0, bottom: 16, trailing: 0))
            .listRowBackground(Color.clear)
    }

    private var photosCardRow: some View {
        photosCard
            .padding(.horizontal, 20)
            .listRowSeparator(.hidden)
            .listRowInsets(.init(top: 0, leading: 0, bottom: 16, trailing: 0))
            .listRowBackground(Color.clear)
    }

    private var linksCardRow: some View {
        linksCard
            .padding(.horizontal, 20)
            .listRowSeparator(.hidden)
            .listRowInsets(.init(top: 0, leading: 0, bottom: 24, trailing: 0))
            .listRowBackground(Color.clear)
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isEditingEnabled {
                TextField("Memory", text: $viewModel.title, axis: .vertical)
                    .font(.title3)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.leading)
                    .submitLabel(.done)
                    .lineLimit(2)
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
            } else {
                Text(displayTitle)
                    .font(.title3)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .foregroundStyle(isTitlePlaceholder ? Color.secondary : Color.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical)
        .glassEffect(.regular.interactive())
        .contentShape(Rectangle())
    }

    private var checklistCard: some View {
        MemoryEditorChecklistCard {
            VStack(alignment: .leading, spacing: 12) {
                if let subtitle = checklistSubtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                ForEach(viewModel.checklistItems) { item in
                    ChecklistItemEditor(
                        item: binding(for: item),
                        isEditable: isEditingEnabled,
                        onToggle: { viewModel.toggleChecklistCompletion(for: item.id) },
                        onDelete: { removeChecklist(item) }
                    )
                }
                if isEditingEnabled {
                    ForEach(checklistDraftRows) { draft in
                        ChecklistNewItemRow(
                            draft: draftBinding(for: draft),
                            focus: $focusedDraftID,
                            onSubmit: handleDraftSubmit,
                            onTitleChange: handleDraftTitleChange
                        )
                    }
                }
            }
        }
        .modifier(EditingSwipeActionModifier(
            isEnabled: isEditingEnabled,
            title: "Delete Checklist",
            systemImage: "trash",
            accessibilityLabel: "Delete checklist content",
            action: { disableContent(.checklist) }
        ))
    }

    private var richTextCard: some View {
        MemoryEditorRichTextCard(
            text: $viewModel.body,
            isEditable: isEditingEnabled
        )
        .modifier(EditingSwipeActionModifier(
            isEnabled: isEditingEnabled,
            title: "Delete Text",
            systemImage: "trash",
            accessibilityLabel: "Delete rich text content",
            action: { disableContent(.richText) }
        ))
    }

    private var photosCard: some View {
        MemoryEditorPhotosCard(
            attachments: $viewModel.attachments,
            isLoading: isLoadingPhotos,
            isEditable: isEditingEnabled,
            onRemoveAttachment: { id in
                viewModel.removeAttachment(id: id)
            },
            onAttachmentTap: { index, _ in
                presentPhotoViewer(at: index)
            }
        )
        .modifier(EditingSwipeActionModifier(
            isEnabled: isEditingEnabled,
            title: "Delete Photos",
            systemImage: "trash",
            accessibilityLabel: "Delete photos content",
            action: { disableContent(.photos) }
        ))
    }

    private var linksCard: some View {
        MemoryEditorLinksCard(
            links: $viewModel.linkAttachments,
            isEditable: isEditingEnabled,
            onRemoveLink: { id in
                viewModel.removeLinkAttachment(id: id)
            }
        )
        .modifier(EditingSwipeActionModifier(
            isEnabled: isEditingEnabled,
            title: "Delete Links",
            systemImage: "trash",
            accessibilityLabel: "Delete links content",
            action: { disableContent(.links) }
        ))
    }

    private var addRichTextButton: some View {
        Button {
            handleAddContentSelection(.richText)
        } label: {
            Image(systemName: MemoryEditorContentType.richText.iconName)
                .font(.system(size: 20, weight: .semibold))
                .frame(width: 48, height: 48)
                .glassEffect(.regular.interactive())
                .glassEffectUnion(id: "editorToolbar", namespace: toolbarGlassNamespace)
                .foregroundStyle(shouldShowRichTextCard ? Color.accentColor : .primary)
        }
        .accessibilityLabel("Add rich text")
    }

    private var addChecklistButton: some View {
        Button {
            handleAddContentSelection(.checklist)
        } label: {
            Image(systemName:  MemoryEditorContentType.checklist.iconName)
                .font(.system(size: 20, weight: .semibold))
                .frame(width: 48, height: 48)
                .glassEffect(.regular.interactive())
                .glassEffectUnion(id: "editorToolbar", namespace: toolbarGlassNamespace)
                .foregroundStyle(shouldShowChecklistCard ? Color.accentColor : .primary)
        }
        .accessibilityLabel("Add checklist")
    }

    private var addLinkButton: some View {
        Button {
            handleAddContentSelection(.links)
        } label: {
            Image(systemName:  MemoryEditorContentType.links.iconName)
                .font(.system(size: 20, weight: .semibold))
                .frame(width: 48, height: 48)
                .glassEffect(.regular.interactive())
                .glassEffectUnion(id: "editorToolbar", namespace: toolbarGlassNamespace)
                .foregroundStyle(shouldShowLinksCard ? Color.accentColor : .primary)
        }
        .accessibilityLabel("Add link")
    }

    private var triggerToolbarButton: some View {
        MemoryTriggerAddBadge(
            isPresented: $showTriggerPickerSheet,
            displayStyle: .toolbar
        )
    }

    private var addPhotoLibraryButton: some View {
        Button {
            handleLibraryToolbarTap()
        } label: {
            Image(systemName:  "photo.stack")
                .font(.system(size: 20, weight: .semibold))
                .frame(width: 48, height: 48)
                .glassEffect(.regular.interactive())
                .glassEffectUnion(id: "editorToolbar", namespace: toolbarGlassNamespace)
                .foregroundStyle(photoToolbarForegroundColor)
        }
        .disabled(!isPhotoActionsEnabled)
        .accessibilityLabel("Add from library")
    }

    private var capturePhotoButton: some View {
        Button {
            handleCameraToolbarTap()
        } label: {
            Image(systemName:  "camera")
                .font(.system(size: 20, weight: .semibold))
                .frame(width: 48, height: 48)
                .glassEffect(.regular.interactive())
                .glassEffectUnion(id: "editorToolbar", namespace: toolbarGlassNamespace)
                .foregroundStyle(photoToolbarForegroundColor)
        }
        .disabled(!isPhotoActionsEnabled)
        .accessibilityLabel("Capture photo")
    }

    private var photoToolbarForegroundColor: Color {
        guard isPhotoActionsEnabled else { return .secondary }
        return shouldShowPhotosCard ? Color.accentColor : Color.primary
    }

    private var isPhotoActionsEnabled: Bool {
        !viewModel.isSaving && !isLoadingPhotos
    }


    private var shouldShowChecklistCard: Bool {
        viewModel.showChecklist || !viewModel.checklistItems.isEmpty
    }

    private var shouldShowRichTextCard: Bool {
        hasEnabledRichTextManually || !viewModel.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var shouldShowPhotosCard: Bool {
        !viewModel.attachments.isEmpty
    }

    private var shouldShowLinksCard: Bool {
        !viewModel.linkAttachments.isEmpty
    }

    private var checklistSubtitle: String? {
        guard !viewModel.checklistItems.isEmpty else { return nil }
        let completed = viewModel.checklistItems.filter(\.isCompleted).count
        return "\(completed) of \(viewModel.checklistItems.count) completed"
    }

    private func handleAddContentSelection(_ type: MemoryEditorContentType) {
        switch type {
        case .richText:
            hasEnabledRichTextManually = true
        case .checklist:
            if !viewModel.showChecklist {
                viewModel.showChecklist = true
            }
            if viewModel.checklistItems.isEmpty && checklistDraftRows.isEmpty {
                checklistDraftRows = [ChecklistDraftRow()]
            }
        case .photos:
            break
        case .links:
            showAddLinkSheet = true
        }
    }

    private func disableContent(_ type: MemoryEditorContentType) {
        switch type {
        case .richText:
            viewModel.body = ""
            hasEnabledRichTextManually = false
        case .checklist:
            viewModel.checklistItems.removeAll()
            viewModel.showChecklist = false
            checklistDraftRows = [ChecklistDraftRow()]
            focusedDraftID = nil
        case .photos:
            viewModel.attachments.removeAll()
            isLoadingPhotos = false
            isPresentingPhotoLibrary = false
        case .links:
            viewModel.linkAttachments.removeAll()
            showAddLinkSheet = false
        }
    }

    private func initializeContentStateIfNeeded() {
        guard !hasInitializedContentState else { return }
        hasInitializedContentState = true
        let trimmedBody = viewModel.body.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedBody.isEmpty {
            hasEnabledRichTextManually = true
        }
    }

    private func binding(for item: CheckItemDraft) -> Binding<CheckItemDraft> {
        guard let index = viewModel.checklistItems.firstIndex(where: { $0.id == item.id }) else {
            return .constant(item)
        }
        return $viewModel.checklistItems[index]
    }

    private func draftBinding(for draft: ChecklistDraftRow) -> Binding<ChecklistDraftRow> {
        guard let index = checklistDraftRows.firstIndex(where: { $0.id == draft.id }) else {
            return .constant(draft)
        }
        return $checklistDraftRows[index]
    }

    private func handleDraftSubmit(_ draftID: UUID) {
        guard let index = checklistDraftRows.firstIndex(where: { $0.id == draftID }) else { return }
        let trimmedTitle = checklistDraftRows[index].title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            DispatchQueue.main.async {
                focusedDraftID = draftID
            }
            return
        }

        let trimmedDetail = checklistDraftRows[index].detail.trimmingCharacters(in: .whitespacesAndNewlines)
        viewModel.addChecklistItem(title: trimmedTitle, detail: trimmedDetail)

        let nextID: UUID
        if index + 1 < checklistDraftRows.count {
            nextID = checklistDraftRows[index + 1].id
        } else {
            let placeholder = ChecklistDraftRow()
            checklistDraftRows.append(placeholder)
            nextID = placeholder.id
        }

        focusedDraftID = nextID
        checklistDraftRows.remove(at: index)

        if checklistDraftRows.isEmpty {
            let placeholder = ChecklistDraftRow()
            checklistDraftRows = [placeholder]
            focusedDraftID = placeholder.id
            return
        }

        cleanupTrailingPlaceholders()
    }

    private func handleDraftTitleChange(_ draftID: UUID, _ text: String) {
        guard let index = checklistDraftRows.firstIndex(where: { $0.id == draftID }) else { return }
        guard !checklistDraftRows.isEmpty else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lastIndex = checklistDraftRows.count - 1

        if trimmed.isEmpty {
            if checklistDraftRows.count > 1 && index != lastIndex {
                checklistDraftRows.remove(at: index)
            }
            cleanupTrailingPlaceholders()
        } else if index == lastIndex {
            checklistDraftRows.append(ChecklistDraftRow())
        }
    }

    private func cleanupTrailingPlaceholders() {
        while checklistDraftRows.count > 1 {
            guard let last = checklistDraftRows.last else { break }
            let beforeLast = checklistDraftRows[checklistDraftRows.count - 2]
            if last.isEffectivelyEmpty && beforeLast.isEffectivelyEmpty {
                checklistDraftRows.removeLast()
            } else {
                break
            }
        }

        if checklistDraftRows.isEmpty {
            checklistDraftRows = [ChecklistDraftRow()]
        }
    }

    private func commitChecklistDrafts() {
        let draftsToCommit = checklistDraftRows.filter {
            !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard !draftsToCommit.isEmpty else { return }

        for draft in draftsToCommit {
            let trimmedTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedTitle.isEmpty else { continue }
            let trimmedDetail = draft.detail.trimmingCharacters(in: .whitespacesAndNewlines)
            viewModel.addChecklistItem(title: trimmedTitle, detail: trimmedDetail)
        }

        let committedIDs = Set(draftsToCommit.map(\.id))
        checklistDraftRows.removeAll { committedIDs.contains($0.id) }
        focusedDraftID = nil

        if checklistDraftRows.isEmpty {
            let placeholder = ChecklistDraftRow()
            checklistDraftRows = [placeholder]
            focusedDraftID = placeholder.id
        } else {
            cleanupTrailingPlaceholders()
        }
    }

    private func removeChecklist(_ item: CheckItemDraft) {
        if let index = viewModel.checklistItems.firstIndex(where: { $0.id == item.id }) {
            viewModel.checklistItems.remove(at: index)
            if viewModel.checklistItems.isEmpty {
                viewModel.showChecklist = false
            }
        }
    }

    private func handleCameraToolbarTap() {
        isPresentingCamera = true
    }

    private func handleLibraryToolbarTap() {
        isPresentingPhotoLibrary = true
    }

    private func handleCapturedImage(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.85) else { return }
        _ = viewModel.createAttachment(data: data)
    }

    private func handleLinkAdded(_ url: URL) {
        let alreadyExists = viewModel.linkAttachments.contains {
            $0.url?.absoluteString == url.absoluteString
        }
        guard !alreadyExists else { return }
        _ = viewModel.createLinkAttachment(url: url)
    }

    private func presentPhotoViewer(at index: Int) {
        guard viewModel.attachments.indices.contains(index) else { return }
        selectedAttachmentIndex = index
        isPhotoViewerPresented = true
    }

    private func loadSelectedPhotos(from items: [PhotosPickerItem]) async {
        await MainActor.run {
            isLoadingPhotos = true
        }
        for item in items {
            do {
                if let data = try await item.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        _ = viewModel.createAttachment(data: data)
                    }
                }
            } catch {
                continue
            }
        }
        await MainActor.run {
            isLoadingPhotos = false
            photoPickerItems = []
            isPresentingPhotoLibrary = false
        }
    }

    private func priorityLabel(for priority: MemoryPriority) -> String {
        switch priority {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }

    private var spacesForPicker: [SpaceModel] {
        let spaces = viewModel.availableSpaces
        return spaces.isEmpty ? [SpaceModel.inbox] : spaces
    }

    private var baseBackground: Color {
        Color(.systemBackground)
    }

    private var readOnlyGradient: some View {
        let accent = currentSpaceAccent
        return LinearGradient(
            colors: [
                accent.opacity(0.45),
                accent.opacity(0.2),
                Color.clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.08),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .ignoresSafeArea()
    }

    private var currentSpaceAccent: Color {
        if let hex = viewModel.selectedSpace?.colorHex,
           let color = Color(hex: hex) {
            return color
        }
        return .accentColor
    }

    private var canEnableEditing: Bool {
        !isEditingEnabled && !viewModel.isSaving
    }

    private func enableEditing() {
        withAnimation(.easeInOut(duration: 0.35)) {
            isEditingEnabled = true
        }
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

    private var isReadOnly: Bool {
        !isEditingEnabled
    }

    private var displayTitle: String {
        let trimmed = viewModel.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Untitled Memory" }
        return trimmed
    }

    private var isTitlePlaceholder: Bool {
        viewModel.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @ViewBuilder
    private func dueDateSheet() -> some View {
        NavigationStack {
            MemoryDueDateTriggerEditorScreen(viewModel: viewModel)
        }
    }

    @ViewBuilder
    private func exactTimeSheet() -> some View {
        NavigationStack {
            MemoryExactTimeTriggerEditorScreen(viewModel: viewModel)
        }
    }

    @ViewBuilder
    private func weekdaySheet() -> some View {
        NavigationStack {
            MemoryWeekdayTriggerEditorScreen(viewModel: viewModel)
        }
    }

    @ViewBuilder
    private func locationSheet() -> some View {
        NavigationStack {
            MemoryLocationTriggerEditorScreen(viewModel: viewModel)
        }
    }

    @ViewBuilder
    private func linkSheet() -> some View {
        MemoryEditorAddLinkSheet { url in
            handleLinkAdded(url)
        }
        .presentationDetents([.medium])
    }

    @ViewBuilder
    private func personSheet() -> some View {
        NavigationStack {
            MemoryPersonTriggerEditorScreen(viewModel: viewModel)
        }
        .presentationDetents([.medium])
    }

    @ViewBuilder
    private func sequentialSheet() -> some View {
        NavigationStack {
            MemorySequentialTriggerEditorScreen(
                viewModel: viewModel,
                excludedMemoryID: viewModel.editingMemoryID
            )
        }
        .presentationDetents([.large])
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
