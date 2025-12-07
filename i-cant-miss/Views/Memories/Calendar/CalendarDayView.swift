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

    @State private var displayedMonthStart: Date
    @State private var monthAnchor: Date

    private var pages: [Date] {
        generateMonthRange()
    }

    private let calendar = Calendar.current
    /// Matches the custom tab bar height (55pt) plus extra spacing for safe overlap
    private let bottomOverlayPadding: CGFloat = 70

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

        // Calculate the start of the month containing the current date
        let monthStart = Calendar.current.date(
            from: Calendar.current.dateComponents([.year, .month], from: currentDate.wrappedValue)
        ) ?? currentDate.wrappedValue
        self._displayedMonthStart = State(initialValue: monthStart)
        self._monthAnchor = State(initialValue: monthStart)
    }

    var body: some View {
        GeometryReader { proxy in
            TabView(selection: $displayedMonthStart) {
                ForEach(pages, id: \.self) { month in
                    let monthWeeks = generateWeeksForMonth(month)
                    let monthHeaderTitle = formatMonthTitle(month)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            Text(monthHeaderTitle)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .padding(.horizontal, 20)
                                .padding(.top, 8)

                            MonthWeeksSection(
                                weeks: monthWeeks,
                                monthReferenceDate: month,
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
                        .safeAreaPadding(.top)
                        .id(month)
                    }
                    .scrollIndicators(.hidden)
                    .scrollBounceBehavior(.basedOnSize)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .tag(month)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .onAppear {
            ensureMonthDataLoaded()
        }
        .onChange(of: displayedMonthStart) { _, _ in
            ensureMonthDataLoaded()
            currentDate = displayedMonthStart
        }
    }

    private func generateMonthRange() -> [Date] {
        let anchor = calendar.date(from: calendar.dateComponents([.year, .month], from: monthAnchor)) ?? monthAnchor

        return (-12...12).compactMap { offset in
            calendar.date(byAdding: .month, value: offset, to: anchor)
                .flatMap { date in
                    calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
                }
        }
    }

    private func generateWeeksForMonth(_ month: Date) -> [[Date]] {
        guard
            let monthRange = calendar.range(of: .day, in: .month, for: month),
            let monthEnd = calendar.date(byAdding: .day, value: monthRange.count - 1, to: month),
            let firstWeekStart = calendar.dateInterval(of: .weekOfYear, for: month)?.start,
            let lastWeekStart = calendar.dateInterval(of: .weekOfYear, for: monthEnd)?.start
        else {
            return []
        }

        var weeks: [[Date]] = []
        var currentWeekStart = firstWeekStart

        while currentWeekStart <= lastWeekStart {
            let days = (0..<7).compactMap { offset in
                calendar.date(byAdding: .day, value: offset, to: currentWeekStart)
            }
            weeks.append(days)

            guard let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: currentWeekStart) else {
                break
            }
            currentWeekStart = nextWeek
        }

        return weeks
    }

    private func formatMonthTitle(_ month: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: month)
    }

    private func ensureMonthDataLoaded() {
        let monthKey = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonthStart)) ?? displayedMonthStart
        dataManager.ensureMonthLoaded(monthKey)
    }
}

// MARK: - Month Weeks Section

private struct MonthWeeksSection: View {
    let weeks: [[Date]]
    let monthReferenceDate: Date
    @ObservedObject var dataManager: CalendarDataManager
    let isMultiSelecting: Bool
    let selectedMemoryIDs: Set<MemoryModel.ID>
    let isPerformingBulkAction: Bool
    let onSelectMemory: (MemoryModel) -> Void
    let onToggleSelection: (MemoryModel) -> Void
    let onEditMemory: ((MemoryModel) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, weekDays in
                WeekSection(
                    weekDays: weekDays,
                    monthReferenceDate: monthReferenceDate,
                    dataManager: dataManager,
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

// MARK: - Week Section

private struct WeekSection: View {
    let weekDays: [Date]
    let monthReferenceDate: Date
    @ObservedObject var dataManager: CalendarDataManager
    let isMultiSelecting: Bool
    let selectedMemoryIDs: Set<MemoryModel.ID>
    let isPerformingBulkAction: Bool
    let onSelectMemory: (MemoryModel) -> Void
    let onToggleSelection: (MemoryModel) -> Void
    let onEditMemory: ((MemoryModel) -> Void)?

    private let calendar = Calendar.current

    private var relevantDays: [Date] {
        let filteredDays = weekDays.filter {
            calendar.isDate($0, equalTo: monthReferenceDate, toGranularity: .month)
        }
        return filteredDays.isEmpty ? weekDays : filteredDays
    }

    /// Days with memories in this week (bounded to the displayed month)
    private var daysWithMemories: [(date: Date, memories: [MemoryModel])] {
        relevantDays.compactMap { day in
            let memories = dataManager.memoriesForDate(day)
            return memories.isEmpty ? nil : (date: day, memories: memories)
        }
    }

    /// Week date range text for empty weeks
    private var weekRangeText: String {
        guard let firstDay = relevantDays.first, let lastDay = relevantDays.last else {
            return ""
        }

        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMMM"
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "d"
        let monthName = monthFormatter.string(from: firstDay)
        let startDay = dayFormatter.string(from: firstDay)
        let endDay = dayFormatter.string(from: lastDay)

        return startDay == endDay ? "\(monthName) \(startDay)" : "\(monthName) \(startDay) - \(endDay)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            if daysWithMemories.isEmpty {
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
