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

    @StateObject private var scrollState: InfiniteScrollState<Date>

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

        // Initialize scroll state with current day centered
        let centerDay = Calendar.current.startOfDay(for: currentDate.wrappedValue)

        self._scrollState = StateObject(wrappedValue: InfiniteScrollState.days(
            centerDay: centerDay,
            range: 14,  // Increased from 7 for better initial loading
            onLoadDay: { day in
                // Ensure the month containing this day is loaded
                let month = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: day)) ?? day
                dataManager.ensureMonthLoaded(month)
            }
        ))
    }

    /// Groups days into display sections (empty week summaries or individual days with content)
    private var displaySections: [DayDisplaySection] {
        let days = scrollState.items
        guard !days.isEmpty else { return [] }

        var sections: [DayDisplaySection] = []
        var currentWeekDays: [Date] = []
        var currentWeekStart: Date?
        var currentMonth: Int?

        for day in days {
            let dayMonth = calendar.component(.month, from: day)
            let dayWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: day))

            // Check if we're starting a new month
            if currentMonth != dayMonth {
                // Process the previous week before starting new month
                if !currentWeekDays.isEmpty {
                    sections.append(contentsOf: processWeek(currentWeekDays))
                    currentWeekDays = []
                    currentWeekStart = nil
                }
                // Add month header
                let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: day)) ?? day
                sections.append(.monthHeader(monthStart))
                currentMonth = dayMonth
            }

            // Check if we're starting a new week
            if currentWeekStart != dayWeekStart {
                // Process the previous week
                if !currentWeekDays.isEmpty {
                    sections.append(contentsOf: processWeek(currentWeekDays))
                }
                currentWeekDays = [day]
                currentWeekStart = dayWeekStart
            } else {
                currentWeekDays.append(day)
            }
        }

        // Process the last week
        if !currentWeekDays.isEmpty {
            sections.append(contentsOf: processWeek(currentWeekDays))
        }

        return sections
    }

    /// Process a week's worth of days and return appropriate sections
    private func processWeek(_ days: [Date]) -> [DayDisplaySection] {
        // Find days with memories in this week
        let daysWithMemories = days.filter { !dataManager.memoriesForDate($0).isEmpty }

        if daysWithMemories.isEmpty {
            // No memories in this week - create a summary
            guard let firstDay = days.first, let lastDay = days.last else { return [] }
            return [.weekSummary(startDate: firstDay, endDate: lastDay)]
        } else {
            // Has memories - show only days with memories
            return daysWithMemories.map { .day($0) }
        }
    }

    /// Check if we need to pre-load more days based on which date is appearing
    private func checkPreloadNeeded(for date: Date) {
        let items = scrollState.items
        guard items.count > 1 else { return }

        // Check how far this date is from the edges of loaded items
        let dayKey = calendar.startOfDay(for: date)

        if let firstDay = items.first,
           let daysSinceFirst = calendar.dateComponents([.day], from: firstDay, to: dayKey).day,
           daysSinceFirst < 14 {
            // Within 2 weeks of the start - load more backward
            scrollState.loadMoreBackward()
        }

        if let lastDay = items.last,
           let daysUntilLast = calendar.dateComponents([.day], from: dayKey, to: lastDay).day,
           daysUntilLast < 14 {
            // Within 2 weeks of the end - load more forward
            scrollState.loadMoreForward()
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 24) {
                    // Top sentinel for loading more days backward
                    InfiniteScrollSentinel {
                        scrollState.loadMoreBackward()
                    }

                    ForEach(displaySections) { section in
                        switch section {
                        case .monthHeader(let date):
                            MonthHeaderSection(date: date)
                                .id(section.id)

                        case .weekSummary(let startDate, let endDate):
                            WeekSummarySection(startDate: startDate, endDate: endDate)
                                .id(section.id)
                                .onAppear {
                                    // Use start date of the week summary to check preload
                                    checkPreloadNeeded(for: startDate)
                                }

                        case .day(let date):
                            DaySection(
                                date: date,
                                dataManager: dataManager,
                                isMultiSelecting: isMultiSelecting,
                                selectedMemoryIDs: selectedMemoryIDs,
                                isPerformingBulkAction: isPerformingBulkAction,
                                onSelectMemory: onSelectMemory,
                                onToggleSelection: onToggleSelection,
                                onEditMemory: onEditMemory
                            )
                            .id(section.id)
                            .onAppear {
                                // Ensure the month containing this day is loaded
                                let month = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
                                dataManager.ensureMonthLoaded(month)

                                // Pre-load more days if near edges
                                checkPreloadNeeded(for: date)
                            }
                        }
                    }

                    // Bottom sentinel for loading more days forward
                    InfiniteScrollSentinel {
                        scrollState.loadMoreForward()
                    }
                }
                .padding(.vertical, 16)
            }
            .scrollIndicators(.hidden)
            .onAppear {
                // Ensure initial days' months are loaded
                scrollState.items.forEach { day in
                    let month = calendar.date(from: calendar.dateComponents([.year, .month], from: day)) ?? day
                    dataManager.ensureMonthLoaded(month)
                }

                let normalizedCurrent = calendar.startOfDay(for: currentDate)
                let targetID = "day-\(normalizedCurrent.timeIntervalSince1970)"
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.none) {
                        proxy.scrollTo(targetID, anchor: .top)
                    }
                }
            }
        }
    }
}

// MARK: - Display Section Type

private enum DayDisplaySection: Identifiable {
    case monthHeader(Date)
    case weekSummary(startDate: Date, endDate: Date)
    case day(Date)

    var id: String {
        switch self {
        case .monthHeader(let date):
            return "month-\(date.timeIntervalSince1970)"
        case .weekSummary(let startDate, let endDate):
            return "week-\(startDate.timeIntervalSince1970)-\(endDate.timeIntervalSince1970)"
        case .day(let date):
            return "day-\(date.timeIntervalSince1970)"
        }
    }
}

// MARK: - Month Header Section

private struct MonthHeaderSection: View {
    let date: Date

    private var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: date)
    }

    var body: some View {
        Text(monthName)
            .font(.largeTitle)
            .fontWeight(.bold)
            .padding(.horizontal, 20)
            .padding(.top, 8)
    }
}

// MARK: - Week Summary Section

private struct WeekSummarySection: View {
    let startDate: Date
    let endDate: Date

    private var summaryText: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current

        let startMonth = calendar.component(.month, from: startDate)
        let endMonth = calendar.component(.month, from: endDate)
        let startYear = calendar.component(.year, from: startDate)
        let endYear = calendar.component(.year, from: endDate)

        if startYear != endYear {
            // Different years: "Dec 28, 2024 - Jan 3, 2025"
            formatter.dateFormat = "MMM d, yyyy"
            return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
        } else if startMonth != endMonth {
            // Same year, different months: "Dec 28 - Jan 3"
            formatter.dateFormat = "MMM d"
            return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
        } else {
            // Same month: "December 7 - 13"
            formatter.dateFormat = "MMMM"
            let monthName = formatter.string(from: startDate)
            let startDay = calendar.component(.day, from: startDate)
            let endDay = calendar.component(.day, from: endDate)
            return "\(monthName) \(startDay) - \(endDay)"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(summaryText)
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
    }
}

// MARK: - Day Section

private struct DaySection: View {
    let date: Date
    @ObservedObject var dataManager: CalendarDataManager
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

    private var memories: [MemoryModel] {
        dataManager.memoriesForDate(date)
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
                            .foregroundStyle(Color.accent)
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
