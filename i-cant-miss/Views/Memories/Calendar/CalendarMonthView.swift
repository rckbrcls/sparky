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

    @StateObject private var scrollState: InfiniteScrollState<Date>

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

        // Initialize scroll state with current month centered
        let centerMonth = Calendar.current.date(
            from: Calendar.current.dateComponents([.year, .month], from: currentMonth.wrappedValue)
        ) ?? currentMonth.wrappedValue

        self._scrollState = StateObject(wrappedValue: InfiniteScrollState.months(
            centerMonth: centerMonth,
            range: 6,
            onLoadMonth: { month in
                dataManager.ensureMonthLoaded(month)
            }
        ))
    }

    /// Check if an index is near edges and should trigger pre-loading
    private func checkPreloadNeeded(at index: Int, totalCount: Int) {
        let preloadThreshold = 2

        if index < preloadThreshold {
            scrollState.loadMoreBackward()
        }

        if index >= totalCount - preloadThreshold {
            scrollState.loadMoreForward()
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 32) {
                    // Top sentinel for loading more months backward
                    InfiniteScrollSentinel {
                        scrollState.loadMoreBackward()
                    }

                    let items = scrollState.items
                    ForEach(Array(items.enumerated()), id: \.element) { index, month in
                        MonthSection(
                            month: month,
                            dataManager: dataManager,
                            selectedDate: selectedDate,
                            onSelectDay: onSelectDay
                        )
                        .id(month)
                        .onAppear {
                            dataManager.ensureMonthLoaded(month)
                            checkPreloadNeeded(at: index, totalCount: items.count)
                        }
                    }

                    // Bottom sentinel for loading more months forward
                    InfiniteScrollSentinel {
                        scrollState.loadMoreForward()
                    }
                }
                .padding(.vertical, 16)
            }
            .scrollIndicators(.hidden)
            .onAppear {
                // Ensure initial months are loaded
                scrollState.items.forEach { month in
                    dataManager.ensureMonthLoaded(month)
                }

                let normalizedCurrent = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth)) ?? currentMonth
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.none) {
                        proxy.scrollTo(normalizedCurrent, anchor: .top)
                    }
                }
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
