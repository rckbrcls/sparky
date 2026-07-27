#if os(macOS)

import SwiftUI

struct DesktopMonthCalendarView: View {
    @ObservedObject var dataManager: CalendarDataManager

    let anchorDate: Date
    let onSelect: (Memory) -> Void
    let onOpenWeek: (Date) -> Void

    private let calendar = Calendar.current
    private let weekdayHeaderHeight: CGFloat = 40

    private var days: [Date] {
        DesktopCalendarLayout.monthDates(containing: anchorDate, calendar: calendar)
    }

    var body: some View {
        VStack(spacing: 0) {
            weekdayHeader

            GeometryReader { geometry in
                let rowHeight = max(
                    72,
                    (geometry.size.height - 1) / CGFloat(6)
                )

                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(.flexible(), spacing: 0),
                        count: 7
                    ),
                    spacing: 0
                ) {
                    ForEach(days, id: \.self) { day in
                        DesktopMonthDayCell(
                            date: day,
                            isInDisplayedMonth: calendar.isDate(day, equalTo: anchorDate, toGranularity: .month),
                            occurrences: dataManager.occurrencesForDate(day),
                            onSelect: onSelect,
                            onOpenWeek: onOpenWeek
                        )
                        .frame(height: rowHeight)
                    }
                }
            }
        }
        .background(Color.Theme.background)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(DesktopCalendarLayout.weekDates(containing: anchorDate, calendar: calendar), id: \.self) { day in
                Text(day.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.Theme.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(height: weekdayHeaderHeight)
        .accessibilityElement(children: .contain)
    }
}

#endif
