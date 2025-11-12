//
//  MemoryTimelineView.swift
//  i-cant-miss
//
//  Created by Codex on 09/03/24.
//

import SwiftUI

struct MemoryTimelineView: View {
    @ObservedObject var memoryService: MemoryService
    let onSelectMemory: (MemoryModel) -> Void
    let onMultiSelectionChange: (Bool) -> Void
    @Binding var navigationPath: NavigationPath

    @EnvironmentObject private var environment: AppEnvironment
    @State private var showingFilterSheet = false
    @State private var searchText = ""
    @State private var selectedMemoryTypes: Set<MemoryType> = []
    @State private var selectedSections: Set<MemoryService.TimelineSection.Kind> = []
    @State private var showInbox = true
    @State private var filterSheetDetent: PresentationDetent = .large
    @State private var collapsedSections: Set<MemoryService.TimelineSection.Kind> = []
    @State private var isInboxExpanded = true
    @State private var autoCollapsedInbox = false
    @State private var isMultiSelecting = false
    @State private var selectedMemoryIDs: Set<MemoryModel.ID> = []
    @State private var isPerformingBulkAction = false
    @State private var showingDeleteConfirmation = false
    @State private var bulkActionErrorMessage: String?

    private var isSearching: Bool {
        !searchText.isEmpty
    }

    private var filteredMemories: [MemoryModel] {
        isSearching ? memoryService.searchMemories(query: searchText) : []
    }

    private var timelineSectionData: [MemoryService.TimelineSection] {
        memoryService.timelineSections()
            .filter { section in
                if selectedSections.isEmpty {
                    return true
                }
                return selectedSections.contains(section.kind)
            }
            .map { section in
                MemoryService.TimelineSection(
                    kind: section.kind,
                    memories: section.memories.filter { memory in
                        isMemoryTypeSelected(memory)
                    }
                )
            }
            .filter { !$0.memories.isEmpty }
    }

    private var filteredInboxMemories: [MemoryModel] {
        memoryService.inboxMemories()
            .filter { isMemoryTypeSelected($0) }
    }

    private var activeFilterCount: Int {
        var count = 0
        if !selectedMemoryTypes.isEmpty && selectedMemoryTypes.count < MemoryType.allCases.count {
            count += selectedMemoryTypes.count
        }
        if !selectedSections.isEmpty && selectedSections.count < MemoryService.TimelineSection.Kind.allCases.count {
            count += selectedSections.count
        }
        if !showInbox {
            count += 1
        }
        return count
    }

    private var filterDescription: String {
        var parts: [String] = []

        if !selectedMemoryTypes.isEmpty && selectedMemoryTypes.count < MemoryType.allCases.count {
            let typeLabels = selectedMemoryTypes
                .map(\.label)
                .sorted()
            parts.append(typeLabels.joined(separator: ", "))
        }

        if !selectedSections.isEmpty && selectedSections.count < MemoryService.TimelineSection.Kind.allCases.count {
            let sectionTitles = selectedSections
                .map(\.title)
                .sorted()
            parts.append(sectionTitles.joined(separator: ", "))
        }

        if !showInbox {
            parts.append("No Inbox")
        }

        return parts.isEmpty ? "All" : parts.joined(separator: " • ")
    }

    private var navigationTitleText: String {
        if isMultiSelecting {
            if selectedMemoryIDs.isEmpty {
                return "Select Memories"
            }
            return "\(selectedMemoryIDs.count) Selected"
        }
        return "Timeline"
    }

    private var bulkActionSpaces: [SpaceModel] {
        environment.spaceService.spaces.filter { $0.id != SpaceModel.allSpacesIdentifier }
    }

    private var selectedMemories: [MemoryModel] {
        selectedMemoryIDs.compactMap { memoryService.memory(id: $0) }
    }

    private var canMoveSelection: Bool {
        !selectedMemoryIDs.isEmpty
    }

    private var canChangeStatusForSelection: Bool {
        guard canMoveSelection else { return false }
        return selectedMemories.allSatisfy { memorySupportsStatusChange($0) }
    }

    private var canChangePriorityForSelection: Bool {
        guard canMoveSelection else { return false }
        return selectedMemories.allSatisfy { memorySupportsPriorityChange($0) }
    }

