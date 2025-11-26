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

    private let calendar = Calendar.current
    private let weekdays = ["S", "M", "T", "W", "T", "F", "S"]

    private var monthKey: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth)) ?? currentMonth
    }

    private var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
    }

    private var firstDayOfMonth: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth)) ?? currentMonth
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
        guard let range = calendar.range(of: .day, in: .month, for: currentMonth) else {
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
            // Month navigation header
            monthNavigationHeader
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

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

            Spacer()
        }
    }

    private var monthNavigationHeader: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    navigateToPreviousMonth()
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .fontWeight(.semibold)
            }

            Spacer()

            Text(monthName)
                .font(.title2)
                .fontWeight(.bold)

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    navigateToNextMonth()
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .fontWeight(.semibold)
            }
        }
    }

    private func isDateSelected(_ date: Date) -> Bool {
        guard let selectedDate = selectedDate else { return false }
        return calendar.isDate(date, equalTo: selectedDate, toGranularity: .day)
    }

    private func navigateToPreviousMonth() {
        if let newMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) {
            currentMonth = newMonth
        }
    }

    private func navigateToNextMonth() {
        if let newMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) {
            currentMonth = newMonth
        }
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
