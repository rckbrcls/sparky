import Foundation
import Testing
@testable import sparky

struct MeMetricsTests {
    @MainActor
    @Test func activityCountsCompletionsAndBuildsCurrentStreak() throws {
        let calendar = testCalendar
        let now = try testDate(day: 18, hour: 12)
        let memories = [
            completedMemory(title: "Today one", at: try testDate(day: 18, hour: 9)),
            completedMemory(title: "Today two", at: try testDate(day: 18, hour: 10)),
            completedMemory(title: "Yesterday", at: try testDate(day: 17, hour: 9)),
            completedMemory(title: "Two days ago", at: try testDate(day: 16, hour: 9))
        ]

        let metrics = MeMetrics.calculate(memories: memories, now: now, calendar: calendar)

        #expect(metrics.activityDays.count == 30)
        #expect(metrics.activityDays.last?.completionCount == 2)
        #expect(metrics.streakDays == 3)
        #expect(metrics.longestStreakDays == 3)
        #expect(metrics.totalCompletionCount == 4)
        #expect(metrics.completionCountLast7Days == 4)
        #expect(metrics.activeDaysLast7Days == 3)
    }

    @MainActor
    @Test func dominantMindIsCalculatedWhenThereIsAClearWinner() throws {
        let now = try testDate(day: 18, hour: 12)
        let mind = Mind(name: "Work")
        let first = completedMemory(title: "First", at: try testDate(day: 14, hour: 9))
        let second = completedMemory(title: "Second", at: try testDate(day: 14, hour: 10))
        first.mind = mind
        second.mind = mind

        let metrics = MeMetrics.calculate(
            memories: [first, second],
            now: now,
            calendar: testCalendar
        )

        #expect(metrics.streakDays == 0)
        #expect(metrics.topMindName == "Work")
    }

    @MainActor
    @Test func personalBestsAreEmptyWithoutCompletionHistory() throws {
        let now = try testDate(day: 18, hour: 12)
        let empty = MeMetrics.calculate(memories: [], now: now, calendar: testCalendar)

        #expect(empty.totalCompletionCount == 0)
        #expect(empty.longestStreakDays == 0)
        #expect(empty.topMindName == nil)
    }

    @MainActor
    @Test func topMindIsUnavailableForTiesAndUnsortedCompletions() throws {
        let now = try testDate(day: 18, hour: 12)
        let work = Mind(name: "Work")
        let home = Mind(name: "Home")
        let workMemory = completedMemory(title: "Work", at: try testDate(day: 14, hour: 9))
        let homeMemory = completedMemory(title: "Home", at: try testDate(day: 14, hour: 10))
        let unsorted = completedMemory(title: "Unsorted", at: try testDate(day: 14, hour: 11))
        workMemory.mind = work
        homeMemory.mind = home

        let tied = MeMetrics.calculate(
            memories: [workMemory, homeMemory],
            now: now,
            calendar: testCalendar
        )
        let withoutMind = MeMetrics.calculate(
            memories: [unsorted],
            now: now,
            calendar: testCalendar
        )

        #expect(tied.topMindName == nil)
        #expect(withoutMind.topMindName == nil)
    }

    @MainActor
    @Test func weeklySummaryUsesARollingSevenDayWindow() throws {
        let now = try testDate(day: 18, hour: 12)
        let included = completedMemory(title: "Included", at: try testDate(day: 12, hour: 9))
        let excluded = completedMemory(title: "Excluded", at: try testDate(day: 11, hour: 9))

        let metrics = MeMetrics.calculate(
            memories: [included, excluded],
            now: now,
            calendar: testCalendar
        )

        #expect(metrics.completionCountLast7Days == 1)
        #expect(metrics.activeDaysLast7Days == 1)
        #expect(metrics.totalCompletionCount == 2)
    }

