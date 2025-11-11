//
//  SpaceDetailView.swift
//  i-cant-miss
//
//  Created by Codex on 09/03/24.
//

import SwiftUI

struct SpaceDetailView: View {
    let space: SpaceModel

    @EnvironmentObject private var environment: AppEnvironment
    @ObservedObject var spaceService: SpaceService
    @ObservedObject var memoryService: MemoryService

    let onCreateMemory: (SpaceModel?) -> Void
    let onSelectMemory: (MemoryModel) -> Void
    let onCreateSpace: (SpaceModel?) -> Void

    @State private var showingFilterSheet = false
    @State private var selectedMemoryTypes: Set<MemoryType> = []
    @State private var selectedSections: Set<MemoryService.TimelineSection.Kind> = []
    @State private var showInbox = true
    @State private var filterSheetDetent: PresentationDetent = .large
    @State private var searchText = ""
    @State private var collapsedSections: Set<MemoryService.TimelineSection.Kind> = []
    @State private var isInboxExpanded = true
    @State private var isUpcomingExpanded = true
    @State private var isOtherExpanded = true
    @State private var autoCollapsedInbox = false
    @State private var autoCollapsedUpcoming = false
    @State private var isMultiSelecting = false
    @State private var selectedMemoryIDs: Set<MemoryModel.ID> = []
    @State private var isPerformingBulkAction = false
    @State private var showingDeleteConfirmation = false

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

    private var isFiltering: Bool {
        activeFilterCount > 0 || isSearching
    }

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSearching: Bool {
        !trimmedSearchText.isEmpty
    }

    private var resolvedSpace: SpaceModel {
        spaceService.space(id: space.id) ?? space
    }

    private var isAllSpace: Bool {
        resolvedSpace.isAllSpaces
    }

    private var nonInboxMemories: [MemoryModel] {
        filteredMemories.filter { !isInboxMemory($0) }
    }

    private var inboxMemories: [MemoryModel] {
        filteredMemories.filter { isInboxMemory($0) }
    }

    private var timelineSectionsForSpace: [MemoryService.TimelineSection] {
        let referenceDate = Date()
        var sections: [MemoryService.TimelineSection] = []

        for kind in MemoryService.TimelineSection.Kind.allCases {
            let memories = nonInboxMemories.filter { memory in
                switch kind {
                case .recurring:
                    return memory.hasRecurringTriggers
                default:
                    guard let sectionKind = sectionKind(for: memory, referenceDate: referenceDate) else {
                        return false
                    }
                    return sectionKind == kind
                }
            }

            if !memories.isEmpty {
                sections.append(MemoryService.TimelineSection(kind: kind, memories: memories))
            }
        }

        return sections
    }

