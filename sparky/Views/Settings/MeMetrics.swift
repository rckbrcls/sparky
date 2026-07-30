import Foundation

struct MeMetrics: Equatable {
    enum ActivityPeriod: String, CaseIterable, Hashable {
        case morning
        case afternoon
        case evening
        case night

        static func containing(_ date: Date, calendar: Calendar) -> ActivityPeriod {
            switch calendar.component(.hour, from: date) {
            case 6..<12:
                return .morning
            case 12..<18:
                return .afternoon
            case 18..<22:
                return .evening
            default:
                return .night
            }
        }
    }

    struct ActivityDay: Identifiable, Equatable {
        let date: Date
        let periodCounts: [ActivityPeriod: Int]

        var id: Date { date }

        var completionCount: Int {
            periodCounts.values.reduce(0, +)
        }

        func completionCount(for period: ActivityPeriod) -> Int {
            periodCounts[period, default: 0]
        }
    }

    static let historyMonthCount = 12

    let activityDays: [ActivityDay]
    let streakDays: Int
    let totalCompletionCount: Int

    var weeklyActivityDays: [ActivityDay] {
        Array(activityDays.suffix(7))
    }

    static func calculate(
        memories: [Memory],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> MeMetrics {
        let events = completionEvents(from: memories, through: now)

        return MeMetrics(
            activityDays: makeActivityDays(
                events: events,
                now: now,
                calendar: calendar
            ),
            streakDays: calculateStreak(
                events: events,
                now: now,
                calendar: calendar
            ),
            totalCompletionCount: events.count
        )
    }
}

private extension MeMetrics {
    struct CompletionEvent {
        let date: Date
    }

    static func completionEvents(
        from memories: [Memory],
        through now: Date
    ) -> [CompletionEvent] {
        memories.flatMap { memory -> [CompletionEvent] in
            if memory.hasRecurringTriggers {
                return memory.completedDates
                    .filter { $0 <= now }
                    .map(CompletionEvent.init(date:))
            }

            guard memory.status == .completed,
                  let completedAt = memory.completedAt,
                  completedAt <= now else {
                return []
            }
            return [CompletionEvent(date: completedAt)]
        }
    }

    static func makeActivityDays(
        events: [CompletionEvent],
        now: Date,
        calendar: Calendar
    ) -> [ActivityDay] {
        let today = calendar.startOfDay(for: now)
        let currentMonthComponents = calendar.dateComponents(
            [.calendar, .timeZone, .year, .month],
            from: today
        )
        let currentMonthStart = calendar.date(from: currentMonthComponents) ?? today
        let historyStart = calendar.date(
            byAdding: .month,
            value: -(historyMonthCount - 1),
            to: currentMonthStart
        ) ?? currentMonthStart
        let eventsByDay = Dictionary(grouping: events) { event in
            calendar.startOfDay(for: event.date)
        }

        var days: [ActivityDay] = []
        var date = historyStart

        while date <= today {
            let periodCounts = Dictionary(
                grouping: eventsByDay[date, default: []]
            ) { event in
                ActivityPeriod.containing(event.date, calendar: calendar)
            }
            .mapValues(\.count)

            days.append(
                ActivityDay(date: date, periodCounts: periodCounts)
            )

            guard let nextDate = calendar.date(
                byAdding: .day,
                value: 1,
                to: date
            ) else {
                break
            }
            date = nextDate
        }

        return days
    }

    static func calculateStreak(
        events: [CompletionEvent],
        now: Date,
        calendar: Calendar
    ) -> Int {
        let activeDays = Set(events.map { calendar.startOfDay(for: $0.date) })
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)

        let startingDay: Date
        if activeDays.contains(today) {
            startingDay = today
        } else if let yesterday, activeDays.contains(yesterday) {
            startingDay = yesterday
        } else {
            return 0
        }

        var streak = 0
        var day = startingDay

        while activeDays.contains(day) {
            streak += 1
            guard let previousDay = calendar.date(
                byAdding: .day,
                value: -1,
                to: day
            ) else {
                break
            }
            day = previousDay
        }

        return streak
    }
}
