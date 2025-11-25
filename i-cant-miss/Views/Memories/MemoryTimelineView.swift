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
    let onEditMemory: ((MemoryModel) -> Void)?
    let onMultiSelectionChange: (Bool) -> Void
    @Binding var navigationPath: NavigationPath

    @EnvironmentObject private var environment: AppEnvironment
    @State private var searchText = ""
    @State private var isMultiSelecting = false
    @State private var selectedDate = Date()
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

    private var filteredPinnedMemories: [MemoryModel] {
        let referenceDate = Date()

        return memoryService.memories
            .filter { memory in
                guard memory.status == .active, memory.isPinned else { return false }
                return true
            }
            .sorted { lhs, rhs in
                sortPinned(lhs, rhs, referenceDate: referenceDate)
            }
    }

    private var scheduledMemories: [MemoryModel] {
        memoryService.scheduledMemories(referenceDate: selectedDate)
            .filter { memory in
                guard memory.nextFireDate(referenceDate: selectedDate) != nil else { return false }
                return true
            }
    }

    private var memoriesByDate: [Date: [MemoryModel]] {
        Dictionary(grouping: scheduledMemories) { memory in
            Calendar.current.startOfDay(for: memory.nextFireDate(referenceDate: selectedDate) ?? Date())
        }
    }

    private var sortedDates: [Date] {
        memoriesByDate.keys.sorted()
    }

    private var weeks: [(start: Date, end: Date, dates: [Date])] {
        let calendar = Calendar.current
        var weeks: [(start: Date, end: Date, dates: [Date])] = []

        guard !sortedDates.isEmpty else { return weeks }

        var currentWeekStart: Date?
        var currentWeekDates: [Date] = []

        for date in sortedDates {
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date

            if let existingWeekStart = currentWeekStart {
                if calendar.isDate(weekStart, equalTo: existingWeekStart, toGranularity: .day) {
                    currentWeekDates.append(date)
                } else {
                    // Save previous week
                    let weekEnd = calendar.date(byAdding: .day, value: 6, to: existingWeekStart) ?? existingWeekStart
                    weeks.append((start: existingWeekStart, end: weekEnd, dates: currentWeekDates))
                    // Start new week
                    currentWeekStart = weekStart
                    currentWeekDates = [date]
                }
            } else {
                currentWeekStart = weekStart
                currentWeekDates = [date]
            }
        }

        // Save last week
        if let weekStart = currentWeekStart, !currentWeekDates.isEmpty {
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
            weeks.append((start: weekStart, end: weekEnd, dates: currentWeekDates))
        }

        return weeks
    }

    private var hasAnyContent: Bool {
        !filteredPinnedMemories.isEmpty ||
        !scheduledMemories.isEmpty
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
                            isStatusEnabled: canMoveSelection,
                            isSpaceEnabled: canMoveSelection && !bulkActionSpaces.isEmpty,
                            onSelectSpace: { space in performMove(to: space) },
                            onSelectStatus: { status in performStatusUpdate(to: status) },
                            onSelectPriority: { priority in performPriorityUpdate(to: priority) },
                            onDelete: { showingDeleteConfirmation = true },
                            onDone: { toggleMultiSelection() }
                        )
                    } else {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                toggleMultiSelection()
                            } label: {
                                Label("Select", systemImage: "checkmark.circle")
                            }
                            .disabled(isPerformingBulkAction)
                        }
                    }
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
                if hasAnyContent {
                    CalendarMonthHeader(selectedDate: $selectedDate, searchText: $searchText)
                        .listRowInsets(.init())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)

                    pinnedSection

                    calendarContent
                } else {
                    MemoryEmptyStateCard(
                        systemImage: "tray",
                        title: "No memories yet",
                        message: "Create a memory or capture a reminder to get started."
                    )
                    .padding(.top, 16)
                    .listRowInsets(.init(top: 24, leading: 20, bottom: 24, trailing: 20))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
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
    private var calendarContent: some View {
        ForEach(weeks, id: \.start) { week in
            CalendarWeekDivider(startDate: week.start, endDate: week.end)
                .listRowInsets(.init())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            ForEach(week.dates, id: \.self) { date in
                CalendarDayHeader(date: date)
                    .listRowInsets(.init())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                if let memories = memoriesByDate[date] {
                    ForEach(memories) { memory in
                        MemoryListItemButton(
                            memory: memory,
                            isMultiSelecting: isMultiSelecting,
                            isSelected: isMemorySelected(memory),
                            isDisabled: isPerformingBulkAction,
                            onSelect: onSelectMemory,
                            onToggleSelection: toggleMemorySelection(_:),
                            onEdit: onEditMemory
                        )
                        .listRowInsets(.init(top: 4, leading: 20, bottom: 4, trailing: 20))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var pinnedSection: some View {
        if !filteredPinnedMemories.isEmpty {
            Section {
                ForEach(filteredPinnedMemories) { memory in
                    MemoryListItemButton(
                        memory: memory,
                        isMultiSelecting: isMultiSelecting,
                        isSelected: isMemorySelected(memory),
                        isDisabled: isPerformingBulkAction,
                        onSelect: onSelectMemory,
                        onToggleSelection: toggleMemorySelection(_:),
                        onEdit: onEditMemory
                    )
                    .listRowInsets(.init(top: 8, leading: 20, bottom: 8, trailing: 20))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            } header: {
                HStack(spacing: 12) {
                    Label("Pinned Memories", systemImage: "pin.fill")
                        .foregroundStyle(.white)
                }
                .padding(.vertical, 12)
                .listRowInsets(.init(top: 24, leading: 20, bottom: 8, trailing: 20))
            }
            .listSectionSeparator(.hidden)
        }
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

    private func memoryRow(for memory: MemoryModel) -> some View {
        MemoryListItemButton(
            memory: memory,
            isMultiSelecting: isMultiSelecting,
            isSelected: isMemorySelected(memory),
            isDisabled: isPerformingBulkAction,
            onSelect: onSelectMemory,
            onToggleSelection: toggleMemorySelection(_:),
            onEdit: onEditMemory)
        .listRowInsets(.init(top: 6, leading: 20, bottom: 6, trailing: 20))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private func sortPinned(_ lhs: MemoryModel, _ rhs: MemoryModel, referenceDate: Date = Date()) -> Bool {
        let lhsFire = lhs.nextFireDate(referenceDate: referenceDate)
        let rhsFire = rhs.nextFireDate(referenceDate: referenceDate)

        if lhsFire != rhsFire {
            switch (lhsFire, rhsFire) {
            case let (lhsDate?, rhsDate?):
                return lhsDate < rhsDate
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                break
            }
        }

        if lhs.dueDate != rhs.dueDate {
            switch (lhs.dueDate, rhs.dueDate) {
            case let (lhsDate?, rhsDate?):
                return lhsDate < rhsDate
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                break
            }
        }

        if lhs.priority != rhs.priority {
            let lhsPriority = lhs.priority?.rawValue ?? MemoryPriority.noPriority.rawValue
            let rhsPriority = rhs.priority?.rawValue ?? MemoryPriority.noPriority.rawValue
            return lhsPriority > rhsPriority
        }

        return lhs.updatedAt > rhs.updatedAt
    }

    private func toggleMemorySelection(_ memory: MemoryModel) {
        let id = memory.id
        if selectedMemoryIDs.contains(id) {
            selectedMemoryIDs.remove(id)
        } else {
            selectedMemoryIDs.insert(id)
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

    private func memorySupportsPriorityChange(_ memory: MemoryModel) -> Bool {
        true
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
            do {
                try await environment.memoryService.deleteMemory(id: id)
            } catch {
                // Silently ignore failures for now.
            }
        }
    }

}

#Preview {
    let environment = AppEnvironment(persistence: PersistenceController.preview)
    environment.bootstrap()
    return MemoryTimelineView(
        memoryService: environment.memoryService,
        onSelectMemory: { _ in },
        onEditMemory: nil,
        onMultiSelectionChange: { _ in },
        navigationPath: .constant(NavigationPath())
    )
    .environmentObject(environment)
}