    private var ungroupedMemories: [MemoryModel] {
        let sectionIDs = Set(timelineSectionsForSpace.flatMap(\.memories).map(\.id))
        return nonInboxMemories.filter { !sectionIDs.contains($0.id) }
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

    private var emptyStateTitle: String {
        isFiltering ? "No memories match these filters" : "No memories yet"
    }

    private var emptyStateMessage: String {
        isFiltering
            ? "Try adjusting the filters or reset them to see more memories."
            : "Create a memory to get started in this space."
    }

    private var navigationTitleText: String {
        if isMultiSelecting {
            if selectedMemoryIDs.isEmpty {
                return "Select Memories"
            }
            return "\(selectedMemoryIDs.count) Selected"
        }
        return resolvedSpace.name
    }

    private var deleteConfirmationMessage: String {
        let count = selectedMemoryIDs.count
        if count == 1 {
            return "This will permanently remove 1 memory."
        }
        return "This will permanently remove \(count) memories."
    }

    private var canCreateSubspace: Bool {
        !resolvedSpace.isAllSpaces && resolvedSpace.id != SpaceModel.inboxIdentifier
    }

    var body: some View {
        ScrollView {
            content
        }
        .navigationTitle(navigationTitleText)
        .searchable(text: $searchText, placement: .navigationBarDrawer, prompt: "Search memories")
        .toolbar { toolbarContent }
        .sheet(isPresented: $showingFilterSheet, content: filterSheetContent)
        .onAppear(perform: syncExpansionStates)
        .onChange(of: timelineSectionsForSpace.count) {
            syncExpansionStates()
        }
        .onChange(of: ungroupedMemories.count) {
            syncExpansionStates()
        }
        .onChange(of: inboxMemories.count) {
            syncExpansionStates()
        }
        .onChange(of: isUpcomingExpanded) {
            autoCollapsedUpcoming = timelineSectionsForSpace.isEmpty && ungroupedMemories.isEmpty && !isUpcomingExpanded
        }
        .onChange(of: isInboxExpanded) {
            autoCollapsedInbox = inboxMemories.isEmpty && !isInboxExpanded
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
    }

    private var childSpaces: [SpaceModel] {
        if isAllSpace {
            return []
        }
        return spaceService.children(of: resolvedSpace)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        SpaceDetailToolbarContent(
            activeFilterCount: activeFilterCount,
            filterDescription: filterDescription,
            isFilterSheetPresented: showingFilterSheet,
            isMultiSelecting: isMultiSelecting,
            isPerformingBulkAction: isPerformingBulkAction,
            hasSelectedMemories: !selectedMemoryIDs.isEmpty,
            canCreateSubspace: canCreateSubspace,
            onShowFilters: presentFilterSheet,
            onToggleMultiSelection: toggleMultiSelection,
            onRequestDeletion: { showingDeleteConfirmation = true },
            onCreateMemory: { onCreateMemory(isAllSpace ? nil : resolvedSpace) },
            onCreateSpace: { onCreateSpace(isAllSpace ? nil : resolvedSpace) }
        )
    }

    @ViewBuilder
    private func filterSheetContent() -> some View {
        FilterSheetView(
            selectedMemoryTypes: $selectedMemoryTypes,
            selectedSections: $selectedSections,
            showInbox: $showInbox,
            detentSelection: $filterSheetDetent
        )
        .onAppear { filterSheetDetent = .large }
        .presentationDetents([.large], selection: $filterSheetDetent)
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 22) {
            subspacesSection
            mainSection
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 70)
    }

    @ViewBuilder
    private var subspacesSection: some View {
        if !childSpaces.isEmpty {
            SpaceDetailSubspacesSection(
                childSpaces: childSpaces,
                spaceService: spaceService,
                memoryCountProvider: memoryCount(for:),
                parentLookup: { id in spaceService.space(id: id) }
            )
        }
    }

    @ViewBuilder
    private var mainSection: some View {
        if isSearching {
            SpaceDetailSearchResultsView(
                memories: filteredMemories,
                isMultiSelecting: isMultiSelecting,
                isPerformingBulkAction: isPerformingBulkAction,
                isMemorySelected: isMemorySelected(_:),
                onSelectMemory: onSelectMemory,
                onToggleSelection: toggleMemorySelection(_:)
            )
        } else {
            timelineAndInboxSection
        }
    }

    @ViewBuilder
    private var timelineAndInboxSection: some View {
        SpaceDetailTimelineContentView(
            sections: timelineSectionsForSpace,
            ungroupedMemories: ungroupedMemories,
            emptyStateTitle: emptyStateTitle,
            emptyStateMessage: emptyStateMessage,
            isMultiSelecting: isMultiSelecting,
            selectedMemoryIDs: selectedMemoryIDs,
            isPerformingBulkAction: isPerformingBulkAction,
            isUpcomingExpanded: $isUpcomingExpanded,
            isOtherExpanded: $isOtherExpanded,
            sectionExpansionProvider: sectionExpansionBinding(for:),
            isMemorySelected: isMemorySelected(_:),
            onSelectMemory: onSelectMemory,
            onToggleSelection: toggleMemorySelection(_:)
        )

        if showInbox {
            SpaceDetailInboxSectionView(
                inboxMemories: inboxMemories,
                isMultiSelecting: isMultiSelecting,
                selectedMemoryIDs: selectedMemoryIDs,
                isPerformingBulkAction: isPerformingBulkAction,
                isInboxExpanded: $isInboxExpanded,
                onSelectMemory: onSelectMemory,
                onToggleSelection: toggleMemorySelection(_:)
            )
        }
    }

    private func presentFilterSheet() {
        filterSheetDetent = .large
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showingFilterSheet = true
        }
    }

