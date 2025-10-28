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
    @State private var selectedMemoryType: MemoryType?
    @State private var selectedSection: MemoryService.TimelineSection.Kind?
    @State private var showInbox = true
    @State private var filterSheetDetent: PresentationDetent = .large
    @State private var searchText = ""

    private var activeFilterCount: Int {
        var count = 0
        if selectedMemoryType != nil {
            count += 1
        }
        if selectedSection != nil {
            count += 1
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

    private var filterDescription: String {
        var parts: [String] = []

        if let type = selectedMemoryType {
            parts.append(type.label)
        }

        if let section = selectedSection {
            parts.append(section.title)
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
                    memoriesSection
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
                selectedMemoryType: $selectedMemoryType,
                selectedSection: $selectedSection,
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
                Label("No results found", systemImage: "magnifyingglass")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(filteredMemories) { memory in
                    Button {
                        onSelectMemory(memory)
                    } label: {
                        MemoryCardView(memory: memory)
                    }
                    .buttonStyle(.plain)
                }
            }
        } header: {
            Divider()
                .padding(.top, 8)
        }
    }

    @ViewBuilder
    private var memoriesSection: some View {
        Section {
            if filteredMemories.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(.tertiary)
                    Text(emptyStateTitle)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(emptyStateMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 36)
                .padding(.top, 8)
                .glassEffect(in: .rect(cornerRadius: 16.0))
            } else {
                ForEach(filteredMemories) { memory in
                    Button {
                        onSelectMemory(memory)
                    } label: {
                        MemoryCardView(memory: memory)
                    }
                    .buttonStyle(.plain)
                }
            }
        } header: {
            Divider()
                .padding(.top, 8)
        }
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
        guard let selectedType = selectedMemoryType else { return true }
        guard let origin = memory.metadata.origin else { return true }

        switch origin {
        case .reminder:
            return selectedType == .reminder
        case .note:
            return selectedType == .note
        case .todoList:
            return selectedType == .todo
        }
    }

    private func matchesSelectedSection(_ memory: MemoryModel, referenceDate: Date = Date()) -> Bool {
        guard let selected = selectedSection else { return true }

        switch selected {
        case .recurring:
            return memory.hasRecurringTriggers
        case .today, .nextSevenDays, .later:
            guard memory.status == .active,
                  memory.hasTriggers,
                  let kind = sectionKind(for: memory, referenceDate: referenceDate) else {
                return false
            }
            return kind == selected
        }
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

    private func matchesSearch(_ memory: MemoryModel, query: String) -> Bool {
        guard !query.isEmpty else { return true }

        if let title = memory.title, title.localizedCaseInsensitiveContains(query) {
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
