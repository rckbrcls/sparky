import Foundation
import Testing
@testable import sparky

struct MeMetricsTests {
    @MainActor
    @Test func activityGroupsCompletionsByDayAndPeriod() throws {
        let now = try testDate(day: 18, hour: 12)
        let memories = [
            completedMemory(title: "Morning one", at: try testDate(day: 18, hour: 6)),
            completedMemory(title: "Morning two", at: try testDate(day: 18, hour: 11, minute: 59)),
            completedMemory(title: "Evening", at: try testDate(day: 17, hour: 18)),
            completedMemory(title: "Night", at: try testDate(day: 16, hour: 23))
        ]

        let metrics = MeMetrics.calculate(
            memories: memories,
            now: now,
            calendar: testCalendar
        )
        let today = try #require(metrics.activityDays.last)

        #expect(metrics.activityDays.count == 30)
        #expect(today.completionCount == 2)
        #expect(today.completionCount(for: .morning) == 2)
        #expect(today.dominantPeriod == .morning)
        #expect(metrics.streakDays == 3)
        #expect(metrics.totalCompletionCount == 4)
        #expect(metrics.completionCountLast7Days == 4)
        #expect(metrics.activeDaysLast7Days == 3)
    }

    @MainActor
    @Test func activityPeriodUsesExactCalendarBoundaries() throws {
        let calendar = testCalendar

        #expect(MeMetrics.ActivityPeriod.containing(
            try testDate(day: 18, hour: 5, minute: 59),
            calendar: calendar
        ) == .night)
        #expect(MeMetrics.ActivityPeriod.containing(
            try testDate(day: 18, hour: 6),
            calendar: calendar
        ) == .morning)
        #expect(MeMetrics.ActivityPeriod.containing(
            try testDate(day: 18, hour: 11, minute: 59),
            calendar: calendar
        ) == .morning)
        #expect(MeMetrics.ActivityPeriod.containing(
            try testDate(day: 18, hour: 12),
            calendar: calendar
        ) == .afternoon)
        #expect(MeMetrics.ActivityPeriod.containing(
            try testDate(day: 18, hour: 18),
            calendar: calendar
        ) == .evening)
        #expect(MeMetrics.ActivityPeriod.containing(
            try testDate(day: 18, hour: 22),
            calendar: calendar
        ) == .night)
    }

    @MainActor
    @Test func weeklySummariesUseAdjacentRollingWindows() throws {
        let now = try testDate(day: 18, hour: 12)
        let memories = [
            completedMemory(title: "Today", at: try testDate(day: 18, hour: 9)),
            completedMemory(title: "Current boundary", at: try testDate(day: 12, hour: 9)),
            completedMemory(title: "Previous start", at: try testDate(day: 11, hour: 9)),
            completedMemory(title: "Previous end", at: try testDate(day: 5, hour: 9)),
            completedMemory(title: "Older", at: try testDate(day: 4, hour: 9))
        ]

        let metrics = MeMetrics.calculate(
            memories: memories,
            now: now,
            calendar: testCalendar
        )

        #expect(metrics.weeklyActivityDays.count == 7)
        #expect(metrics.completionCountLast7Days == 2)
        #expect(metrics.completionCountPrevious7Days == 2)
        #expect(metrics.totalCompletionCount == 5)
    }

    @MainActor
    @Test func rhythmFindsUniquePeriodAndWeekdayWithEnoughData() throws {
        let now = try testDate(day: 18, hour: 12)
        let completionDate = try testDate(day: 14, hour: 19)
        let memories = [
            completedMemory(title: "One", at: completionDate),
            completedMemory(title: "Two", at: try testDate(day: 14, hour: 20)),
            completedMemory(title: "Three", at: try testDate(day: 14, hour: 9))
        ]

        let metrics = MeMetrics.calculate(
            memories: memories,
            now: now,
            calendar: testCalendar
        )

        #expect(metrics.rhythm.sampleCount == 3)
        #expect(metrics.rhythm.mostActivePeriod == .evening)
        #expect(
            metrics.rhythm.bestWeekday
                == testCalendar.component(.weekday, from: completionDate)
        )
        #expect(metrics.rhythm.hasReliablePattern)
    }

    @MainActor
    @Test func rhythmSuppressesTiesAndSmallSamples() throws {
        let now = try testDate(day: 18, hour: 12)
        let tied = MeMetrics.calculate(
            memories: [
                completedMemory(title: "Day one morning", at: try testDate(day: 14, hour: 9)),
                completedMemory(title: "Day one afternoon", at: try testDate(day: 14, hour: 13)),
                completedMemory(title: "Day two evening", at: try testDate(day: 15, hour: 19)),
                completedMemory(title: "Day two night", at: try testDate(day: 15, hour: 23))
            ],
            now: now,
            calendar: testCalendar
        )
        let smallSample = MeMetrics.calculate(
            memories: [
                completedMemory(title: "One", at: try testDate(day: 14, hour: 19)),
                completedMemory(title: "Two", at: try testDate(day: 14, hour: 20))
            ],
            now: now,
            calendar: testCalendar
        )

        #expect(tied.rhythm.mostActivePeriod == nil)
        #expect(tied.rhythm.bestWeekday == nil)
        #expect(!tied.rhythm.hasReliablePattern)
        #expect(smallSample.rhythm.sampleCount == 2)
        #expect(smallSample.rhythm.mostActivePeriod == nil)
        #expect(smallSample.rhythm.bestWeekday == nil)
    }

    @MainActor
    @Test func insightPrioritizesWeekOverWeekImprovement() throws {
        let now = try testDate(day: 18, hour: 12)
        let metrics = MeMetrics.calculate(
            memories: [
                completedMemory(title: "Current one", at: try testDate(day: 18, hour: 19)),
                completedMemory(title: "Current two", at: try testDate(day: 17, hour: 19)),
                completedMemory(title: "Previous", at: try testDate(day: 11, hour: 19))
            ],
            now: now,
            calendar: testCalendar
        )

        #expect(metrics.insight == .improvedWeek(delta: 1))
    }

    @MainActor
    @Test func insightFallsBackThroughRhythmBuildingAndRestart() throws {
        let now = try testDate(day: 18, hour: 12)
        let activePeriod = MeMetrics.calculate(
            memories: [
                completedMemory(title: "Current evening one", at: try testDate(day: 18, hour: 19)),
                completedMemory(title: "Current evening two", at: try testDate(day: 17, hour: 20)),
                completedMemory(title: "Previous evening", at: try testDate(day: 11, hour: 19)),
                completedMemory(title: "Previous morning", at: try testDate(day: 10, hour: 9))
            ],
            now: now,
            calendar: testCalendar
        )
        let bestWeekdayDate = try testDate(day: 1, hour: 6)
        let bestWeekday = MeMetrics.calculate(
            memories: [
                completedMemory(title: "Morning", at: bestWeekdayDate),
                completedMemory(title: "Afternoon", at: try testDate(day: 1, hour: 12)),
                completedMemory(title: "Evening", at: try testDate(day: 1, hour: 18)),
                completedMemory(title: "Night", at: try testDate(day: 1, hour: 22))
            ],
            now: now,
            calendar: testCalendar
        )
        let building = MeMetrics.calculate(
            memories: [
                completedMemory(title: "Current", at: try testDate(day: 18, hour: 9)),
                completedMemory(title: "Previous", at: try testDate(day: 11, hour: 9))
            ],
            now: now,
            calendar: testCalendar
        )
        let restart = MeMetrics.calculate(
            memories: [
                completedMemory(
                    title: "Old",
                    at: try testDate(month: 5, day: 1, hour: 9)
                )
            ],
            now: now,
            calendar: testCalendar
        )

        #expect(activePeriod.insight == .activePeriod(.evening))
        #expect(
            bestWeekday.insight
                == .bestWeekday(testCalendar.component(.weekday, from: bestWeekdayDate))
        )
        #expect(building.insight == .buildingPattern)
        #expect(restart.insight == .restart)
    }

    @MainActor
    @Test func zeroMetricsRemainValidWithAndWithoutMemories() throws {
        let now = try testDate(day: 18, hour: 12)
        let noMemories = MeMetrics.calculate(
            memories: [],
            now: now,
            calendar: testCalendar
        )
        let waiting = MeMetrics.calculate(
            memories: [Memory(title: "Ready to complete")],
            now: now,
            calendar: testCalendar
        )

        #expect(noMemories.memoryCount == 0)
        #expect(noMemories.activityDays.count == 30)
        #expect(noMemories.weeklyActivityDays.count == 7)
        #expect(noMemories.completionCountLast7Days == 0)
        #expect(noMemories.activeDaysLast7Days == 0)
        #expect(noMemories.streakDays == 0)
        #expect(noMemories.totalCompletionCount == 0)
        #expect(noMemories.rhythm.sampleCount == 0)
        #expect(noMemories.insight == .buildingPattern)
        #expect(!noMemories.completionRate.isAvailable)

        #expect(waiting.memoryCount == 1)
        #expect(waiting.completionCountLast7Days == 0)
        #expect(waiting.totalCompletionCount == 0)
        #expect(waiting.insight == .buildingPattern)
    }

    @MainActor
    @Test func futureCompletionsDoNotChangeCurrentMetrics() throws {
        let now = try testDate(day: 18, hour: 12)
        let future = completedMemory(
            title: "Future",
            at: try testDate(day: 18, hour: 15)
        )

        let metrics = MeMetrics.calculate(
            memories: [future],
            now: now,
            calendar: testCalendar
        )

        #expect(metrics.totalCompletionCount == 0)
        #expect(metrics.completionCountLast7Days == 0)
        #expect(metrics.streakDays == 0)
        #expect(metrics.rhythm.sampleCount == 0)
        #expect(metrics.insight == .buildingPattern)
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

        #expect(metrics.completionRate.isAvailable)
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
    @Test func completionRateIsUnavailableWithoutScheduledOccurrences() throws {
        let metrics = MeMetrics.calculate(
            memories: [
                completedMemory(
                    title: "Unscheduled",
                    at: try testDate(day: 18, hour: 9)
                )
            ],
            now: try testDate(day: 18, hour: 12),
            calendar: testCalendar
        )

        #expect(!metrics.completionRate.isAvailable)
        #expect(metrics.completionRate.scheduledOccurrences == 0)
        #expect(metrics.completionRate.value == 0)
    }

    @MainActor
    @Test func presentationDistinguishesMeasuredZeroFromUnavailableValues() {
        let measuredZero = MeMetrics.CompletionRate(
            completedOccurrences: 0,
            scheduledOccurrences: 4
        )
        let unavailable = MeMetrics.CompletionRate(
            completedOccurrences: 0,
            scheduledOccurrences: 0
        )

        #expect(MeMetrics.percentageText(for: measuredZero) == "0%")
        #expect(MeMetrics.percentageText(for: unavailable) == "—")
        #expect(
            MeMetrics.accessibilityText(
                for: MeMetrics.percentageText(for: unavailable)
            ) == "Not available"
        )
    }

    @MainActor
    @Test func presentationUsesDashesForInsufficientAndTiedRhythm() {
        let insufficient = MeMetrics.RhythmSummary(
            sampleCount: 2,
            mostActivePeriod: nil,
            bestWeekday: nil
        )
        let tied = MeMetrics.RhythmSummary(
            sampleCount: 4,
            mostActivePeriod: nil,
            bestWeekday: nil
        )

        #expect(
            MeMetrics.activityPeriodText(
                for: insufficient.mostActivePeriod
            ) == "—"
        )
        #expect(MeMetrics.weekdayText(for: insufficient.bestWeekday) == "—")
        #expect(MeMetrics.activityPeriodText(for: tied.mostActivePeriod) == "—")
        #expect(MeMetrics.weekdayText(for: tied.bestWeekday) == "—")
    }

    @MainActor
    @Test func presentationFormatsMeasuredPeriodAndWeekday() {
        #expect(MeMetrics.activityPeriodText(for: .evening) == "Evening")
        #expect(MeMetrics.weekdayText(for: 2) == "Monday")
        #expect(MeMetrics.accessibilityText(for: "Evening") == "Evening")
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
