//
//  CalendarDayView.swift
//  i-cant-miss
//
//  Created by Codex on 09/03/24.
//

import SwiftUI

struct CalendarDayView: View {
    @ObservedObject var dataManager: CalendarDataManager
    @Binding var currentDate: Date
    let isMultiSelecting: Bool
    let selectedMemoryIDs: Set<MemoryModel.ID>
    let isPerformingBulkAction: Bool
    let onSelectMemory: (MemoryModel) -> Void
    let onToggleSelection: (MemoryModel) -> Void
    let onEditMemory: ((MemoryModel) -> Void)?

    @State private var displayedWeekStart: Date
    @State private var transitionDirection: PullDirection?

    private let calendar = Calendar.current

    init(
        dataManager: CalendarDataManager,
        currentDate: Binding<Date>,
        isMultiSelecting: Bool,
        selectedMemoryIDs: Set<MemoryModel.ID>,
        isPerformingBulkAction: Bool,
        onSelectMemory: @escaping (MemoryModel) -> Void,
        onToggleSelection: @escaping (MemoryModel) -> Void,
        onEditMemory: ((MemoryModel) -> Void)?
    ) {
        self.dataManager = dataManager
        self._currentDate = currentDate
        self.isMultiSelecting = isMultiSelecting
        self.selectedMemoryIDs = selectedMemoryIDs
        self.isPerformingBulkAction = isPerformingBulkAction
        self.onSelectMemory = onSelectMemory
        self.onToggleSelection = onToggleSelection
        self.onEditMemory = onEditMemory

        // Calculate the start of the week containing the current date
        let weekStart = Calendar.current.date(
            from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: currentDate.wrappedValue)
        ) ?? currentDate.wrappedValue
        self._displayedWeekStart = State(initialValue: weekStart)
    }

    /// Get the 7 days of the displayed week
    private var weekDays: [Date] {
        (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: displayedWeekStart)
        }
    }

    /// Get month name for header
    private var weekMonthHeader: String {
        let formatter = DateFormatter()

        // Check if week spans two months
        guard let firstDay = weekDays.first, let lastDay = weekDays.last else {
            return ""
        }

        let firstMonth = calendar.component(.month, from: firstDay)
        let lastMonth = calendar.component(.month, from: lastDay)
        let firstYear = calendar.component(.year, from: firstDay)
        let lastYear = calendar.component(.year, from: lastDay)

        if firstYear != lastYear {
            formatter.dateFormat = "MMM yyyy"
            return "\(formatter.string(from: firstDay)) - \(formatter.string(from: lastDay))"
        } else if firstMonth != lastMonth {
            formatter.dateFormat = "MMM"
            let firstMonthName = formatter.string(from: firstDay)
            let lastMonthName = formatter.string(from: lastDay)
            formatter.dateFormat = "yyyy"
            let year = formatter.string(from: firstDay)
            return "\(firstMonthName) - \(lastMonthName) \(year)"
        } else {
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: firstDay)
        }
    }

    var body: some View {
        PullToNavigateScrollView(
            onPullUp: {
                navigateToPreviousWeek()
            },
            onPullDown: {
                navigateToNextWeek()
                    }
        ) {
            VStack(alignment: .leading, spacing: 16) {
                // Month header
                Text(weekMonthHeader)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                // Week content
                WeekSection(
                    weekDays: weekDays,
                                dataManager: dataManager,
                                isMultiSelecting: isMultiSelecting,
                                selectedMemoryIDs: selectedMemoryIDs,
                                isPerformingBulkAction: isPerformingBulkAction,
                                onSelectMemory: onSelectMemory,
                                onToggleSelection: onToggleSelection,
                                onEditMemory: onEditMemory
                            )
            }
            .padding(.vertical, 16)
            .id(displayedWeekStart)
        }
                            .onAppear {
            ensureWeekDataLoaded()
        }
        .onChange(of: displayedWeekStart) { _, _ in
            ensureWeekDataLoaded()
            // Update currentDate to first day of week
            if let firstDay = weekDays.first {
                currentDate = firstDay
            }
        }
    }

    private func navigateToPreviousWeek() {
        transitionDirection = .up
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if let previousWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: displayedWeekStart) {
                displayedWeekStart = previousWeek
                            }
                        }
                    }

    private func navigateToNextWeek() {
        transitionDirection = .down
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: displayedWeekStart) {
                displayedWeekStart = nextWeek
                    }
                }
    }

    private func ensureWeekDataLoaded() {
        // Load months for all days in the week
        var monthsToLoad: Set<Date> = []
        for day in weekDays {
            let monthKey = calendar.date(from: calendar.dateComponents([.year, .month], from: day)) ?? day
            monthsToLoad.insert(monthKey)
                }
        for month in monthsToLoad {
            dataManager.ensureMonthLoaded(month)
        }
    }
}

// MARK: - Week Section

