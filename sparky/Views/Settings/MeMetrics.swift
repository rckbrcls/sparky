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

        var dominantPeriod: ActivityPeriod? {
            MeMetrics.uniqueWinner(in: periodCounts)
        }
    }

    struct CompletionRate: Equatable {
        let completedOccurrences: Int
        let scheduledOccurrences: Int

        var isAvailable: Bool {
            scheduledOccurrences > 0
        }

        var value: Double {
            guard isAvailable else { return 0 }
            return min(max(Double(completedOccurrences) / Double(scheduledOccurrences), 0), 1)
        }
    }

    struct RhythmSummary: Equatable {
        let sampleCount: Int
        let mostActivePeriod: ActivityPeriod?
        let bestWeekday: Int?

        var hasReliablePattern: Bool {
            sampleCount >= MeMetrics.minimumRhythmSampleCount
                && (mostActivePeriod != nil || bestWeekday != nil)
        }
    }

    enum Insight: Equatable {
        case improvedWeek(delta: Int)
        case activePeriod(ActivityPeriod)
        case bestWeekday(Int)
        case buildingPattern
        case restart
    }

    static let minimumRhythmSampleCount = 3

    let memoryCount: Int
    let activityDays: [ActivityDay]
    let completionRate: CompletionRate
    let streakDays: Int
    let totalCompletionCount: Int
    let rhythm: RhythmSummary
    let insight: Insight

    var weeklyActivityDays: [ActivityDay] {
        Array(activityDays.suffix(7))
    }

    var completionCountLast30Days: Int {
        activityDays.reduce(0) { $0 + $1.completionCount }
    }

    var activeDaysLast30Days: Int {
        activityDays.filter { $0.completionCount > 0 }.count
    }

    var completionCountLast7Days: Int {
        weeklyActivityDays.reduce(0) { $0 + $1.completionCount }
    }

    var activeDaysLast7Days: Int {
        weeklyActivityDays.filter { $0.completionCount > 0 }.count
    }

    var completionCountPrevious7Days: Int {
        activityDays
            .dropLast(7)
            .suffix(7)
            .reduce(0) { $0 + $1.completionCount }
    }

    static func calculate(
        memories: [Memory],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> MeMetrics {
        let events = completionEvents(from: memories, through: now)
        let activityDays = makeActivityDays(events: events, now: now, calendar: calendar)
        let rhythm = makeRhythmSummary(
            events: events,
            now: now,
            calendar: calendar
        )
        let completionRate = calculateCompletionRate(
            memories: memories,
            now: now,
            calendar: calendar
        )
        let currentWeekCount = activityDays
            .suffix(7)
            .reduce(0) { $0 + $1.completionCount }
        let previousWeekCount = activityDays
            .dropLast(7)
            .suffix(7)
            .reduce(0) { $0 + $1.completionCount }
        let insight = makeInsight(
            currentWeekCount: currentWeekCount,
            previousWeekCount: previousWeekCount,
            rhythm: rhythm,
            totalCompletionCount: events.count
        )

        return MeMetrics(
            memoryCount: memories.count,
            activityDays: activityDays,
            completionRate: completionRate,
            streakDays: calculateStreak(events: events, now: now, calendar: calendar),
            totalCompletionCount: events.count,
            rhythm: rhythm,
            insight: insight
        )
    }
}

private extension MeMetrics {
    struct CompletionEvent {
        let date: Date
    }

