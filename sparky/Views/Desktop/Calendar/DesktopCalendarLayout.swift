import Foundation

struct DesktopCalendarTitle: Equatable {
    var leading: String
    var trailing: String
}

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
        switch mode {
        case .day:
            return calendar.date(byAdding: .day, value: direction, to: date) ?? date
        case .week:
            return calendar.date(byAdding: .day, value: direction * 7, to: date) ?? date
        case .month:
            return calendar.date(byAdding: .month, value: direction, to: date) ?? date
        }
    }

    nonisolated static func title(
        for anchorDate: Date,
        mode: DesktopCalendarMode,
        calendar: Calendar = .current
    ) -> DesktopCalendarTitle {
        switch mode {
        case .day, .month:
            return DesktopCalendarTitle(
                leading: monthName(anchorDate, calendar: calendar),
                trailing: yearName(anchorDate, calendar: calendar)
            )
        case .week:
            let dates = weekDates(containing: anchorDate, calendar: calendar)
            guard let first = dates.first, let last = dates.last else {
                return DesktopCalendarTitle(
                    leading: monthName(anchorDate, calendar: calendar),
                    trailing: yearName(anchorDate, calendar: calendar)
                )
            }

            if calendar.isDate(first, equalTo: last, toGranularity: .month) {
                return DesktopCalendarTitle(
                    leading: monthName(first, calendar: calendar),
                    trailing: yearName(first, calendar: calendar)
                )
            }

            if calendar.isDate(first, equalTo: last, toGranularity: .year) {
                return DesktopCalendarTitle(
                    leading: "\(monthName(first, calendar: calendar)) – \(monthName(last, calendar: calendar))",
                    trailing: yearName(first, calendar: calendar)
                )
            }

            return DesktopCalendarTitle(
                leading: "\(monthName(first, calendar: calendar)) \(yearName(first, calendar: calendar)) – \(monthName(last, calendar: calendar)) \(yearName(last, calendar: calendar))",
                trailing: ""
            )
        }
    }

    private nonisolated static func monthName(_ date: Date, calendar: Calendar) -> String {
        date.formatted(
            .dateTime
                .month(.wide)
                .locale(calendar.locale ?? .autoupdatingCurrent)
        )
    }

    private nonisolated static func yearName(_ date: Date, calendar: Calendar) -> String {
        date.formatted(
            .dateTime
                .year()
                .locale(calendar.locale ?? .autoupdatingCurrent)
        )
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
        case .week:
            visibleDates = weekDates(containing: anchorDate, calendar: calendar)
        case .month:
            visibleDates = monthDates(containing: anchorDate, calendar: calendar)
        }
        return monthsNeeded(for: visibleDates, calendar: calendar)
    }
}