    private func syncExpansionStates() {
        let timelineIsEmpty = timelineSectionsForSpace.isEmpty && ungroupedMemories.isEmpty
        if timelineIsEmpty {
            if isUpcomingExpanded {
                isUpcomingExpanded = false
                autoCollapsedUpcoming = true
            }
        } else if autoCollapsedUpcoming && !isUpcomingExpanded {
            isUpcomingExpanded = true
            autoCollapsedUpcoming = false
        }

        let inboxIsEmpty = inboxMemories.isEmpty
        if inboxIsEmpty {
            if isInboxExpanded {
                isInboxExpanded = false
                autoCollapsedInbox = true
            }
        } else if autoCollapsedInbox && !isInboxExpanded {
            isInboxExpanded = true
            autoCollapsedInbox = false
        }
    }
    private var filteredMemories: [MemoryModel] {
        let targetSpace = isAllSpace ? nil : resolvedSpace
        let base = memoryService.memories(
            in: targetSpace,
            includeDescendants: false,
            statuses: [],
            includeCompleted: true,
            includeArchived: true,
            sort: .updatedAtDescending
        )

        let referenceDate = Date()
        let query = trimmedSearchText

        return base.filter { memory in
            matchesSelectedType(memory) &&
            matchesSelectedSection(memory, referenceDate: referenceDate) &&
            (showInbox || !isInboxMemory(memory)) &&
            matchesSearch(memory, query: query)
        }
    }

    private func matchesSelectedType(_ memory: MemoryModel) -> Bool {
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

    private func matchesSelectedSection(_ memory: MemoryModel, referenceDate: Date = Date()) -> Bool {
        if selectedSections.isEmpty || selectedSections.count == MemoryService.TimelineSection.Kind.allCases.count {
            return true
        }

        if selectedSections.contains(.recurring), memory.hasRecurringTriggers {
            return true
        }

        guard memory.status == .active,
              memory.hasTriggers,
              let kind = sectionKind(for: memory, referenceDate: referenceDate) else {
            return false
        }

        return selectedSections.contains(kind)
    }

    private func sectionKind(for memory: MemoryModel, referenceDate: Date = Date()) -> MemoryService.TimelineSection.Kind? {
        guard let fireDate = memory.nextFireDate(referenceDate: referenceDate) else { return nil }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: referenceDate)
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? referenceDate
        let sevenDaysOut = calendar.date(byAdding: .day, value: 7, to: startOfTomorrow) ?? referenceDate

        if calendar.isDate(fireDate, inSameDayAs: referenceDate) {
            return .today
        } else if fireDate < sevenDaysOut {
            return .nextSevenDays
        } else {
            return .later
        }
    }

    private func isInboxMemory(_ memory: MemoryModel) -> Bool {
        memory.status == .active && !memory.hasTriggers
    }

    private func memoryCount(for space: SpaceModel) -> Int {
        let ids = spaceService.descendantIDs(of: space)
        return memoryService.memories.filter { ids.contains($0.space.id) }.count
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

    private func matchesSearch(_ memory: MemoryModel, query: String) -> Bool {
        guard !query.isEmpty else { return true }

        if memory.title.localizedCaseInsensitiveContains(query) {
            return true
        }

        if let body = memory.body, body.localizedCaseInsensitiveContains(query) {
            return true
        }

        return false
    }

    private func isMemorySelected(_ memory: MemoryModel) -> Bool {
        selectedMemoryIDs.contains(memory.id)
    }

    private func toggleMemorySelection(_ memory: MemoryModel) {
        let id = memory.id
        if selectedMemoryIDs.contains(id) {
            selectedMemoryIDs.remove(id)
        } else {
            selectedMemoryIDs.insert(id)
        }
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
                // Failures are handled individually by each service.
            }
        }

        await memoryService.refresh(force: true)
    }
}

#Preview {
    let environment = AppEnvironment(persistence: PersistenceController.preview)
    environment.bootstrap()
    return SpacesRootView(
        spaceService: environment.spaceService,
        memoryService: environment.memoryService,
        navigationPath: .constant(NavigationPath()),
        onCreateMemory: { _ in },
        onSelectMemory: { _ in },
        onCreateSpace: { _ in }
    )
    .environmentObject(environment)
}
