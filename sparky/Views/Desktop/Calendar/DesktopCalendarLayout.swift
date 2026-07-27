import Foundation

struct DesktopCalendarLayout {
    nonisolated static let visibleMonthDayCount = 42

    nonisolated static func startOfWeek(
        containing date: Date,
        calendar: Calendar = .current
    ) -> Date {
        let startOfDay = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: startOfDay)
        let offset = (weekday - calendar.firstWeekday + 7) % 7
        return calendar.date(byAdding: .day, value: -offset, to: startOfDay) ?? startOfDay
    }

    nonisolated static func weekDates(
        containing date: Date,
        calendar: Calendar = .current
    ) -> [Date] {
        let weekStart = startOfWeek(containing: date, calendar: calendar)
        return (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: weekStart)
        }
    }

    nonisolated static func monthDates(
        containing date: Date,
        calendar: Calendar = .current
    ) -> [Date] {
        let monthStart = calendar.date(
            from: calendar.dateComponents([.year, .month], from: date)
        ) ?? calendar.startOfDay(for: date)
        let gridStart = startOfWeek(containing: monthStart, calendar: calendar)

        return (0..<visibleMonthDayCount).compactMap {
            calendar.date(byAdding: .day, value: $0, to: gridStart)
        }
    }

    nonisolated static func shiftedAnchor(
        _ date: Date,
        mode: DesktopCalendarMode,
        direction: Int,
        calendar: Calendar = .current
    ) -> Date {
        let component: Calendar.Component = mode == .day ? .day : .month
        return calendar.date(byAdding: component, value: direction, to: date) ?? date
    }

    nonisolated static func monthsNeeded(
        for dates: [Date],
        calendar: Calendar = .current
    ) -> [Date] {
        var seen = Set<Date>()
        return dates.compactMap { date in
            let month = calendar.date(
                from: calendar.dateComponents([.year, .month], from: date)
            ) ?? date
            return seen.insert(month).inserted ? month : nil
        }
    }

    nonisolated static func monthsNeeded(
        for anchorDate: Date,
        mode: DesktopCalendarMode,
        calendar: Calendar = .current
    ) -> [Date] {
        let visibleDates: [Date]
        switch mode {
        case .day:
            visibleDates = [anchorDate]
        case .month:
            visibleDates = monthDates(containing: anchorDate, calendar: calendar)
        }
        return monthsNeeded(for: visibleDates, calendar: calendar)
    }
}
