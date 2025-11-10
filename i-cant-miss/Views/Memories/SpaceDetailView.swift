//
//  SpaceDetailView.swift
//  i-cant-miss
//
//  Created by Codex on 09/03/24.
//

import SwiftUI

struct SpaceDetailView: View {
    let space: SpaceModel

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

    private var canCreateSubspace: Bool {
        resolvedSpace.id != SpaceModel.inboxIdentifier
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if !childSpaces.isEmpty {
                    subspacesList
                }

                if isSearching {
                    searchResultsSection
                } else {
                    timelineContent
                    if showInbox {
                        inboxSection
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 70)
        }
        .navigationTitle(resolvedSpace.name)
        .searchable(text: $searchText, placement: .navigationBarDrawer, prompt: "Search memories")
        .toolbar {
            ToolbarItem(placement: .principal) {
                MemoryFilterSummaryButton(
                    activeFilterCount: activeFilterCount,
                    filterDescription: filterDescription,
                    isSheetPresented: showingFilterSheet,
                    paddingInsets: EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
                ) {
                    filterSheetDetent = .large
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showingFilterSheet = true
                    }
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                if canCreateSubspace {
                    Button {
                        onCreateSpace(resolvedSpace)
                    } label: {
                        Image(systemName: "folder.badge.plus")
                    }
                    .accessibilityLabel("Create Space")
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    onCreateMemory(resolvedSpace)
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Create Memory")
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
    }

    private var childSpaces: [SpaceModel] {
        spaceService.children(of: resolvedSpace)
    }

    private var subspacesList: some View {
        List {
            Section("Subspaces") {
                ForEach(childSpaces) { child in
                    NavigationLink(value: child) {
                        SpaceRowView(
                            space: child,
                            count: memoryCount(for: child),
                            parentLookup: spaceService.space(id:)
                        )
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if canDeleteSpace(child) {
                            Button(role: .destructive) {
                                deleteSpace(child)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .listRowSeparator(.hidden)
        .listSectionSeparator(.hidden)
        .scrollContentBackground(.hidden)
        .scrollDisabled(true)
        .frame(height: subspacesListHeight)
        .padding(.horizontal, -16)
    }

    private var subspacesListHeight: CGFloat {
        let rowHeight: CGFloat = 68
        let headerHeight: CGFloat = 48
        return (CGFloat(childSpaces.count) * rowHeight) + headerHeight
    }

    @ViewBuilder
    private var searchResultsSection: some View {
        Section {
            if filteredMemories.isEmpty {
                MemoryEmptyStateCard(
                    systemImage: "magnifyingglass",
                    title: "No memories match your search",
                    message: "Try different keywords or reset filters to discover more memories."
                )
            } else {
                ForEach(filteredMemories) { memory in
                    MemoryListItemButton(
                        memory: memory,
                        isMultiSelecting: false,
                        isSelected: false,
                        isDisabled: false,
                        onSelect: onSelectMemory,
                        onToggleSelection: nil)
                }
            }
        }
    }

    @ViewBuilder
    private var timelineContent: some View {
        let sections = timelineSectionsForSpace

        Section {
            Group {
                if sections.isEmpty && ungroupedMemories.isEmpty {
                    DisclosureGroup(isExpanded: $isUpcomingExpanded) {
                        MemoryEmptyStateCard(
                            systemImage: "tray",
                            title: emptyStateTitle,
                            message: emptyStateMessage
                        )
                        .padding(.top)
                    } label: {
                        Label("Upcoming", systemImage: "calendar")
                            .foregroundStyle(.white)
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isUpcomingExpanded)
                    .padding(.top)
                } else {
                    ForEach(sections) { section in
                        MemoryDisclosureListSection(
                            title: section.kind.title,
                            systemImage: section.kind.systemImage,
                            isExpanded: sectionExpansionBinding(for: section.kind),
                            memories: section.memories,
                            isMultiSelecting: false,
                            selectedMemoryIDs: [],
                            isDisabled: false,
                            onSelect: onSelectMemory,
                            onToggleSelection: nil)
                    }

                    if !ungroupedMemories.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            DisclosureGroup(isExpanded: $isOtherExpanded) {
                                VStack(alignment: .leading, spacing: 12) {
                                    ForEach(ungroupedMemories) { memory in
                                        MemoryListItemButton(
                                            memory: memory,
                                            isMultiSelecting: false,
                                            isSelected: false,
                                            isDisabled: false,
                                            onSelect: onSelectMemory,
                                            onToggleSelection: nil)
                                    }
                                }
                                .padding(.top)
                            } label: {
                                Label("Other Memories", systemImage: "tray")
                                    .foregroundStyle(.white)
                            }
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isOtherExpanded)
                        }
                        .padding(.top)
                    }
                }
            }
        }
    }

    private var inboxSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            DisclosureGroup(isExpanded: $isInboxExpanded) {
                if inboxMemories.isEmpty {
                    MemoryEmptyStateCard(
                        systemImage: "checkmark.seal",
                        title: "Inbox is clear",
                        message: "Create a memory or capture a reminder to keep building your inbox."
                    )
                    .padding(.top)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(inboxMemories) { memory in
                            MemoryListItemButton(
                                memory: memory,
                                isMultiSelecting: false,
                                isSelected: false,
                                isDisabled: false,
                                onSelect: onSelectMemory,
                                onToggleSelection: nil)
                        }
                    }
                    .padding(.top)
                }
            } label: {
                Label("Inbox", systemImage: "tray.fill")
                    .foregroundStyle(.white)
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isInboxExpanded)
        }
        .padding(.top)
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
        let base = memoryService.memories(
            in: resolvedSpace,
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

    private func canDeleteSpace(_ space: SpaceModel) -> Bool {
        space.id != SpaceModel.inboxIdentifier && !space.isDefault
    }

    private func deleteSpace(_ space: SpaceModel) {
        Task { @MainActor in
            do {
                try await spaceService.deleteSpace(space)
            } catch {
                assertionFailure("Failed to delete space: \(error.localizedDescription)")
            }
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
}

#Preview {
    let environment = AppEnvironment(persistence: PersistenceController.preview)
    environment.bootstrap()
    return SpacesRootView(
        spaceService: environment.spaceService,
        memoryService: environment.memoryService,
        onCreateMemory: { _ in },
        onSelectMemory: { _ in },
        onCreateSpace: { _ in }
    )
    .environmentObject(environment)
}