    static func completionEvents(from memories: [Memory], through now: Date) -> [CompletionEvent] {
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
        let eventsByDay = Dictionary(grouping: events) { event in
            calendar.startOfDay(for: event.date)
        }

        return (0..<30).compactMap { index in
            guard let date = calendar.date(byAdding: .day, value: index - 29, to: today) else {
                return nil
            }

            let periodCounts = Dictionary(
                grouping: eventsByDay[date, default: []]
            ) { event in
                ActivityPeriod.containing(event.date, calendar: calendar)
            }
            .mapValues(\.count)

            return ActivityDay(date: date, periodCounts: periodCounts)
        }
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
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: day) else {
                break
            }
            day = previousDay
        }
        return streak
    }

    static func makeRhythmSummary(
        events: [CompletionEvent],
        now: Date,
        calendar: Calendar
    ) -> RhythmSummary {
        let today = calendar.startOfDay(for: now)
        let windowStart = calendar.date(byAdding: .day, value: -29, to: today) ?? today
        let recentEvents = events.filter { $0.date >= windowStart && $0.date <= now }

        guard recentEvents.count >= minimumRhythmSampleCount else {
            return RhythmSummary(
                sampleCount: recentEvents.count,
                mostActivePeriod: nil,
                bestWeekday: nil
            )
        }

        let periodCounts = Dictionary(grouping: recentEvents) { event in
            ActivityPeriod.containing(event.date, calendar: calendar)
        }
        .mapValues(\.count)
        let weekdayCounts = Dictionary(grouping: recentEvents) { event in
            calendar.component(.weekday, from: event.date)
        }
        .mapValues(\.count)

        return RhythmSummary(
            sampleCount: recentEvents.count,
            mostActivePeriod: uniqueWinner(in: periodCounts),
            bestWeekday: uniqueWinner(in: weekdayCounts)
        )
    }

    static func makeInsight(
        currentWeekCount: Int,
        previousWeekCount: Int,
        rhythm: RhythmSummary,
        totalCompletionCount: Int
    ) -> Insight {
        if currentWeekCount > previousWeekCount {
            return .improvedWeek(delta: currentWeekCount - previousWeekCount)
        }
        if let period = rhythm.mostActivePeriod {
            return .activePeriod(period)
        }
        if let weekday = rhythm.bestWeekday {
            return .bestWeekday(weekday)
        }
        if currentWeekCount > 0 {
            return .buildingPattern
        }
        return totalCompletionCount > 0 ? .restart : .buildingPattern
    }

    static func calculateCompletionRate(
        memories: [Memory],
        now: Date,
        calendar: Calendar
    ) -> CompletionRate {
        let today = calendar.startOfDay(for: now)
        guard let windowStart = calendar.date(byAdding: .day, value: -6, to: today),
              let endExclusive = calendar.date(byAdding: .second, value: 1, to: now) else {
            return CompletionRate(completedOccurrences: 0, scheduledOccurrences: 0)
        }

        var scheduled = 0
        var completed = 0

        for memory in memories {
            guard let schedule = memory.scheduleConfig, schedule.isActive else { continue }
            let occurrences = schedule
                .dates(from: windowStart, to: endExclusive)
                .filter { $0 <= now }

            scheduled += occurrences.count
            completed += occurrences.filter { occurrence in
                isOccurrenceCompleted(
                    occurrence,
                    for: memory,
                    now: now,
                    calendar: calendar
                )
            }.count
        }

        return CompletionRate(
            completedOccurrences: completed,
            scheduledOccurrences: scheduled
        )
    }

    static func isOccurrenceCompleted(
        _ occurrence: Date,
        for memory: Memory,
        now: Date,
        calendar: Calendar
    ) -> Bool {
        guard memory.hasRecurringTriggers else {
            guard memory.status == .completed, let completedAt = memory.completedAt else {
                return false
            }
            return completedAt <= now
        }

        if memory.hasIntraDayRecurrence {
            return memory.completedDates.contains { completion in
                calendar.isDate(completion, inSameDayAs: occurrence)
                    && calendar.component(.hour, from: completion) == calendar.component(.hour, from: occurrence)
                    && calendar.component(.minute, from: completion) == calendar.component(.minute, from: occurrence)
            }
        }

        return memory.completedDates.contains {
            calendar.isDate($0, inSameDayAs: occurrence)
        }
    }

    static func uniqueWinner<Key: Hashable>(in counts: [Key: Int]) -> Key? {
        guard let maximum = counts.values.max(), maximum > 0 else { return nil }
        let winners = counts.filter { $0.value == maximum }.map(\.key)
        return winners.count == 1 ? winners[0] : nil
    }
}
