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
    let onCreateSpace: () -> Void

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

    var body: some View {
        ScrollView{
            VStack(alignment: .leading, spacing: 22) {
                if !childSpaces.isEmpty {
                    Section("Subspaces") {
                        ForEach(childSpaces) { child in
                            NavigationLink(value: child) {
                                SpaceRowView(
                                    space: child,
                                    count: memoryCount(for: child),
                                    parentLookup: spaceService.space(id:)
                                )
                            }
                        }
                    }
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
        .navigationTitle(space.name)
        .searchable(text: $searchText, placement: .navigationBarDrawer, prompt: "Search memories")
        .toolbar {
            ToolbarItem(placement: .principal) {
                filterSummaryButton
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    onCreateMemory(space)
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
    }

    private var filterSummaryButton: some View {
        Button {
            filterSheetDetent = .large
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showingFilterSheet = true
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: activeFilterCount > 0 ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    .symbolEffect(.bounce, value: activeFilterCount)
                Text(filterDescription)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .contentTransition(.opacity)
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .rotationEffect(.degrees(showingFilterSheet ? 180 : 0))
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showingFilterSheet)
            }
            .foregroundStyle(activeFilterCount > 0 ? Color.accent : .primary)
            .padding(10)
            .glassEffect(.regular.interactive())
        }
    }

    private var childSpaces: [SpaceModel] {
        spaceService.children(of: space)
    }

    @ViewBuilder
    private var searchResultsSection: some View {
        Section {
            if filteredMemories.isEmpty {
                emptyStateCard(
                    systemImage: "magnifyingglass",
                    title: "No memories match your search",
                    message: "Try different keywords or reset filters to discover more memories."
                )
            } else {
                ForEach(filteredMemories) { memory in
                    memoryButton(for: memory)
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
                        emptyStateCard(
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
                        VStack(alignment: .leading, spacing: 8) {
                            DisclosureGroup(
                                isExpanded: sectionExpansionBinding(for: section.kind)
                            ) {
                                VStack(alignment: .leading, spacing: 12) {
                                    ForEach(section.memories) { memory in
                                        memoryButton(for: memory)
                                    }
                                }
                                .padding(.top)
                            } label: {
                                Label(section.kind.title, systemImage: section.kind.systemImage)
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding(.top)
                    }

                    if !ungroupedMemories.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            DisclosureGroup(isExpanded: $isOtherExpanded) {
                                VStack(alignment: .leading, spacing: 12) {
                                    ForEach(ungroupedMemories) { memory in
                                        memoryButton(for: memory)
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
                    emptyStateCard(
                        systemImage: "checkmark.seal",
                        title: "Inbox is clear",
                        message: "Create a memory or capture a reminder to keep building your inbox."
                    )
                    .padding(.top)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(inboxMemories) { memory in
                            memoryButton(for: memory)
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

    private var filteredMemories: [MemoryModel] {
        let base = memoryService.memories(
            in: space,
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

    private func memoryButton(for memory: MemoryModel) -> some View {
        Button {
            onSelectMemory(memory)
        } label: {
            MemoryCardView(memory: memory)
        }
        .buttonStyle(.plain)
    }

    private func emptyStateCard(systemImage: String, title: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.top, 8)
        .glassEffect(in: .rect(cornerRadius: 16.0))
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
        onCreateSpace: {}
    )
    .environmentObject(environment)
}