    @MainActor
    @Test func completionRateCountsOnlyElapsedScheduledOccurrences() throws {
        let calendar = testCalendar
        let now = try testDate(day: 18, hour: 12)
        let daily = Memory(title: "Daily rhythm")
        let dailySchedule = ScheduleConfig(
            fireDate: try testDate(day: 12, hour: 9),
            startDate: try testDate(day: 12, hour: 9),
            recurrenceRule: RecurrenceRule(frequency: .daily, interval: 1),
            timeZoneIdentifier: "UTC",
            isActive: true,
            memory: daily
        )
        daily.scheduleConfig = dailySchedule
        daily.completionDateEntries = [
            MemoryCompletionDate(date: try testDate(day: 12, hour: 9), memory: daily),
            MemoryCompletionDate(date: try testDate(day: 18, hour: 9), memory: daily)
        ]

        let futureToday = Memory(title: "Future today")
        futureToday.scheduleConfig = ScheduleConfig(
            fireDate: try testDate(day: 18, hour: 15),
            startDate: try testDate(day: 18, hour: 15),
            timeZoneIdentifier: "UTC",
            isActive: true,
            memory: futureToday
        )

        let locationOnly = Memory(title: "Location only")
        locationOnly.locationConfig = LocationConfig(
            latitude: 0,
            longitude: 0,
            name: "Somewhere",
            event: .onEntry,
            memory: locationOnly
        )

        let metrics = MeMetrics.calculate(
            memories: [daily, futureToday, locationOnly],
            now: now,
            calendar: calendar
        )

        #expect(metrics.completionRate.scheduledOccurrences == 7)
        #expect(metrics.completionRate.completedOccurrences == 2)
        #expect(metrics.completionRate.value == 2.0 / 7.0)
    }

    @MainActor
    @Test func intraDayRateMatchesTheSpecificHourAndMinute() throws {
        let now = try testDate(day: 18, hour: 12)
        let memory = Memory(title: "Hourly")
        memory.scheduleConfig = ScheduleConfig(
            fireDate: try testDate(day: 18, hour: 9),
            startDate: try testDate(day: 18, hour: 9),
            recurrenceRule: RecurrenceRule(frequency: .hourly, interval: 1),
            timeZoneIdentifier: "UTC",
            isActive: true,
            memory: memory
        )
        memory.completionDateEntries = [
            MemoryCompletionDate(date: try testDate(day: 18, hour: 9), memory: memory),
            MemoryCompletionDate(date: try testDate(day: 18, hour: 11), memory: memory)
        ]

        let metrics = MeMetrics.calculate(
            memories: [memory],
            now: now,
            calendar: testCalendar
        )

        #expect(metrics.completionRate.scheduledOccurrences == 4)
        #expect(metrics.completionRate.completedOccurrences == 2)
        #expect(metrics.completionRate.value == 0.5)
    }

    @MainActor
    @Test func completionRateIsZeroWithoutScheduledOccurrences() throws {
        let metrics = MeMetrics.calculate(
            memories: [completedMemory(title: "Unscheduled", at: try testDate(day: 18, hour: 9))],
            now: try testDate(day: 18, hour: 12),
            calendar: testCalendar
        )

        #expect(metrics.completionRate.scheduledOccurrences == 0)
        #expect(metrics.completionRate.value == 0)
    }

    @MainActor
    @Test func quoteChangesOnConsecutiveDaysAndPreservesTheDefault() throws {
        let today = try testDate(day: 18, hour: 12)
        let quotes = (0..<20).compactMap { dayOffset -> MeViewModel.Quote? in
            guard let date = testCalendar.date(byAdding: .day, value: dayOffset, to: today) else {
                return nil
            }
            return MeViewModel.quote(for: date, calendar: testCalendar)
        }

        #expect(MeViewModel.Quote.defaultQuote.text == "The best way to predict the future is to create it.")
        #expect(MeViewModel.Quote.defaultQuote.author == "Peter Drucker")
        #expect(quotes.count == 20)
        #expect(Set(quotes).count == 20)
    }
}

private extension MeMetricsTests {
    var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testDate(
        month: Int = 7,
        day: Int,
        hour: Int,
        minute: Int = 0
    ) throws -> Date {
        try #require(testCalendar.date(from: DateComponents(
            year: 2026,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )))
    }

    @MainActor
    func completedMemory(title: String, at date: Date) -> Memory {
        Memory(
            title: title,
            statusRaw: MemoryStatus.completed.rawValue,
            createdAt: date.addingTimeInterval(-3_600),
            updatedAt: date,
            completedAt: date
        )
    }
}