private struct WeekSection: View {
    let weekDays: [Date]
    @ObservedObject var dataManager: CalendarDataManager
    let isMultiSelecting: Bool
    let selectedMemoryIDs: Set<MemoryModel.ID>
    let isPerformingBulkAction: Bool
    let onSelectMemory: (MemoryModel) -> Void
    let onToggleSelection: (MemoryModel) -> Void
    let onEditMemory: ((MemoryModel) -> Void)?

    private let calendar = Calendar.current

    /// Days with memories in this week
    private var daysWithMemories: [(date: Date, memories: [MemoryModel])] {
        weekDays.compactMap { day in
            let memories = dataManager.memoriesForDate(day)
            return memories.isEmpty ? nil : (date: day, memories: memories)
    }
}

    /// Week date range text for empty weeks
    private var weekRangeText: String {
        guard let firstDay = weekDays.first, let lastDay = weekDays.last else {
            return ""
        }

        let formatter = DateFormatter()
        let firstMonth = calendar.component(.month, from: firstDay)
        let lastMonth = calendar.component(.month, from: lastDay)

        if firstMonth != lastMonth {
            formatter.dateFormat = "MMM d"
            return "\(formatter.string(from: firstDay)) - \(formatter.string(from: lastDay))"
        } else {
            formatter.dateFormat = "MMMM"
            let monthName = formatter.string(from: firstDay)
            let startDay = calendar.component(.day, from: firstDay)
            let endDay = calendar.component(.day, from: lastDay)
            return "\(monthName) \(startDay) - \(endDay)"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            if daysWithMemories.isEmpty {
                // Empty week summary
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                        Text(weekRangeText)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("No events")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
                }
            } else {
                // Show days with memories
                ForEach(daysWithMemories, id: \.date) { dayData in
                    DaySection(
                        date: dayData.date,
                        memories: dayData.memories,
                        isMultiSelecting: isMultiSelecting,
                        selectedMemoryIDs: selectedMemoryIDs,
                        isPerformingBulkAction: isPerformingBulkAction,
                        onSelectMemory: onSelectMemory,
                        onToggleSelection: onToggleSelection,
                        onEditMemory: onEditMemory
                    )
                }
            }
        }
    }
}

// MARK: - Day Section

private struct DaySection: View {
    let date: Date
    let memories: [MemoryModel]
    let isMultiSelecting: Bool
    let selectedMemoryIDs: Set<MemoryModel.ID>
    let isPerformingBulkAction: Bool
    let onSelectMemory: (MemoryModel) -> Void
    let onToggleSelection: (MemoryModel) -> Void
    let onEditMemory: ((MemoryModel) -> Void)?

    private let calendar = Calendar.current

    private var dayTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d"
        return formatter.string(from: date)
    }

    private var allDayMemories: [MemoryModel] {
        memories.filter { memory in
            guard let fireDate = memory.nextFireDate(referenceDate: date) else {
                return false
            }
            let components = calendar.dateComponents([.hour, .minute], from: fireDate)
            return (components.hour ?? 0) == 0 && (components.minute ?? 0) == 0
        }
    }

    private var timedMemories: [MemoryModel] {
        memories.filter { memory in
            guard let fireDate = memory.nextFireDate(referenceDate: date) else {
                return false
            }
            let components = calendar.dateComponents([.hour, .minute], from: fireDate)
            return (components.hour ?? 0) != 0 || (components.minute ?? 0) != 0
        }
    }

    private var isToday: Bool {
        calendar.isDateInToday(date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Day header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dayTitle)
                        .font(.title3)
                        .fontWeight(.bold)

                    if isToday {
                        Text("Today")
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 20)

            // Memory content
            VStack(alignment: .leading, spacing: 16) {
                // All day memories section
                if !allDayMemories.isEmpty {
                    memoriesSection(title: "All Day", memories: allDayMemories)
                }

                // Timed memories section
                if !timedMemories.isEmpty {
                    memoriesSection(title: "Timed Events", memories: timedMemories)
                }
            }
        }
    }

    @ViewBuilder
    private func memoriesSection(title: String, memories: [MemoryModel]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)

            ForEach(memories) { memory in
                MemoryListItemButton(
                    memory: memory,
                    isMultiSelecting: isMultiSelecting,
                    isSelected: selectedMemoryIDs.contains(memory.id),
                    isDisabled: isPerformingBulkAction,
                    onSelect: onSelectMemory,
                    onToggleSelection: onToggleSelection,
                    onEdit: onEditMemory
                )
                .padding(.horizontal, 20)
            }
        }
    }
}

#Preview {
    let environment = AppEnvironment(persistence: PersistenceController.preview)
    environment.bootstrap()
    let date = Date()
    let dataManager = CalendarDataManager(memoryService: environment.memoryService)

    return CalendarDayView(
        dataManager: dataManager,
        currentDate: .constant(date),
        isMultiSelecting: false,
        selectedMemoryIDs: [],
        isPerformingBulkAction: false,
        onSelectMemory: { _ in },
        onToggleSelection: { _ in },
        onEditMemory: nil
    )
    .environmentObject(environment)
}