    private var deleteConfirmationMessage: String {
        let count = selectedMemoryIDs.count
        if count == 1 {
            return "This will permanently remove 1 memory."
        }
        return "This will permanently remove \(count) memories."
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            timelineList
                .navigationTitle(navigationTitleText)
                .searchable(text: $searchText, placement: .navigationBarDrawer, prompt: "Search memories")
                .toolbar {
                    if isMultiSelecting {
                        MemoryMultiSelectToolbarContent(
                            availableSpaces: bulkActionSpaces,
                            isPerformingBulkAction: isPerformingBulkAction,
                            canPerformDeletion: canMoveSelection,
                            isPriorityEnabled: canChangePriorityForSelection,
                            isStatusEnabled: canChangeStatusForSelection,
                            isSpaceEnabled: canMoveSelection && !bulkActionSpaces.isEmpty,
                            onSelectSpace: { space in performMove(to: space) },
                            onSelectStatus: { status in performStatusUpdate(to: status) },
                            onSelectPriority: { priority in performPriorityUpdate(to: priority) },
                            onDelete: { showingDeleteConfirmation = true },
                            onDone: { toggleMultiSelection() }
                        )
                    } else {
                        ToolbarItemGroup(placement: .navigationBarTrailing) {
                            MemoryFilterSummaryButton(
                                activeFilterCount: activeFilterCount,
                                filterDescription: filterDescription,
                                isSheetPresented: showingFilterSheet,
                                isDisabled: isPerformingBulkAction
                            ) {
                                filterSheetDetent = .large
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    showingFilterSheet = true
                                }
                            }

                            Button {
                                toggleMultiSelection()
                            } label: {
                                Label("Select", systemImage: "checkmark.circle")
                            }
                            .disabled(isPerformingBulkAction)
                        }
                    }
                }
                .sheet(isPresented: $showingFilterSheet) {
                    FilterSheetView(
                        selectedMemoryTypes: $selectedMemoryTypes,
                        selectedSections: $selectedSections,
                        showInbox: $showInbox,
                        detentSelection: $filterSheetDetent
                    )
                    .onAppear { filterSheetDetent = .large }
                    .presentationDetents([.large], selection: $filterSheetDetent)
                }
                .alert("Delete selected memories?", isPresented: $showingDeleteConfirmation) {
                    Button("Delete", role: .destructive) {
                        performBulkDeletion()
                    }
                    .disabled(isPerformingBulkAction)

                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text(deleteConfirmationMessage)
                }
                .alert("Unable to complete action", isPresented: Binding(
                    get: { bulkActionErrorMessage != nil },
                    set: { isPresented in
                        if !isPresented {
                            bulkActionErrorMessage = nil
                        }
                    }
                )) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(bulkActionErrorMessage ?? "")
                }
                .onAppear(perform: syncExpansionStates)
                .onChange(of: timelineSectionData.count) {
                    syncExpansionStates()
                }
                .onChange(of: filteredInboxMemories.count) {
                    syncExpansionStates()
                }
                .onChange(of: isInboxExpanded) {
                    autoCollapsedInbox = filteredInboxMemories.isEmpty && !isInboxExpanded
                }
                .onChange(of: isMultiSelecting) { _, newValue in
                    onMultiSelectionChange(newValue)
                }
                .onAppear {
                    onMultiSelectionChange(isMultiSelecting)
                }
                .onDisappear {
                    onMultiSelectionChange(false)
                }
        }
    }

    private var timelineList: some View {
        List {
            if isSearching {
                searchResultsList
            } else {
                timelineSectionsList
                if showInbox {
                    inboxListContent
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .environment(\.defaultMinListRowHeight, 0)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 70)
        }
        .listRowSeparator(.hidden)
        .background(Color.clear)
    }

    @ViewBuilder
    private var searchResultsList: some View {
        if filteredMemories.isEmpty {
            MemoryEmptyStateCard(
                systemImage: "magnifyingglass",
                title: "No memories match your search",
                message: "Try different keywords or reset filters to discover more memories."
            )
            .padding(.top, 16)
            .listRowInsets(.init(top: 16, leading: 20, bottom: 24, trailing: 20))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        } else {
            ForEach(filteredMemories) { memory in
                memoryRow(for: memory)
            }
        }
    }

    @ViewBuilder
    private var timelineSectionsList: some View {
        let sections = timelineSectionData
        let hasInboxContent = showInbox && !filteredInboxMemories.isEmpty

        if sections.isEmpty && !hasInboxContent {
            MemoryEmptyStateCard(
                systemImage: "tray",
                title: "No memories with active triggers",
                message: "Create or activate reminders to see them organized on your timeline."
            )
            .padding(.top, 16)
            .listRowInsets(.init(top: 24, leading: 20, bottom: 8, trailing: 20))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        } else {
            ForEach(sections) { section in
                MemoryDisclosureListSection(
                    title: section.kind.title,
                    systemImage: section.kind.systemImage,
                    isExpanded: sectionExpansionBinding(for: section.kind),
                    memories: section.memories,
                    isMultiSelecting: isMultiSelecting,
                    selectedMemoryIDs: selectedMemoryIDs,
                    isDisabled: isPerformingBulkAction,
                    onSelect: onSelectMemory,
                    onToggleSelection: toggleMemorySelection(_:))
            }
        }
    }

    @ViewBuilder
    private var inboxListContent: some View {
        let inboxMemories = filteredInboxMemories
        let hasTimelineContent = !timelineSectionData.isEmpty
        let shouldShowEmptyState = inboxMemories.isEmpty && !hasTimelineContent

        if inboxMemories.isEmpty {
            if shouldShowEmptyState {
                MemoryEmptyStateCard(
                    systemImage: "checkmark.seal",
                    title: "Inbox is clear",
                    message: "Create a memory or capture a reminder to keep building your inbox."
                )
                .padding(.top, 16)
                .listRowInsets(.init(top: 24, leading: 20, bottom: 24, trailing: 20))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        } else {
            Section {
                inboxHeaderRow(memories: inboxMemories)

                if isInboxExpanded {
                    ForEach(inboxMemories) { memory in
                        MemoryListItemButton(
                            memory: memory,
                            isMultiSelecting: isMultiSelecting,
                            isSelected: isMemorySelected(memory),
                            isDisabled: isPerformingBulkAction,
                            onSelect: onSelectMemory,
                            onToggleSelection: toggleMemorySelection(_:))
                        .listRowInsets(.init(top: 12, leading: 20, bottom: 12, trailing: 20))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }
            }
            .listSectionSeparator(.hidden)
        }
    }

    private func inboxHeaderRow(memories: [MemoryModel]) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isInboxExpanded.toggle()
            }
        } label: {
            HStack(spacing: 12) {
                Label("Inbox", systemImage: "tray.fill")
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: isInboxExpanded ? "chevron.down" : "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .listRowInsets(.init(top: 24, leading: 20, bottom: isInboxExpanded && !memories.isEmpty ? 0 : 12, trailing: 20))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .disabled(memories.isEmpty)
    }

    private func memoryRow(for memory: MemoryModel) -> some View {
        MemoryListItemButton(
            memory: memory,
            isMultiSelecting: isMultiSelecting,
            isSelected: isMemorySelected(memory),
            isDisabled: isPerformingBulkAction,
            onSelect: onSelectMemory,
            onToggleSelection: toggleMemorySelection(_:))
        .listRowInsets(.init(top: 8, leading: 20, bottom: 8, trailing: 20))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private func isMemoryTypeSelected(_ memory: MemoryModel) -> Bool {
        if selectedMemoryTypes.isEmpty {
            return true
        }
        guard let origin = memory.metadata.origin else { return true }

        switch origin {
        case .reminder:
            return selectedMemoryTypes.contains(.reminder)
        case .note:
            return selectedMemoryTypes.contains(.note)
        case .todoList:
            return selectedMemoryTypes.contains(.todo)
        }
    }

    private func sectionExpansionBinding(for kind: MemoryService.TimelineSection.Kind) -> Binding<Bool> {
        Binding(
            get: { !collapsedSections.contains(kind) },
            set: { isExpanded in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    if isExpanded {
                        collapsedSections.remove(kind)
                    } else {
                        collapsedSections.insert(kind)
                    }
                }
            }
        )
    }

    private func toggleMemorySelection(_ memory: MemoryModel) {
        let id = memory.id
        if selectedMemoryIDs.contains(id) {
            selectedMemoryIDs.remove(id)
        } else {
            selectedMemoryIDs.insert(id)
        }
    }

    private func syncExpansionStates() {
        if filteredInboxMemories.isEmpty {
            if isInboxExpanded {
                isInboxExpanded = false
                autoCollapsedInbox = true
            }
        } else if autoCollapsedInbox && !isInboxExpanded {
            isInboxExpanded = true
            autoCollapsedInbox = false
        }
    }

    private func isMemorySelected(_ memory: MemoryModel) -> Bool {
        selectedMemoryIDs.contains(memory.id)
    }

    private func toggleMultiSelection() {
        if isMultiSelecting {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isMultiSelecting = false
            }
            selectedMemoryIDs.removeAll()
        } else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isMultiSelecting = true
            }
            selectedMemoryIDs.removeAll()
            searchText = ""
        }
        showingFilterSheet = false
        showingDeleteConfirmation = false
    }

    private func performMove(to space: SpaceModel) {
        performBulkAction { processor, ids in
            await processor.moveMemories(ids, to: space)
        }
    }

    private func performStatusUpdate(to status: MemoryStatus) {
        performBulkAction { processor, ids in
            await processor.updateStatus(of: ids, to: status)
        }
    }

    private func performPriorityUpdate(to priority: MemoryPriority) {
        performBulkAction { processor, ids in
            await processor.updatePriority(of: ids, to: priority)
        }
    }

    private func performBulkAction(
        _ action: @escaping (MemoryBulkActionProcessor, Set<MemoryModel.ID>) async -> MemoryBulkActionProcessor.MemoryBulkActionResult
    ) {
        let ids = selectedMemoryIDs
        guard !ids.isEmpty, !isPerformingBulkAction else { return }

        isPerformingBulkAction = true
        Task {
            let processor = MemoryBulkActionProcessor(environment: environment)
            let result = await action(processor, ids)
            await MainActor.run {
                handleBulkActionResult(result)
            }
        }
    }

    private func handleBulkActionResult(_ result: MemoryBulkActionProcessor.MemoryBulkActionResult) {
        isPerformingBulkAction = false

        if result.hasSuccesses {
            selectedMemoryIDs.subtract(result.succeededIDs)
        }

        if result.hasFailures {
            bulkActionErrorMessage = bulkActionFailureMessage(from: result.failedIDs)
        }
    }

    private func bulkActionFailureMessage(from failures: [UUID: Error]) -> String {
        guard let firstError = failures.values.first else {
            return "Unable to complete the requested action."
        }

        if failures.count == 1 {
            return firstError.localizedDescription
        }

        return "\(failures.count) memories failed to update. \(firstError.localizedDescription)"
    }

    private func memorySupportsStatusChange(_ memory: MemoryModel) -> Bool {
        guard let origin = memory.metadata.origin else { return false }
        switch origin {
        case .reminder, .todoList:
            return true
        case .note:
            return false
        }
    }

    private func memorySupportsPriorityChange(_ memory: MemoryModel) -> Bool {
        guard let origin = memory.metadata.origin else { return false }
        switch origin {
        case .reminder:
            return true
        case .note, .todoList:
            return false
        }
    }

    private func performBulkDeletion() {
        let ids = selectedMemoryIDs
        guard !ids.isEmpty else { return }
        isPerformingBulkAction = true
        Task {
            await deleteMemories(withIDs: ids)
            await MainActor.run {
                selectedMemoryIDs.removeAll()
                isMultiSelecting = false
                isPerformingBulkAction = false
            }
        }
    }

    private func deleteMemories(withIDs ids: Set<MemoryModel.ID>) async {
        for id in ids {
            guard let memory = memoryService.memory(id: id),
                  let origin = memory.metadata.origin else {
                continue
            }

            do {
                switch origin {
                case .reminder(let reminderID):
                    try await environment.reminderService.deleteReminder(id: reminderID)
                case .note(let noteID):
                    try await environment.noteService.deleteNote(id: noteID)
                case .todoList(let listID):
                    try await environment.todoService.deleteList(id: listID)
                }
            } catch {
                // Silently ignore failures for now; individual services surface errors independently.
            }
        }

        await memoryService.refresh(force: true)
    }

}

enum MemoryType: String, CaseIterable, Identifiable {
    case reminder
    case note
    case todo

    var id: String { rawValue }

    var label: String {
        switch self {
        case .reminder: return "Reminders"
        case .note: return "Notes"
        case .todo: return "Todos"
        }
    }

    var systemImage: String {
        switch self {
        case .reminder: return "bell.fill"
        case .note: return "note.text"
        case .todo: return "checklist"
        }
    }
}

#Preview {
    let environment = AppEnvironment(persistence: PersistenceController.preview)
    environment.bootstrap()
    return MemoryTimelineView(
        memoryService: environment.memoryService,
        onSelectMemory: { _ in },
        onMultiSelectionChange: { _ in },
        navigationPath: .constant(NavigationPath())
    )
    .environmentObject(environment)
}
