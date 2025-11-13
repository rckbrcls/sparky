extension MemoryEditorView {
    private func ensureDraftContainer(for contentID: UUID) {
        if let drafts = checklistDraftRows[contentID], !drafts.isEmpty {
            return
        }
        checklistDraftRows[contentID] = [ChecklistDraftRow()]
    }

    private func draftsBinding(for contentID: UUID) -> Binding<[ChecklistDraftRow]> {
        Binding(
            get: { checklistDraftRows[contentID] ?? [ChecklistDraftRow()] },
            set: { checklistDraftRows[contentID] = $0 }
        )
    }

    private func binding(for checklistItem: CheckItemDraft, in contentBinding: Binding<MemoryEditorContentItem>) -> Binding<CheckItemDraft> {
        Binding(
            get: {
                guard case .checklist(let content) = contentBinding.wrappedValue,
                      let index = content.items.firstIndex(where: { $0.id == checklistItem.id }) else {
                    return checklistItem
                }
                return content.items[index]
            },
            set: { newValue in
                guard case .checklist(var content) = contentBinding.wrappedValue,
                      let index = content.items.firstIndex(where: { $0.id == checklistItem.id }) else {
                    return
                }
                content.items[index] = newValue
                contentBinding.wrappedValue = .checklist(content)
            }
        )
    }

    private func handleDraftSubmit(_ draftID: UUID, in contentID: UUID) {
        guard var drafts = checklistDraftRows[contentID],
              let index = drafts.firstIndex(where: { $0.id == draftID }) else { return }
        let trimmedTitle = drafts[index].title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            DispatchQueue.main.async {
                focusedDraftID = draftID
            }
            return
        }

        let trimmedDetail = drafts[index].detail.trimmingCharacters(in: .whitespacesAndNewlines)
        viewModel.addChecklistItem(to: contentID, title: trimmedTitle, detail: trimmedDetail)

        drafts.remove(at: index)
        if drafts.isEmpty {
            drafts = [ChecklistDraftRow()]
        } else {
            cleanupTrailingPlaceholders(for: contentID, drafts: &drafts)
        }

        checklistDraftRows[contentID] = drafts
        focusedDraftID = drafts.last?.id
    }

    private func handleDraftTitleChange(_ contentID: UUID, _ draftID: UUID, _ text: String) {
        guard var drafts = checklistDraftRows[contentID],
              let index = drafts.firstIndex(where: { $0.id == draftID }) else { return }

        drafts[index].title = text

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lastIndex = drafts.count - 1

        if trimmed.isEmpty {
            if drafts.count > 1 && index != lastIndex {
                drafts.remove(at: index)
            }
            cleanupTrailingPlaceholders(for: contentID, drafts: &drafts)
        } else if index == lastIndex {
            drafts.append(ChecklistDraftRow())
        }

        checklistDraftRows[contentID] = drafts
    }

    private func cleanupTrailingPlaceholders(for contentID: UUID, drafts: inout [ChecklistDraftRow]) {
        while drafts.count > 1 {
            guard let last = drafts.last else { break }
            let beforeLast = drafts[drafts.count - 2]
            if last.isEffectivelyEmpty && beforeLast.isEffectivelyEmpty {
                drafts.removeLast()
            } else {
                break
            }
        }

        if drafts.isEmpty {
            drafts = [ChecklistDraftRow()]
        }
        checklistDraftRows[contentID] = drafts
    }

    private func commitChecklistDrafts() {
        for (contentID, drafts) in checklistDraftRows {
            let draftsToCommit = drafts.filter {
                !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            guard !draftsToCommit.isEmpty else { continue }

            for draft in draftsToCommit {
                let trimmedTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedTitle.isEmpty else { continue }
                let trimmedDetail = draft.detail.trimmingCharacters(in: .whitespacesAndNewlines)
                viewModel.addChecklistItem(to: contentID, title: trimmedTitle, detail: trimmedDetail)
            }

            checklistDraftRows[contentID] = [ChecklistDraftRow()]
        }

        focusedDraftID = nil
    }

    private func removeChecklist(_ item: CheckItemDraft, in contentID: UUID) {
        viewModel.removeChecklistItem(contentID: contentID, itemID: item.id)
    }

    private func removeContent(with id: UUID) {
        viewModel.removeContent(id: id)
        checklistDraftRows.removeValue(forKey: id)
        photoLoadingContentIDs.remove(id)
        if pendingPhotoContentID == id {
            pendingPhotoContentID = nil
        }
        if pendingLinkContentID == id {
            pendingLinkContentID = nil
        }
        if selectedPhotoContentID == id {
            selectedPhotoContentID = nil
            selectedAttachmentIndex = 0
            isPhotoViewerPresented = false
        }
        cleanupPendingContentTargets()
    }
}

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
    @State private var checklistDraftRows: [UUID: [ChecklistDraftRow]] = [:]
    @State private var isPresentingPhotoLibrary = false
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var isPresentingCamera = false
    @State private var photoLoadingContentIDs: Set<UUID> = []
    @State private var pendingPhotoContentID: UUID?
    @State private var pendingLinkContentID: UUID?
    @FocusState private var focusedDraftID: UUID?
    @FocusState private var isTitleFocused: Bool
    @State private var isEditingEnabled: Bool
    @State private var isPhotoViewerPresented = false
    @State private var selectedAttachmentIndex = 0
    @State private var selectedPhotoContentID: UUID?
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
                syncChecklistDraftRowsWithContent()
                Task {
                    await viewModel.loadLatestDataIfNeeded()
                    syncChecklistDraftRowsWithContent()
                }
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
            }
            .photosPicker(isPresented: $isPresentingPhotoLibrary,
                          selection: $photoPickerItems,
                          matching: .images)
            .fullScreenCover(isPresented: $isPhotoViewerPresented) {
                photoViewerContent
            }
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
            .onChange(of: viewModel.contentQueue) { _, _ in
                syncChecklistDraftRowsWithContent()
                cleanupPendingContentTargets()
                if let contentID = selectedPhotoContentID,
                   !viewModel.contentQueue.contains(where: { $0.id == contentID && $0.contentType == .photos }) {
                    selectedPhotoContentID = nil
                    selectedAttachmentIndex = 0
                    isPhotoViewerPresented = false
                }
            }
            .onChange(of: isPresentingPhotoLibrary) { _, isPresented in
                if !isPresented {
                    if photoPickerItems.isEmpty {
                        if pendingPhotoContentID != nil {
                            let cardExists = viewModel.contentQueue.contains(where: { $0.id == pendingPhotoContentID && $0.contentType == .photos })
                            if !cardExists {
                                pendingPhotoContentID = nil
                            }
                        }
                    }
                    cleanupPendingContentTargets()
                }
            }
            .onChange(of: isPresentingCamera) { _, isPresented in
                if !isPresented {
                    if pendingPhotoContentID != nil {
                        let cardExists = viewModel.contentQueue.contains(where: { $0.id == pendingPhotoContentID && $0.contentType == .photos })
                        if !cardExists {
                            pendingPhotoContentID = nil
                        }
                    }
                    cleanupPendingContentTargets()
                }
            }
            .onChange(of: showAddLinkSheet) { _, isPresented in
                if !isPresented {
                    cleanupPendingContentTargets()
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
            ForEach($viewModel.contentQueue) { $item in
                contentRow(for: $item)
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

    @ViewBuilder
    private func contentRow(for item: Binding<MemoryEditorContentItem>) -> some View {
        switch item.wrappedValue {
        case .richText(let content):
            richTextCard(for: item, content: content)
            .padding(.horizontal, 20)
            .listRowSeparator(.hidden)
            .listRowInsets(.init(top: 0, leading: 0, bottom: 16, trailing: 0))
            .listRowBackground(Color.clear)
        case .checklist(let content):
            checklistCard(for: item, content: content)
            .padding(.horizontal, 20)
            .listRowSeparator(.hidden)
            .listRowInsets(.init(top: 0, leading: 0, bottom: 16, trailing: 0))
            .listRowBackground(Color.clear)
        case .photos(let content):
            photosCard(for: item, content: content)
            .padding(.horizontal, 20)
            .listRowSeparator(.hidden)
            .listRowInsets(.init(top: 0, leading: 0, bottom: 16, trailing: 0))
            .listRowBackground(Color.clear)
        case .links(let content):
            linksCard(for: item, content: content)
            .padding(.horizontal, 20)
            .listRowSeparator(.hidden)
            .listRowInsets(.init(top: 0, leading: 0, bottom: 24, trailing: 0))
            .listRowBackground(Color.clear)
        }
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

    private func checklistCard(for item: Binding<MemoryEditorContentItem>, content: MemoryEditorChecklistContent) -> some View {
        MemoryEditorChecklistCard {
            VStack(alignment: .leading, spacing: 12) {
                if let subtitle = checklistSubtitle(for: content) {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                ForEach(content.items) { checklistItem in
                    ChecklistItemEditor(
                        item: binding(for: checklistItem, in: item),
                        isEditable: isEditingEnabled,
                        onToggle: { viewModel.toggleChecklistCompletion(for: checklistItem.id) },
                        onDelete: { removeChecklist(checklistItem, in: content.id) }
                    )
                }
                if isEditingEnabled {
                    ForEach(draftsBinding(for: content.id)) { $draft in
                        ChecklistNewItemRow(
                            draft: $draft,
                            focus: $focusedDraftID,
                            onSubmit: { handleDraftSubmit($0, in: content.id) },
                            onTitleChange: { draftID, text in handleDraftTitleChange(content.id, draftID, text) }
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
            action: { removeContent(with: content.id) }
        ))
    }

    private func richTextCard(for item: Binding<MemoryEditorContentItem>, content: MemoryEditorRichTextContent) -> some View {
        MemoryEditorRichTextCard(
            text: richTextBinding(for: item),
            isEditable: isEditingEnabled
        )
        .modifier(EditingSwipeActionModifier(
            isEnabled: isEditingEnabled,
            title: "Delete Text",
            systemImage: "trash",
            accessibilityLabel: "Delete rich text content",
            action: { removeContent(with: content.id) }
        ))
    }

    private func photosCard(for item: Binding<MemoryEditorContentItem>, content: MemoryEditorPhotosContent) -> some View {
        MemoryEditorPhotosCard(
            attachments: photosBinding(for: item),
            isLoading: photoLoadingContentIDs.contains(content.id),
            isEditable: isEditingEnabled,
            onRemoveAttachment: { id in
                viewModel.removePhotoAttachment(id: id, from: content.id)
            },
            onAttachmentTap: { index, attachment in
                presentPhotoViewer(at: index, for: content.id, clickedAttachment: attachment)
            },
            onAddFromLibrary: { addPhotosFromLibrary(to: content.id) },
            onAddFromCamera: { addPhotosFromCamera(to: content.id) },
            isAddMenuEnabled: canAddPhotos(to: content.id)
        )
        .modifier(EditingSwipeActionModifier(
            isEnabled: isEditingEnabled,
            title: "Delete Photos",
            systemImage: "trash",
            accessibilityLabel: "Delete photos content",
            action: { removeContent(with: content.id) }
        ))
    }

    private func linksCard(for item: Binding<MemoryEditorContentItem>, content: MemoryEditorLinksContent) -> some View {
        MemoryEditorLinksCard(
            links: linksBinding(for: item),
            isEditable: isEditingEnabled,
            onRemoveLink: { id in
                viewModel.removeLinkAttachment(id: id, from: content.id)
            }
        )
        .modifier(EditingSwipeActionModifier(
            isEnabled: isEditingEnabled,
            title: "Delete Links",
            systemImage: "trash",
            accessibilityLabel: "Delete links content",
            action: { removeContent(with: content.id) }
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
                .foregroundStyle(hasContent(of: .richText) ? Color.accentColor : .primary)
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
                .foregroundStyle(hasContent(of: .checklist) ? Color.accentColor : .primary)
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
                .foregroundStyle(hasContent(of: .links) ? Color.accentColor : .primary)
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
        return hasContent(of: .photos) ? Color.accentColor : Color.primary
    }

    private var isPhotoActionsEnabled: Bool {
        !viewModel.isSaving && pendingPhotoContentID == nil && photoLoadingContentIDs.isEmpty
    }

    private func canAddPhotos(to contentID: UUID) -> Bool {
        guard isEditingEnabled else { return false }
        guard !viewModel.isSaving else { return false }
        guard pendingPhotoContentID == nil else { return false }
        guard !isPresentingPhotoLibrary && !isPresentingCamera else { return false }
        guard photoLoadingContentIDs.isEmpty else { return false }
        return viewModel.contentQueue.contains { $0.id == contentID && $0.contentType == .photos }
    }

    private func handleAddContentSelection(_ type: MemoryEditorContentType) {
        guard isEditingEnabled else { return }
        switch type {
        case .richText:
            _ = viewModel.appendContent(type)
        case .checklist:
            let contentID = viewModel.appendContent(type)
            ensureDraftContainer(for: contentID)
            focusedDraftID = checklistDraftRows[contentID]?.first?.id
        case .photos:
            pendingPhotoContentID = nil
            isPresentingPhotoLibrary = true
        case .links:
            let contentID = viewModel.appendContent(type)
            pendingLinkContentID = contentID
            showAddLinkSheet = true
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

    private func addPhotosFromLibrary(to contentID: UUID) {
        guard canAddPhotos(to: contentID) else { return }
        pendingPhotoContentID = contentID
        isPresentingPhotoLibrary = true
    }

    private func addPhotosFromCamera(to contentID: UUID) {
        guard canAddPhotos(to: contentID) else { return }
        pendingPhotoContentID = contentID
        isPresentingCamera = true
    }

    private func handleCapturedImage(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.85) else { return }
        let targetID: UUID
        if let existingID = pendingPhotoContentID {
            targetID = existingID
        } else {
            targetID = viewModel.appendContent(.photos)
        }
        photoLoadingContentIDs.insert(targetID)
        if viewModel.addPhotoAttachment(data: data, to: targetID) == nil {
            viewModel.removeContent(id: targetID)
        }
        photoLoadingContentIDs.remove(targetID)
        pendingPhotoContentID = nil
        cleanupPendingContentTargets()
    }

    private func handleLinkAdded(_ url: URL) {
        guard let contentID = pendingLinkContentID else { return }
        if viewModel.addLinkAttachment(url: url, to: contentID) != nil {
            pendingLinkContentID = nil
        }
        cleanupPendingContentTargets()
    }

    private func presentPhotoViewer(at index: Int, for contentID: UUID, clickedAttachment: MemoryModel.Attachment) {
        guard index >= 0 else {
            return
        }

        isPhotoViewerPresented = false
        selectedPhotoContentID = nil
        selectedAttachmentIndex = 0

        guard let rawAttachments = photoAttachments(for: contentID),
              !rawAttachments.isEmpty else {
            return
        }

        guard rawAttachments.indices.contains(index) else {
            return
        }

        let flattenedAttachments = flattenAttachments(rawAttachments)

        guard !flattenedAttachments.isEmpty else {
            return
        }

        let safeIndex: Int
        if let flattenedIndex = flattenedAttachments.firstIndex(where: { $0.id == clickedAttachment.id }) {
            safeIndex = flattenedIndex
        } else {
            safeIndex = min(max(0, index), flattenedAttachments.count - 1)
        }

        guard flattenedAttachments.indices.contains(safeIndex) else {
            return
        }

        selectedPhotoContentID = contentID
        selectedAttachmentIndex = safeIndex
        isPhotoViewerPresented = true
    }

    private func loadSelectedPhotos(from items: [PhotosPickerItem]) async {
        let targetID: UUID = await MainActor.run {
            let id: UUID
            if let existingID = pendingPhotoContentID,
               viewModel.contentQueue.contains(where: { $0.id == existingID && $0.contentType == .photos }) {
                id = existingID
            } else {
                id = viewModel.appendContent(.photos)
            }
            photoLoadingContentIDs.insert(id)
            return id
        }

        var didAddAttachment = false
        for item in items {
            do {
                if let image = try await item.loadTransferable(type: PhotoPickerLoadedImage.self) {
                    _ = await MainActor.run {
                        if viewModel.addPhotoAttachment(data: image.data, to: targetID) != nil {
                            didAddAttachment = true
                        }
                    }
                }
            } catch {
                continue
            }
        }

        _ = await MainActor.run {
            photoLoadingContentIDs.remove(targetID)
            photoPickerItems = []
            isPresentingPhotoLibrary = false
            if !didAddAttachment {
                viewModel.removeContent(id: targetID)
            }
            if pendingPhotoContentID == targetID {
                pendingPhotoContentID = nil
            }
            cleanupPendingContentTargetsAfterAttachment(for: targetID, didAddAttachment: didAddAttachment)
        }
    }

    private func richTextBinding(for item: Binding<MemoryEditorContentItem>) -> Binding<String> {
        Binding(
            get: {
                if case .richText(let content) = item.wrappedValue {
                    return content.text
                }
                return ""
            },
            set: { newValue in
                if case .richText(var content) = item.wrappedValue {
                    content.text = newValue
                    item.wrappedValue = .richText(content)
                }
            }
        )
    }

    private func photosBinding(for item: Binding<MemoryEditorContentItem>) -> Binding<[MemoryModel.Attachment]> {
        Binding(
            get: {
                if case .photos(let content) = item.wrappedValue {
                    return content.attachments
                }
                return []
            },
            set: { newValue in
                if case .photos(var content) = item.wrappedValue {
                    content.attachments = newValue
                    item.wrappedValue = .photos(content)
                }
            }
        )
    }

    private func linksBinding(for item: Binding<MemoryEditorContentItem>) -> Binding<[MemoryModel.Attachment]> {
        Binding(
            get: {
                if case .links(let content) = item.wrappedValue {
                    return content.links
                }
                return []
            },
            set: { newValue in
                if case .links(var content) = item.wrappedValue {
                    content.links = newValue
                    item.wrappedValue = .links(content)
                }
            }
        )
    }

    private func photoAttachments(for contentID: UUID) -> [MemoryModel.Attachment]? {
        guard let item = viewModel.contentQueue.first(where: { $0.id == contentID && $0.contentType == .photos }),
              let photosContent = item.photosContent else {
            return nil
        }
        return photosContent.attachments
    }

    private func linkAttachments(for contentID: UUID) -> [MemoryModel.Attachment]? {
        viewModel.contentQueue.first { $0.id == contentID && $0.contentType == .links }?.linksContent?.links
    }

    private func hasContent(of type: MemoryEditorContentType) -> Bool {
        viewModel.contentQueue.contains { $0.contentType == type }
    }

    private func checklistSubtitle(for content: MemoryEditorChecklistContent) -> String? {
        let total = content.items.count
        guard total > 0 else { return nil }
        let completed = content.items.filter(\.isCompleted).count
        if completed == 0 {
            return total == 1 ? "1 item" : "\(total) items"
        }
        return "\(completed) of \(total) completed"
    }

    private func syncChecklistDraftRowsWithContent() {
        let checklistIDs = viewModel.contentQueue.compactMap { item -> UUID? in
            item.checklistContent?.id
        }

        let validIDs = Set(checklistIDs)
        for key in checklistDraftRows.keys where !validIDs.contains(key) {
            checklistDraftRows.removeValue(forKey: key)
        }

        for id in checklistIDs {
            ensureDraftContainer(for: id)
        }
    }

    private func cleanupPendingContentTargets() {
        let existingIDs = Set(viewModel.contentQueue.map(\.id))
        for key in checklistDraftRows.keys where !existingIDs.contains(key) {
            checklistDraftRows.removeValue(forKey: key)
        }

        if let pendingPhotoID = pendingPhotoContentID,
           !isPresentingPhotoLibrary,
           !isPresentingCamera,
           !photoLoadingContentIDs.contains(pendingPhotoID),
           photoPickerItems.isEmpty {
            let cardExists = viewModel.contentQueue.contains(where: { $0.id == pendingPhotoID && $0.contentType == .photos })
            if !cardExists {
                pendingPhotoContentID = nil
            }
        }

        if let pendingLinkID = pendingLinkContentID,
           !showAddLinkSheet,
           (linkAttachments(for: pendingLinkID)?.isEmpty ?? true) {
            viewModel.removeContent(id: pendingLinkID)
            pendingLinkContentID = nil
        }
    }

    private func cleanupPendingContentTargetsAfterAttachment(for contentID: UUID, didAddAttachment: Bool) {
        photoLoadingContentIDs.remove(contentID)
        photoPickerItems = []
        isPresentingPhotoLibrary = false

        if !didAddAttachment {
            viewModel.removeContent(id: contentID)
        }

        if pendingPhotoContentID == contentID {
            pendingPhotoContentID = nil
        }

        cleanupPendingContentTargets()
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

    private var shouldShowRichTextCard: Bool {
        hasContent(of: .richText)
    }

    private var shouldShowChecklistCard: Bool {
        hasContent(of: .checklist)
    }

    private var shouldShowPhotosCard: Bool {
        hasContent(of: .photos)
    }

    private var shouldShowLinksCard: Bool {
        hasContent(of: .links)
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
    private var photoViewerContent: some View {
        Group {
            if let contentID = selectedPhotoContentID,
               viewModel.contentQueue.contains(where: { $0.id == contentID && $0.contentType == .photos }) {
                let attachments = getPhotoAttachmentsForViewer(contentID: contentID)
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
            } else {
                photoViewerErrorView
            }
        }
        .onAppear {
            if let contentID = selectedPhotoContentID {
                let attachments = getPhotoAttachmentsForViewer(contentID: contentID)
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
    }

    private func getPhotoAttachmentsForViewer(contentID: UUID) -> [MemoryModel.Attachment] {
        guard contentID == selectedPhotoContentID else {
            return []
        }

        guard viewModel.contentQueue.contains(where: { $0.id == contentID && $0.contentType == .photos }) else {
            return []
        }

        guard let rawAttachments = photoAttachments(for: contentID),
              !rawAttachments.isEmpty else {
            return []
        }

        let flattened = flattenAttachments(rawAttachments)
        guard !flattened.isEmpty else {
            return []
        }

        return flattened
    }

    private func flattenAttachments(_ attachments: [MemoryModel.Attachment]) -> [MemoryModel.Attachment] {
        var flattened: [MemoryModel.Attachment] = []
        for attachment in attachments {
            if attachment.kind == .contentBundle {
                if let bundleAttachments = extractAttachmentsFromBundle(attachment.data) {
                    flattened.append(contentsOf: bundleAttachments)
                }
            } else if attachment.kind == .photo {
                if !attachment.data.isEmpty {
                    flattened.append(attachment)
                }
            }
        }
        return flattened
    }

    private func extractAttachmentsFromBundle(_ bundleData: Data) -> [MemoryModel.Attachment]? {
        let decoder = JSONDecoder()
        guard let bundle = try? decoder.decode(MemoryContentBundle.self, from: bundleData) else {
            return nil
        }
        var extracted: [MemoryModel.Attachment] = []
        for content in bundle.contents {
            if case .photos(let photosContent) = content {
                let attachmentIDs = photosContent.attachmentIDs
                let allAttachments = viewModel.allPhotoAttachments
                let attachmentLookup = Dictionary(uniqueKeysWithValues: allAttachments.map { ($0.id, $0) })
                let matchedAttachments = attachmentIDs.compactMap { attachmentLookup[$0] }
                    .filter { $0.kind == .photo && !$0.data.isEmpty }
                extracted.append(contentsOf: matchedAttachments)
            }
        }
        return extracted.isEmpty ? nil : extracted
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
