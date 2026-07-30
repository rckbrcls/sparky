import Foundation
import Testing
@testable import sparky

struct MeMetricsTests {
    @MainActor
    @Test func annualHistoryAggregatesCompletionsByDayAndPeriod() throws {
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
        let firstDay = try #require(metrics.activityDays.first)
        let today = try #require(metrics.activityDays.last)
        let expectedFirstDay = try testDate(
            year: 2025,
            month: 8,
            day: 1,
            hour: 0
        )
        let expectedToday = try testDate(day: 18, hour: 0)

        #expect(firstDay.date == expectedFirstDay)
        #expect(today.date == expectedToday)
        #expect(today.completionCount == 2)
        #expect(today.completionCount(for: .morning) == 2)
        #expect(metrics.streakDays == 3)
        #expect(metrics.totalCompletionCount == 4)
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
    @Test func streakMayContinueFromYesterday() throws {
        let now = try testDate(day: 18, hour: 12)
        let metrics = MeMetrics.calculate(
            memories: [
                completedMemory(title: "Yesterday", at: try testDate(day: 17, hour: 9)),
                completedMemory(title: "Two days ago", at: try testDate(day: 16, hour: 9)),
                completedMemory(title: "Three days ago", at: try testDate(day: 15, hour: 9)),
                completedMemory(title: "Before gap", at: try testDate(day: 13, hour: 9))
            ],
            now: now,
            calendar: testCalendar
        )

        #expect(metrics.streakDays == 3)
    }

    @MainActor
    @Test func recurringAndNonRecurringCompletionsContributeToAllTime() throws {
        let now = try testDate(day: 18, hour: 12)
        let recurring = Memory(title: "Daily reflection")
        recurring.scheduleConfig = ScheduleConfig(
            fireDate: try testDate(day: 16, hour: 9),
            startDate: try testDate(day: 16, hour: 9),
            recurrenceRule: RecurrenceRule(frequency: .daily, interval: 1),
            timeZoneIdentifier: "UTC",
            isActive: true,
            memory: recurring
        )
        recurring.completionDateEntries = [
            MemoryCompletionDate(
                date: try testDate(day: 16, hour: 9),
                memory: recurring
            ),
            MemoryCompletionDate(
                date: try testDate(day: 17, hour: 9),
                memory: recurring
            ),
            MemoryCompletionDate(
                date: try testDate(day: 18, hour: 15),
                memory: recurring
            )
        ]

        let metrics = MeMetrics.calculate(
            memories: [
                recurring,
                completedMemory(
                    title: "One-off completion",
                    at: try testDate(day: 18, hour: 10)
                )
            ],
            now: now,
            calendar: testCalendar
        )

        #expect(metrics.totalCompletionCount == 3)
        #expect(metrics.streakDays == 3)
    }

    @MainActor
    @Test func allTimeIncludesCompletionsOutsideAnnualHistory() throws {
        let now = try testDate(day: 18, hour: 12)
        let metrics = MeMetrics.calculate(
            memories: [
                completedMemory(
                    title: "Older completion",
                    at: try testDate(
                        year: 2024,
                        month: 1,
                        day: 10,
                        hour: 9
                    )
                )
            ],
            now: now,
            calendar: testCalendar
        )

        #expect(metrics.totalCompletionCount == 1)
        #expect(metrics.activityDays.allSatisfy { $0.completionCount == 0 })
        #expect(metrics.streakDays == 0)
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
        #expect(metrics.streakDays == 0)
        #expect(metrics.activityDays.last?.completionCount == 0)
    }

    @MainActor
    @Test func zeroMetricsKeepTheCompleteLayout() throws {
        let now = try testDate(day: 18, hour: 12)
        let metrics = MeMetrics.calculate(
            memories: [],
            now: now,
            calendar: testCalendar
        )

        #expect(!metrics.activityDays.isEmpty)
        #expect(metrics.weeklyActivityDays.count == 7)
        #expect(metrics.activityDays.allSatisfy { $0.completionCount == 0 })
        #expect(metrics.streakDays == 0)
        #expect(metrics.totalCompletionCount == 0)
    }
}

private extension MeMetricsTests {
    var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 1
        return calendar
    }

    func testDate(
        year: Int = 2026,
        month: Int = 7,
        day: Int,
        hour: Int,
        minute: Int = 0
    ) throws -> Date {
        try #require(testCalendar.date(from: DateComponents(
            year: year,
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
