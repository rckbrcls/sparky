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

    @State private var displayedYear: Int
    @State private var yearAnchor: Int

    private var pages: [Int] {
        generateYearRange()
    }

    private let calendar = Calendar.current

    /// Tab bar height (55pt) + extra padding for safety
    private let bottomInset: CGFloat = 70

    init(
        dataManager: CalendarDataManager,
        selectedYear: Binding<Int>,
        onSelectMonth: @escaping (Date) -> Void
    ) {
        self.dataManager = dataManager
        self._selectedYear = selectedYear
        self.onSelectMonth = onSelectMonth
        self._displayedYear = State(initialValue: selectedYear.wrappedValue)
        self._yearAnchor = State(initialValue: selectedYear.wrappedValue)
    }

    var body: some View {
        GeometryReader { proxy in
            TabView(selection: $displayedYear) {
                ForEach(pages, id: \.self) { year in
                    let safeHeight = max(400, proxy.size.height - bottomInset)

                    ScrollView {
                        YearSection(
                            year: year,
                            dataManager: dataManager,
                            onSelectMonth: onSelectMonth,
                            availableHeight: safeHeight
                        )
                        .frame(minHeight: safeHeight)
                        .id(year)
                    }
                    .scrollIndicators(.hidden)
                    .scrollBounceBehavior(.basedOnSize)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .tag(year)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .onAppear {
            dataManager.ensureYearLoaded(displayedYear)
        }
        .onChange(of: displayedYear) { _, newYear in
            dataManager.ensureYearLoaded(newYear)
            selectedYear = newYear
        }
    }

    private func generateYearRange() -> [Int] {
        let anchor = yearAnchor
        // Generate ±20 anos para reduzir custo e evitar salto
        return Array((anchor - 20)...(anchor + 20))
    }
}

// MARK: - Year Section

private struct YearSection: View {
    let year: Int
    @ObservedObject var dataManager: CalendarDataManager
    let onSelectMonth: (Date) -> Void
    let availableHeight: CGFloat

    private let calendar = Calendar.current
    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 3)

    private var months: [Date] {
        (1...12).compactMap { month in
            calendar.date(from: DateComponents(year: year, month: month, day: 1))
        }
    }

    /// Calculate the height for each month cell based on available space
    /// Layout: Year header (~36pt) + 4 rows of months + spacing + padding
    private var monthCellHeight: CGFloat {
        let headerHeight: CGFloat = 36
        let topPadding: CGFloat = 8
        let gridSpacing: CGFloat = 4 * 3 // 4 rows = 3 gaps
        let horizontalPadding: CGFloat = 8 // padding around grid
        let availableForGrid = availableHeight - headerHeight - topPadding - gridSpacing - horizontalPadding
        return max(80, availableForGrid / 4) // 4 rows of months
    }

    var body: some View {
        VStack(spacing: 4) {
            // Year header
            Text("\(year)")
                .font(.title3)
                .fontWeight(.bold)
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.top, 8)

            // Month grid
            LazyVGrid(columns: gridColumns, spacing: 4) {
                ForEach(months, id: \.self) { month in
                    MonthCell(
                        month: month,
                        dataManager: dataManager,
                        cellHeight: monthCellHeight,
                        onSelect: { onSelectMonth(month) }
                    )
                }
            }
            .padding(.horizontal, 8)
        }
        .safeAreaPadding(.top)
    }
}

// MARK: - Month Cell

private struct MonthCell: View {
    let month: Date
    @ObservedObject var dataManager: CalendarDataManager
    let cellHeight: CGFloat
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

    /// Calculate day indicator size based on cell height
    private var dayIndicatorSize: CGFloat {
        let headerSpace: CGFloat = 20 // Month name height
        let padding: CGFloat = 12 // Top + bottom padding
        let availableForDays = cellHeight - headerSpace - padding
        let rows: CGFloat = 6 // Max 6 rows in a month
        return min(12, max(8, availableForDays / rows))
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 2) {
                Text(monthName)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
                    ForEach(Array(daySlots.enumerated()), id: \.offset) { _, day in
                        if let day = day {
                            MiniDayIndicator(
                                day: day,
                                memories: dataManager.memoriesForDay(monthKey: monthKey, day: day),
                                size: dayIndicatorSize
                            )
                        } else {
                            Color.clear
                                .frame(height: dayIndicatorSize)
                        }
                    }
                }
            }
            .padding(6)
            .frame(maxWidth: .infinity)
            .frame(height: cellHeight)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 24.0))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Mini Day Indicator

private struct MiniDayIndicator: View {
    let day: Int
    let memories: [MemoryModel]
    let size: CGFloat

    private var hasMemories: Bool {
        !memories.isEmpty
    }

    private var indicatorColor: Color {
        hasMemories ? CalendarColorHelper.indicatorColor(for: memories) : .clear
    }

    private var fontSize: CGFloat {
        max(5, size * 0.55)
    }

    var body: some View {
        ZStack {
            if hasMemories {
                Circle()
                    .fill(indicatorColor)
                    .frame(width: size, height: size)
            }

            Text("\(day)")
                .font(.system(size: fontSize, weight: .medium))
                .foregroundStyle(hasMemories ? .white : .secondary)
        }
        .frame(height: size)
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
