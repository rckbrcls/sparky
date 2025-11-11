//
//  MemoryEditorView.swift
//  i-cant-miss
//
//  Created by Codex on 09/03/24.
//

import SwiftUI
import UIKit

struct MemoryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: MemoryEditorViewModel
    @State private var showDueDateSheet = false
    @State private var showExactTimeSheet = false
    @State private var showWeekdaySheet = false
    @State private var showTriggerPickerSheet = false
    @State private var showLocationPicker = false
    @State private var showPersonSheet = false
    @State private var showSequentialSheet = false
    @State private var checklistDraftRows: [ChecklistDraftRow] = [ChecklistDraftRow()]
    @FocusState private var focusedDraftID: UUID?
    @FocusState private var isTitleFocused: Bool
    @State private var scrollOffset: CGFloat = 20
    @State private var scrollViewProxy: ScrollViewProxy?
    @State private var isDetailsExpanded = false
    @State private var isPreferencesExpanded = false
    @State private var expandedHeaderHeight: CGFloat = 148
    @StateObject private var bodyEditorController = RichTextEditorController()
    @State private var isAddContentMenuExpanded = false
    @State private var hasEnabledRichTextManually = false
    @State private var hasEnabledPhotosManually = false
    @State private var hasInitializedContentState = false

    private let isEditing: Bool
    private let minHeaderHeight: CGFloat = 76
    private let transitionThreshold: CGFloat = 32


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
            ZStack(alignment: .top) {
                let headerTransitionRange = max(expandedHeaderHeight - minHeaderHeight, 1)
                let fadeZoneLength = min(48, headerTransitionRange)
                let fadeZoneStart = headerTransitionRange - fadeZoneLength
                let showMinimizedHeader = scrollOffset >= headerTransitionRange

                let expandedOpacity = scrollOffset < fadeZoneStart ? 1.0 : max(0, min(1, 1 - ((scrollOffset - fadeZoneStart) / fadeZoneLength)))
                let minimizedOpacity = scrollOffset < fadeZoneStart ? 0.0 : max(0, min(1, (scrollOffset - fadeZoneStart) / fadeZoneLength))

                ZStack(alignment: .top) {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea()
                        .frame(height: max(minHeaderHeight, expandedHeaderHeight - scrollOffset))
                        .allowsHitTesting(true)

                    let minOffset = expandedHeaderHeight - minHeaderHeight
                    let offset = scrollOffset <= 0 ? -scrollOffset : scrollOffset <= minOffset ? -scrollOffset : -minOffset

                    VStack(spacing: 8) {
                        titleHeaderView()
                            .padding(.horizontal, 20)
                    }
                    .padding(.top, 72)
                    .padding(.bottom, 12)
                    .background(
                        GeometryReader { proxy in
                            Color.clear
                                .preference(key: HeaderHeightPreferenceKey.self, value: proxy.size.height)
                        }
                    )
                    .frame(maxWidth: .infinity)
                    .offset(y: offset)
                    .opacity(expandedOpacity)
                }
                .onPreferenceChange(HeaderHeightPreferenceKey.self) { newHeight in
                    guard newHeight > 0 else { return }
                    let clampedHeight = max(newHeight, minHeaderHeight + 20)
                    if abs(expandedHeaderHeight - clampedHeight) > 0.5 {
                        expandedHeaderHeight = clampedHeight
                    }
                }
                .zIndex(10)

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            Color.clear
                                .frame(height: expandedHeaderHeight - transitionThreshold)
                                .frame(maxWidth: .infinity)
                                .id("scrollTop")

                            editorContent
                        }
                        .padding(.top, 16)
                        .padding()
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onScrollGeometryChange(for: CGFloat.self) { geometry in
                        geometry.contentOffset.y + geometry.contentInsets.top
                    } action: { _, new in
                        scrollOffset = new
                    }
                    .onAppear {
                        scrollViewProxy = proxy
                    }
                }

                VStack(spacing: 0) {
                    Button {
                        scrollToTopAndFocus()
                    } label: {
                        let displayTitle = viewModel.title.trimmingCharacters(in: .whitespacesAndNewlines)
                        Text(displayTitle.isEmpty ? "Memory" : displayTitle)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(displayTitle.isEmpty ? .secondary : .primary)
                            .lineLimit(1)
                            .padding(.horizontal, 76)
                            .padding(.vertical, 20)
                            .frame(height: minHeaderHeight)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .opacity(minimizedOpacity)
                }
                .frame(maxWidth: .infinity)
                .allowsHitTesting(minimizedOpacity > 0.3)
                .zIndex(showMinimizedHeader ? 11 : 9)

                VStack {
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(width: 44, height: 44)
                                .tint(.white)
                                .glassEffect(.regular.interactive())
                        }

                        Spacer()

                        Menu {
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
                                .font(.system(size: 16, weight: .semibold))
                                .frame(width: 44, height: 44)
                        }
                        .tint(.white)
                        .glassEffect(.regular.interactive())

                        Button(role: .confirm) {
                            commitChecklistDrafts()
                            Task {
                                let success = await viewModel.save()
                                if success { dismiss() }
                            }
                        } label: {
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(width: 44, height: 44)
                                .tint(.white)
                                .glassEffect(.regular.tint(.accent).interactive())
                        }
                        .disabled(isSaveDisabled)
                        .opacity(isSaveDisabled ? 0.45 : 1)

                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                    Spacer()
                }
                .zIndex(100)
            }
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
                ToolbarItemGroup(placement: .bottomBar) {
                    MemoryTriggerAddBadge(
                        isPresented: $showTriggerPickerSheet,
                        displayStyle: .toolbar
                    )

                    Spacer()

                    ControlGroup {
                        Button {
                            viewModel.isPinned.toggle()
                        } label: {
                            Image(systemName: viewModel.isPinned ? "pin.fill" : "pin")
                                .foregroundStyle(viewModel.isPinned ? Color.accentColor : .primary)
                        }
                        .accessibilityLabel(viewModel.isPinned ? "Unpin memory" : "Pin memory")

                        Button(action: {}) {
                            Image(systemName: "photo.on.rectangle")
                        }
                        .disabled(true)
                        .accessibilityLabel("Image attachments are disabled")

                        Button(action: {}) {
                            Image(systemName: "camera")
                        }
                        .disabled(true)
                        .accessibilityLabel("Image capture is disabled")
                    }
                }
            }
            .sheet(isPresented: $showDueDateSheet, content: dueDateSheet)
            .sheet(isPresented: $showExactTimeSheet, content: exactTimeSheet)
            .sheet(isPresented: $showWeekdaySheet, content: weekdaySheet)
            .sheet(isPresented: $showTriggerPickerSheet) {
                MemoryTriggerPickerSheet(viewModel: viewModel)
                .presentationDetents([.large])
            }
            .sheet(isPresented: $showLocationPicker, content: locationSheet)
            .sheet(isPresented: $showPersonSheet, content: personSheet)
            .sheet(isPresented: $showSequentialSheet, content: sequentialSheet)
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

    private func titleHeaderView() -> some View {
        VStack(spacing: 12) {
            TextField("Memory", text: $viewModel.title, axis: .vertical)
                .font(.title)
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
        .padding(.vertical, 10)
        .glassEffect(.regular.interactive())
        .contentShape(Rectangle())
        .allowsHitTesting(true)
    }

    private func scrollToTopAndFocus() {
        guard let proxy = scrollViewProxy else { return }

        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            proxy.scrollTo("scrollTop", anchor: .bottom)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            isTitleFocused = true
        }
    }

    private var editorContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            addContentButton
            if isAddContentMenuExpanded {
                MemoryEditorAddContentMenu(
                    options: contentMenuOptions,
                    onSelect: handleAddContentSelection
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            VStack(alignment: .leading, spacing: 20) {
                if shouldShowChecklistCard {
                    checklistCard
                }
                if shouldShowRichTextCard {
                    richTextCard
                }
                if shouldShowPhotosCard {
                    photosCard
                }
            }
            .animation(.easeInOut(duration: 0.2), value: shouldShowChecklistCard)
            .animation(.easeInOut(duration: 0.2), value: shouldShowRichTextCard)
            .animation(.easeInOut(duration: 0.2), value: shouldShowPhotosCard)
        }
        
    }

    private var checklistCard: some View {
        MemoryEditorChecklistCard(subtitle: checklistSubtitle, onRemove: { disableContent(.checklist) }) {
            VStack(alignment: .leading, spacing: 12) {
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
    }

    private var richTextCard: some View {
        MemoryEditorRichTextCard(
            text: $viewModel.body,
            controller: bodyEditorController,
            onRemove: { disableContent(.richText) }
        )
    }

    private var photosCard: some View {
        MemoryEditorPhotosCard(
            attachments: $viewModel.attachments,
            onAddAttachment: { data in
                _ = viewModel.createAttachment(data: data)
            },
            onRemoveAttachment: { id in
                viewModel.removeAttachment(id: id)
            },
            onRemove: { disableContent(.photos) }
        )
    }

    private var addContentButton: some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                isAddContentMenuExpanded.toggle()
            }
        } label: {
            Label("Add content", systemImage: "plus.circle.fill")
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isAddContentMenuExpanded ? "Hide content options" : "Show content options")
        .liquidGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var contentMenuOptions: [MemoryEditorAddContentMenu.Option] {
        MemoryEditorContentType.allCases.map { type in
            MemoryEditorAddContentMenu.Option(
                id: type,
                iconName: type.iconName,
                title: type.title,
                subtitle: type.subtitle,
                isActive: isContentActive(type)
            )
        }
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

    private var checklistSubtitle: String? {
        guard !viewModel.checklistItems.isEmpty else { return nil }
        let completed = viewModel.checklistItems.filter(\.isCompleted).count
        return "\(completed) of \(viewModel.checklistItems.count) completed"
    }

    private func handleAddContentSelection(_ type: MemoryEditorContentType) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            isAddContentMenuExpanded = false
        }

        switch type {
        case .richText:
            hasEnabledRichTextManually = true
        case .checklist:
            if !viewModel.showChecklist {
                viewModel.showChecklist = true
            }
            if viewModel.checklistItems.isEmpty && checklistDraftRows.isEmpty {
                let placeholder = ChecklistDraftRow()
                checklistDraftRows = [placeholder]
                focusedDraftID = placeholder.id
            } else if let firstDraft = checklistDraftRows.first {
                focusedDraftID = firstDraft.id
            }
        case .photos:
            hasEnabledPhotosManually = true
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
        }
    }

    private func isContentActive(_ type: MemoryEditorContentType) -> Bool {
        switch type {
        case .richText:
            return shouldShowRichTextCard
        case .checklist:
            return shouldShowChecklistCard
        case .photos:
            return shouldShowPhotosCard
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
