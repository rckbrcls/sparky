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
    @StateObject private var bodyEditorController = RichTextEditorController()
    @State private var hasEnabledRichTextManually = false
    @State private var hasEnabledPhotosManually = false
    @State private var hasEnabledLinksManually = false
    @State private var hasInitializedContentState = false

    private let isEditing: Bool


    init(environment: AppEnvironment,
         memory: MemoryModel? = nil,
         defaultSpace: SpaceModel? = nil,
         template: MemoryEditorTemplate = .blank) {
        _viewModel = StateObject(wrappedValue: MemoryEditorViewModel(
            environment: environment,
            attachmentStore: environment.attachmentStore,
            memory: memory,
            defaultSpace: defaultSpace,
            template: template
        ))
        self.isEditing = memory != nil
    }

    var body: some View {
        NavigationStack {
            editorContent
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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) {
                        dismiss()
                    } label: {
                        Label("Cancel", systemImage: "xmark")
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        commitChecklistDrafts()
                        Task {
                            let success = await viewModel.save()
                            if success { dismiss() }
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

                ToolbarItemGroup(placement: .bottomBar) {


                    ControlGroup {
                        addRichTextButton
                        addChecklistButton
                        photoToolbarControls
                        addLinkButton
                    }

                    Spacer()

                    MemoryTriggerAddBadge(
                        isPresented: $showTriggerPickerSheet,
                        displayStyle: .toolbar
                    )
                }
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
            .onChange(of: viewModel.body) { _, newValue in
                guard !hasEnabledRichTextManually else { return }
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    hasEnabledRichTextManually = true
                }
            }
            .onChange(of: viewModel.attachments) { _, newValue in
                guard !hasEnabledPhotosManually else { return }
                if !newValue.isEmpty {
                    hasEnabledPhotosManually = true
                }
            }
            .onChange(of: viewModel.linkAttachments) { _, newValue in
                guard !hasEnabledLinksManually else { return }
                if !newValue.isEmpty {
                    hasEnabledLinksManually = true
                }
            }
            .onChange(of: photoPickerItems) { _, newItems in
                guard !newItems.isEmpty else { return }
                hasEnabledPhotosManually = true
                Task {
                    await loadSelectedPhotos(from: newItems)
                }
            }
        }
    }

    private var memoryLookup: [UUID: MemoryModel] {
        Dictionary(uniqueKeysWithValues: viewModel.environment.memoryService.memories.map { ($0.id, $0) })
    }

    private var navigationTitle: String { isEditing ? "Edit Memory" : "New Memory" }

    private var saveButtonTitle: String { isEditing ? "Save" : "Create" }

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
                        onToggle: { viewModel.toggleChecklistCompletion(for: item.id) },
                        onDelete: { removeChecklist(item) }
                    )
                }
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
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                disableContent(.checklist)
            } label: {
                Label("Delete Checklist", systemImage: "trash")
            }
            .accessibilityLabel("Delete checklist content")
        }
    }

    private var richTextCard: some View {
        MemoryEditorRichTextCard(
            text: $viewModel.body,
            controller: bodyEditorController
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                disableContent(.richText)
            } label: {
                Label("Delete Text", systemImage: "trash")
            }
            .accessibilityLabel("Delete rich text content")
        }
    }

    private var photosCard: some View {
        MemoryEditorPhotosCard(
            attachments: $viewModel.attachments,
            isLoading: isLoadingPhotos,
            onRemoveAttachment: { id in
                viewModel.removeAttachment(id: id)
            }
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                disableContent(.photos)
            } label: {
                Label("Delete Photos", systemImage: "trash")
            }
            .accessibilityLabel("Delete photos content")
        }
    }

    private var linksCard: some View {
        MemoryEditorLinksCard(
            links: $viewModel.linkAttachments,
            onRemoveLink: { id in
                viewModel.removeLinkAttachment(id: id)
            }
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                disableContent(.links)
            } label: {
                Label("Delete Links", systemImage: "trash")
            }
            .accessibilityLabel("Delete links content")
        }
    }

    private var addRichTextButton: some View {
        Button {
            handleAddContentSelection(.richText)
        } label: {
            Label("Add rich text", systemImage: MemoryEditorContentType.richText.iconName)
        }
        .labelStyle(.iconOnly)
        .foregroundStyle(shouldShowRichTextCard ? Color.accentColor : .primary)
        .accessibilityLabel("Add rich text")
    }

    private var addChecklistButton: some View {
        Button {
            handleAddContentSelection(.checklist)
        } label: {
            Label("Add checklist", systemImage: MemoryEditorContentType.checklist.iconName)
        }
        .labelStyle(.iconOnly)
        .foregroundStyle(shouldShowChecklistCard ? Color.accentColor : .primary)
        .accessibilityLabel("Add checklist")
    }

    private var photoToolbarControls: some View {
        MemoryEditorPhotoToolbarControls(
            isHighlighted: shouldShowPhotosCard,
            isEnabled: !viewModel.isSaving && !isLoadingPhotos,
            onLibraryTap: handleLibraryToolbarTap,
            onCameraTap: handleCameraToolbarTap
        )
    }

    private var addLinkButton: some View {
        Button {
            handleAddContentSelection(.links)
        } label: {
            Label("Add link", systemImage: MemoryEditorContentType.links.iconName)
        }
        .labelStyle(.iconOnly)
        .foregroundStyle(shouldShowLinksCard ? Color.accentColor : .primary)
        .accessibilityLabel("Add link")
    }

    private var shouldShowChecklistCard: Bool {
        viewModel.showChecklist || !viewModel.checklistItems.isEmpty
    }

    private var shouldShowRichTextCard: Bool {
        hasEnabledRichTextManually || !viewModel.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var shouldShowPhotosCard: Bool {
        hasEnabledPhotosManually || !viewModel.attachments.isEmpty
    }

    private var shouldShowLinksCard: Bool {
        hasEnabledLinksManually || !viewModel.linkAttachments.isEmpty
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
            hasEnabledPhotosManually = true
        case .links:
            hasEnabledLinksManually = true
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
            hasEnabledPhotosManually = false
            isLoadingPhotos = false
            isPresentingPhotoLibrary = false
        case .links:
            viewModel.linkAttachments.removeAll()
            hasEnabledLinksManually = false
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
        if !viewModel.attachments.isEmpty {
            hasEnabledPhotosManually = true
        }
        if !viewModel.linkAttachments.isEmpty {
            hasEnabledLinksManually = true
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
        hasEnabledPhotosManually = true
        isPresentingCamera = true
    }

    private func handleLibraryToolbarTap() {
        hasEnabledPhotosManually = true
        isPresentingPhotoLibrary = true
    }

    private func handleCapturedImage(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.85) else { return }
        _ = viewModel.createAttachment(data: data)
    }

    private func handleLinkAdded(_ url: URL) {
        hasEnabledLinksManually = true
        let alreadyExists = viewModel.linkAttachments.contains {
            $0.url?.absoluteString == url.absoluteString
        }
        guard !alreadyExists else { return }
        _ = viewModel.createLinkAttachment(url: url)
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

#Preview {
    let environment = AppEnvironment(persistence: PersistenceController.preview)
    environment.bootstrap()
    return MemoryEditorView(environment: environment)
}
