//
//  CalendarMonthView.swift
//  i-cant-miss
//
//  Created by Codex on 09/03/24.
//

import SwiftUI

struct CalendarMonthView: View {
    @ObservedObject var dataManager: CalendarDataManager
    @Binding var currentMonth: Date
    let selectedDate: Date?
    let onSelectDay: (Date) -> Void

    @State private var displayedMonth: Date
    @State private var transitionDirection: PullDirection?

    private let calendar = Calendar.current

    /// Tab bar height (55pt) + extra padding for safety
    private let bottomInset: CGFloat = 70

    init(
        dataManager: CalendarDataManager,
        currentMonth: Binding<Date>,
        selectedDate: Date?,
        onSelectDay: @escaping (Date) -> Void
    ) {
        self.dataManager = dataManager
        self._currentMonth = currentMonth
        self.selectedDate = selectedDate
        self.onSelectDay = onSelectDay

        // Normalize to start of month
        let normalized = Calendar.current.date(
            from: Calendar.current.dateComponents([.year, .month], from: currentMonth.wrappedValue)
        ) ?? currentMonth.wrappedValue
        self._displayedMonth = State(initialValue: normalized)
    }

    var body: some View {
        PullToNavigateScrollView(
            bottomOverlayPadding: bottomInset,
            onPullUp: {
                navigateToPreviousMonth()
            },
            onPullDown: {
                navigateToNextMonth()
            }
        ) {
            GeometryReader { geometry in
                let safeHeight = max(400, geometry.size.height - bottomInset)

                MonthSection(
                    month: displayedMonth,
                    dataManager: dataManager,
                    selectedDate: selectedDate,
                    onSelectDay: onSelectDay,
                    availableHeight: safeHeight
                )
                .frame(minHeight: safeHeight)
                .id(displayedMonth)
            }
        }
        .onAppear {
            dataManager.ensureMonthLoaded(displayedMonth)
        }
        .onChange(of: displayedMonth) { _, newMonth in
            dataManager.ensureMonthLoaded(newMonth)
            currentMonth = newMonth
        }
    }

    private func navigateToPreviousMonth() {
        transitionDirection = .up
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if let previousMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) {
                displayedMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: previousMonth)) ?? previousMonth
            }
        }
    }

    private func navigateToNextMonth() {
        transitionDirection = .down
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if let nextMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) {
                displayedMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: nextMonth)) ?? nextMonth
            }
        }
    }
}

// MARK: - Month Section

private struct MonthSection: View {
    let month: Date
    @ObservedObject var dataManager: CalendarDataManager
    let selectedDate: Date?
    let onSelectDay: (Date) -> Void
    let availableHeight: CGFloat

    private let calendar = Calendar.current
    private let weekdays = ["S", "M", "T", "W", "T", "F", "S"]

    private var monthKey: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: month)) ?? month
    }

    private var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: month)
    }

    private var firstDayOfMonth: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: month)) ?? month
    }

    private var calendarDays: [Date?] {
        var days: [Date?] = []

        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        let offset = (firstWeekday - calendar.firstWeekday + 7) % 7

        // Empty slots before first day
        for _ in 0..<offset {
            days.append(nil)
        }

        // Days of month
        guard let range = calendar.range(of: .day, in: .month, for: month) else {
            return days
        }

        for day in 1...range.count {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) {
                days.append(date)
            }
        }

        return days
    }

    /// Number of rows needed for this month
    private var numberOfRows: Int {
        let totalSlots = calendarDays.count
        return (totalSlots + 6) / 7 // Ceiling division
    }

    /// Calculate day cell height based on available space
    /// Layout: Header (~44pt) + Weekday headers (~24pt) + padding (~16pt) + 6 rows of days
    private var dayCellHeight: CGFloat {
        let headerHeight: CGFloat = 44
        let weekdayHeaderHeight: CGFloat = 28
        let topPadding: CGFloat = 12
        let availableForDays = availableHeight - headerHeight - weekdayHeaderHeight - topPadding
        // Always use 6 rows for consistent sizing across months
        return max(50, availableForDays / 6)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Month header
            Text(monthName)
                .font(.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 12)

            // Weekday headers
            HStack(spacing: 0) {
                ForEach(Array(weekdays.enumerated()), id: \.offset) { _, weekday in
                    Text(weekday)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
                ForEach(Array(calendarDays.enumerated()), id: \.offset) { _, date in
                    if let date = date {
                        DayCell(
                            date: date,
                            memories: dataManager.memoriesForDate(date),
                            isSelected: isDateSelected(date),
                            cellHeight: dayCellHeight,
                            onSelect: { onSelectDay(date) }
                        )
                    } else {
                        Color.clear
                            .frame(height: dayCellHeight)
                    }
                }
            }
            .padding(.horizontal, 16)

            Spacer(minLength: 0)
        }
        .safeAreaPadding(.top)
    }

    private func isDateSelected(_ date: Date) -> Bool {
        guard let selectedDate = selectedDate else { return false }
        return calendar.isDate(date, equalTo: selectedDate, toGranularity: .day)
    }
}

// MARK: - Day Cell

private struct DayCell: View {
    let date: Date
    let memories: [MemoryModel]
    let isSelected: Bool
    let cellHeight: CGFloat
    let onSelect: () -> Void

    private let calendar = Calendar.current

    private var dayNumber: Int {
        calendar.component(.day, from: date)
    }

    private var isToday: Bool {
        calendar.isDateInToday(date)
    }

    private var hasMemories: Bool {
        !memories.isEmpty
    }

    /// Calculate circle size based on cell height
    private var circleSize: CGFloat {
        min(36, max(28, cellHeight * 0.55))
    }

    /// Calculate font size based on cell height
    private var fontSize: CGFloat {
        min(18, max(14, cellHeight * 0.28))
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 2) {
                ZStack {
                    if isToday {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: circleSize, height: circleSize)
                    } else if isSelected {
                        Circle()
                            .fill(Color.accentColor.opacity(0.2))
                            .frame(width: circleSize, height: circleSize)
                    }

                    Text("\(dayNumber)")
                        .font(.system(size: fontSize, weight: isToday ? .bold : .medium))
                        .foregroundStyle(isToday ? .white : .primary)
                }

                if hasMemories {
                    HStack(spacing: 2) {
                        ForEach(Array(memories.prefix(3).enumerated()), id: \.offset) { _, memory in
                            Circle()
                                .fill(CalendarColorHelper.color(for: memory))
                                .frame(width: 5, height: 5)
                        }
                        if memories.count > 3 {
                            Text("+\(memories.count - 3)")
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(height: 8)
                } else {
                    Spacer()
                        .frame(height: 8)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: cellHeight)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let environment = AppEnvironment(persistence: PersistenceController.preview)
    environment.bootstrap()
    let month = Calendar.current.date(from: DateComponents(year: 2025, month: 11)) ?? Date()
    let dataManager = CalendarDataManager(memoryService: environment.memoryService)

    return CalendarMonthView(
        dataManager: dataManager,
        currentMonth: .constant(month),
        selectedDate: nil,
        onSelectDay: { _ in }
    )
    .environmentObject(environment)
}
