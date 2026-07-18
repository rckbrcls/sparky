import Foundation

struct MeMetrics {
    struct ActivityDay: Identifiable, Equatable {
        let date: Date
        let completionCount: Int

        var id: Date { date }
    }

    struct CompletionRate: Equatable {
        let completedOccurrences: Int
        let scheduledOccurrences: Int

        var value: Double? {
            guard scheduledOccurrences > 0 else { return nil }
            return Double(completedOccurrences) / Double(scheduledOccurrences)
        }
    }

    let activityDays: [ActivityDay]
    let completionRate: CompletionRate
    let streakDays: Int
    let insight: String

    var completionCountLast30Days: Int {
        activityDays.reduce(0) { $0 + $1.completionCount }
    }

    var activeDaysLast30Days: Int {
        activityDays.count { $0.completionCount > 0 }
    }

    static func calculate(
        memories: [Memory],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> MeMetrics {
        let events = completionEvents(from: memories, through: now)
        let activityDays = makeActivityDays(events: events, now: now, calendar: calendar)
        let streakDays = calculateStreak(events: events, now: now, calendar: calendar)
        let completionRate = calculateCompletionRate(
            memories: memories,
            now: now,
            calendar: calendar
        )
        let insight = makeInsight(
            events: events,
            activityDays: activityDays,
            streakDays: streakDays,
            now: now,
            calendar: calendar
        )

        return MeMetrics(
            activityDays: activityDays,
            completionRate: completionRate,
            streakDays: streakDays,
            insight: insight
        )
    }
}

private extension MeMetrics {
    struct CompletionEvent {
        let date: Date
        let memory: Memory
    }

    static func completionEvents(from memories: [Memory], through now: Date) -> [CompletionEvent] {
        memories.flatMap { memory -> [CompletionEvent] in
            if memory.hasRecurringTriggers {
                return memory.completedDates
                    .filter { $0 <= now }
                    .map { CompletionEvent(date: $0, memory: memory) }
            }

            guard memory.status == .completed,
                  let completedAt = memory.completedAt,
                  completedAt <= now else {
                return []
            }
            return [CompletionEvent(date: completedAt, memory: memory)]
        }
    }

    static func makeActivityDays(
        events: [CompletionEvent],
        now: Date,
        calendar: Calendar
    ) -> [ActivityDay] {
        let today = calendar.startOfDay(for: now)
        let countsByDay = Dictionary(grouping: events) { event in
            calendar.startOfDay(for: event.date)
        }.mapValues(\.count)

        return (0..<30).compactMap { index in
            guard let date = calendar.date(byAdding: .day, value: index - 29, to: today) else {
                return nil
            }
            return ActivityDay(date: date, completionCount: countsByDay[date, default: 0])
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
            completed += occurrences.count { occurrence in
                isOccurrenceCompleted(
                    occurrence,
                    for: memory,
                    now: now,
                    calendar: calendar
                )
            }
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

    static func makeInsight(
        events: [CompletionEvent],
        activityDays: [ActivityDay],
        streakDays: Int,
        now: Date,
        calendar: Calendar
    ) -> String {
        if streakDays >= 2 {
            return "You have shown up for \(streakDays) days in a row."
        }

        let recentEvents = events.filter { event in
            guard let start = activityDays.first?.date else { return false }
            return event.date >= start && event.date <= now
        }
        if let mindName = dominantMindName(in: recentEvents) {
            return "Most of your recent progress happened in \(mindName)."
        }

        let today = calendar.startOfDay(for: now)
        let lastSevenDays = Set(activityDays.suffix(7).filter { $0.completionCount > 0 }.map(\.date))
        let completionCount = activityDays.suffix(7).reduce(0) { $0 + $1.completionCount }
        if completionCount > 0 {
            let completionLabel = completionCount == 1 ? "memory" : "memories"
            let dayLabel = lastSevenDays.count == 1 ? "day" : "days"
            return "You completed \(completionCount) \(completionLabel) across \(lastSevenDays.count) \(dayLabel) in the last 7 days."
        }

        if events.contains(where: { $0.date < today }) {
            return "A small completion today can start a new rhythm."
        }

        return "Complete a memory to start seeing your rhythm."
    }

    static func dominantMindName(in events: [CompletionEvent]) -> String? {
        let counts = Dictionary(grouping: events.compactMap { event -> String? in
            guard let name = event.memory.mind?.name.trimmingCharacters(in: .whitespacesAndNewlines),
                  !name.isEmpty else {
                return nil
            }
            return name
        }, by: { $0 }).mapValues(\.count)

        let ranked = counts.sorted { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value > rhs.value }
            return lhs.key.localizedCaseInsensitiveCompare(rhs.key) == .orderedAscending
        }
        guard let first = ranked.first,
              first.value >= 2,
              ranked.dropFirst().first?.value != first.value else {
            return nil
        }
        return first.key
    }
}
