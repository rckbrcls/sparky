//
//  CalendarYearView.swift
//  i-cant-miss
//
//  Created by Codex on 09/03/24.
//

import SwiftUI

struct CalendarYearView: View {
    @ObservedObject var dataManager: CalendarDataManager
    @Binding var selectedYear: Int
    let onSelectMonth: (Date) -> Void

    @StateObject private var scrollState: InfiniteScrollState<Int>

    private let calendar = Calendar.current

    init(
        dataManager: CalendarDataManager,
        selectedYear: Binding<Int>,
        onSelectMonth: @escaping (Date) -> Void
    ) {
        self.dataManager = dataManager
        self._selectedYear = selectedYear
        self.onSelectMonth = onSelectMonth

        // Initialize scroll state with current year centered
        let initialYear = selectedYear.wrappedValue
        self._scrollState = StateObject(wrappedValue: InfiniteScrollState.years(
            initialYear: initialYear,
            range: 2,
            onLoadYear: { year in
                dataManager.ensureYearLoaded(year)
            }
        ))
    }

    /// Check if an index is near edges and should trigger pre-loading
    private func checkPreloadNeeded(at index: Int, totalCount: Int) {
        let preloadThreshold = 1

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
                LazyVStack(spacing: 16) {
                    // Top sentinel for loading more years backward
                    InfiniteScrollSentinel {
                        scrollState.loadMoreBackward()
                    }

                    let items = scrollState.items
                    ForEach(Array(items.enumerated()), id: \.element) { index, year in
                        YearSection(
                            year: year,
                            dataManager: dataManager,
                            onSelectMonth: onSelectMonth
                        )
                        .id(year)
                        .onAppear {
                            dataManager.ensureYearLoaded(year)
                            checkPreloadNeeded(at: index, totalCount: items.count)
                        }
                    }

                    // Bottom sentinel for loading more years forward
                    InfiniteScrollSentinel {
                        scrollState.loadMoreForward()
                    }
                }
                .padding(.vertical, 16)
            }
            .scrollIndicators(.hidden)
            .onAppear {
                // Ensure initial years are loaded
                scrollState.items.forEach { year in
                    dataManager.ensureYearLoaded(year)
                }

                // Scroll to selected year on appear
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.none) {
                        proxy.scrollTo(selectedYear, anchor: .top)
                    }
                }
            }
        }
    }
}

// MARK: - Year Section

private struct YearSection: View {
    let year: Int
    @ObservedObject var dataManager: CalendarDataManager
    let onSelectMonth: (Date) -> Void

    private let calendar = Calendar.current
    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)

    private var months: [Date] {
        (1...12).compactMap { month in
            calendar.date(from: DateComponents(year: year, month: month, day: 1))
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            // Year header
            Text("\(year)")
                .font(.title)
                .fontWeight(.bold)
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)

            // Month grid
            LazyVGrid(columns: gridColumns, spacing: 8) {
                ForEach(months, id: \.self) { month in
                    MonthCell(
                        month: month,
                        dataManager: dataManager,
                        onSelect: { onSelectMonth(month) }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Month Cell

private struct MonthCell: View {
    let month: Date
    @ObservedObject var dataManager: CalendarDataManager
    let onSelect: () -> Void

    private let calendar = Calendar.current

    private var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: month)
    }

    private var daysInMonth: Int {
        calendar.range(of: .day, in: .month, for: month)?.count ?? 0
    }

    private var firstWeekday: Int {
        guard let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) else {
            return 0
        }
        return (calendar.component(.weekday, from: firstDay) - calendar.firstWeekday + 7) % 7
    }

    private var monthKey: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: month)) ?? month
    }

    private var daySlots: [Int?] {
        var days: [Int?] = []

        // Empty slots before first day
        for _ in 0..<firstWeekday {
            days.append(nil)
        }

        // Days of month
        for day in 1...daysInMonth {
            days.append(day)
        }

        return days
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                Text(monthName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 7), spacing: 1) {
                    ForEach(Array(daySlots.enumerated()), id: \.offset) { _, day in
                        if let day = day {
                            MiniDayIndicator(
                                day: day,
                                memories: dataManager.memoriesForDay(monthKey: monthKey, day: day)
                            )
                        } else {
                            Color.clear
                                .frame(height: 16)
                        }
                    }
                }
                .frame(maxHeight: 90)
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.secondary.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Mini Day Indicator

private struct MiniDayIndicator: View {
    let day: Int
    let memories: [MemoryModel]

    private var hasMemories: Bool {
        !memories.isEmpty
    }

    private var indicatorColor: Color {
        hasMemories ? CalendarColorHelper.indicatorColor(for: memories) : .clear
    }

    var body: some View {
        ZStack {
            if hasMemories {
                Circle()
                    .fill(indicatorColor)
                    .frame(width: 16, height: 16)
            }

            Text("\(day)")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(hasMemories ? .white : .secondary)
        }
        .frame(height: 16)
    }
}

#Preview {
    let environment = AppEnvironment(persistence: PersistenceController.preview)
    environment.bootstrap()
    let currentYear = Calendar.current.component(.year, from: Date())
    let dataManager = CalendarDataManager(memoryService: environment.memoryService)

    return CalendarYearView(
        dataManager: dataManager,
        selectedYear: .constant(currentYear),
        onSelectMonth: { _ in }
    )
    .environmentObject(environment)
}
