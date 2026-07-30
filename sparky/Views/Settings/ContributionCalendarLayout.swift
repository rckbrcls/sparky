import Foundation

struct ContributionCalendarLayout: Equatable {
    struct Day: Identifiable, Equatable {
        let date: Date
        let completionCount: Int?

        var id: Date { date }

        var intensityLevel: Int? {
            completionCount.map(ContributionCalendarLayout.intensityLevel)
        }
    }

    struct Week: Identifiable, Equatable {
        let days: [Day]
        let monthStart: Date?

        var id: Date {
            days.first?.date ?? .distantPast
        }
    }

    let rangeStart: Date
    let rangeEnd: Date
    let weeks: [Week]
    let weekdayLabels: [String?]

    static func make(
        activityDays: [MeMetrics.ActivityDay],
        through endDate: Date,
        monthCount: Int,
        calendar: Calendar
    ) -> ContributionCalendarLayout {
        let normalizedMonthCount = max(monthCount, 1)
        let rangeEnd = calendar.startOfDay(for: endDate)
        let currentMonthComponents = calendar.dateComponents(
            [.calendar, .timeZone, .year, .month],
            from: rangeEnd
        )
        let currentMonthStart = calendar.date(from: currentMonthComponents)
            ?? rangeEnd
        let rangeStart = calendar.date(
            byAdding: .month,
            value: -(normalizedMonthCount - 1),
            to: currentMonthStart
        ) ?? currentMonthStart
        let gridStart = startOfWeek(containing: rangeStart, calendar: calendar)
        let finalWeekStart = startOfWeek(containing: rangeEnd, calendar: calendar)
        let gridEnd = calendar.date(
            byAdding: .day,
            value: 6,
            to: finalWeekStart
        ) ?? rangeEnd
        let completionsByDay = Dictionary(
            uniqueKeysWithValues: activityDays.map {
                (calendar.startOfDay(for: $0.date), $0.completionCount)
            }
        )

        var monthStartsByWeek: [Date: Date] = [:]
        for offset in 0..<normalizedMonthCount {
            guard let monthStart = calendar.date(
                byAdding: .month,
                value: offset,
                to: rangeStart
            ) else {
                continue
            }
            monthStartsByWeek[
                startOfWeek(containing: monthStart, calendar: calendar)
            ] = monthStart
        }

        var weeks: [Week] = []
        var weekStart = gridStart

        while weekStart <= gridEnd {
            let days = (0..<7).compactMap { dayOffset -> Day? in
                guard let date = calendar.date(
                    byAdding: .day,
                    value: dayOffset,
                    to: weekStart
                ) else {
                    return nil
                }
                let completionCount: Int?
                if date >= rangeStart, date <= rangeEnd {
                    completionCount = completionsByDay[date, default: 0]
                } else {
                    completionCount = nil
                }
                return Day(date: date, completionCount: completionCount)
            }

            weeks.append(
                Week(
                    days: days,
                    monthStart: monthStartsByWeek[weekStart]
                )
            )

            guard let nextWeek = calendar.date(
                byAdding: .day,
                value: 7,
                to: weekStart
            ) else {
                break
            }
            weekStart = nextWeek
        }

        return ContributionCalendarLayout(
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            weeks: weeks,
            weekdayLabels: weekdayLabels(for: calendar)
        )
    }

    nonisolated static func intensityLevel(for completionCount: Int) -> Int {
        switch completionCount {
        case ...0:
            return 0
        case 1:
            return 1
        case 2:
            return 2
        case 3...4:
            return 3
        default:
            return 4
        }
    }
}

private extension ContributionCalendarLayout {
    static func startOfWeek(
        containing date: Date,
        calendar: Calendar
    ) -> Date {
        let day = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: day)
        let offset = (weekday - calendar.firstWeekday + 7) % 7
        return calendar.date(byAdding: .day, value: -offset, to: day) ?? day
    }

    static func weekdayLabels(for calendar: Calendar) -> [String?] {
        (0..<7).map { row in
            let weekday = ((calendar.firstWeekday - 1 + row) % 7) + 1
            switch weekday {
            case 2:
                return "Mon"
            case 4:
                return "Wed"
            case 6:
                return "Fri"
            default:
                return nil
            }
        }
    }
}
