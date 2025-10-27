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
    @State private var filterSheetDetent: PresentationDetent = .medium

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

    var body: some View {
        ScrollView{
            VStack(alignment: .leading, spacing: 16) {
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

                Section {
                    if filteredMemories.isEmpty {
                        Label("No memories in this space", systemImage: "tray")
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
                }

            }
            .padding(.horizontal, 20)
            .padding(.bottom, 70)
        }
        .navigationTitle(space.name)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button {
                    filterSheetDetent = .medium
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
                            .animation(.easeInOut(duration: 0.2), value: filterDescription)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .rotationEffect(.degrees(showingFilterSheet ? 180 : 0))
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showingFilterSheet)
                    }
                    .foregroundStyle(activeFilterCount > 0 ? Color.accent : .primary)
                    .animation(.easeInOut(duration: 0.2), value: activeFilterCount)
                    .padding(12)
                    .glassEffect(.regular.interactive())
                }
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
            .onAppear { filterSheetDetent = .medium }
            .presentationDetents([.medium, .large], selection: $filterSheetDetent)
        }
        .refreshable {
            await refresh()
        }
    }

    private var childSpaces: [SpaceModel] {
        spaceService.children(of: space)
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

        return base.filter { memory in
            matchesSelectedType(memory) &&
            matchesSelectedSection(memory, referenceDate: referenceDate) &&
            (showInbox || !isInboxMemory(memory))
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

    private func refresh() async {
        async let spaces = spaceService.refresh(force: true)
        async let memories = memoryService.refresh(force: true)
        _ = await (spaces, memories)
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
}
