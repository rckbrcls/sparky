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
            onPullUp: {
                navigateToPreviousMonth()
            },
            onPullDown: {
                navigateToNextMonth()
            }
        ) {
            MonthSection(
                month: displayedMonth,
                dataManager: dataManager,
                selectedDate: selectedDate,
                onSelectDay: onSelectDay
            )
            .padding(.vertical, 16)
            .id(displayedMonth)
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

    var body: some View {
        VStack(spacing: 0) {
            // Month header
            Text(monthName)
                .font(.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

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
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
                ForEach(Array(calendarDays.enumerated()), id: \.offset) { _, date in
                    if let date = date {
                        DayCell(
                            date: date,
                            memories: dataManager.memoriesForDate(date),
                            isSelected: isDateSelected(date),
                            onSelect: { onSelectDay(date) }
                        )
                    } else {
                        Color.clear
                            .frame(height: 60)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
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

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 4) {
                ZStack {
                    if isToday {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 32, height: 32)
                    } else if isSelected {
                        Circle()
                            .fill(Color.accentColor.opacity(0.2))
                            .frame(width: 32, height: 32)
                    }

                    Text("\(dayNumber)")
                        .font(.system(size: 16, weight: isToday ? .bold : .medium))
                        .foregroundStyle(isToday ? .white : .primary)
                }

                if hasMemories {
                    HStack(spacing: 2) {
                        ForEach(Array(memories.prefix(3).enumerated()), id: \.offset) { _, memory in
                            Circle()
                                .fill(CalendarColorHelper.color(for: memory))
                                .frame(width: 4, height: 4)
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
            .padding(.vertical, 8)
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
