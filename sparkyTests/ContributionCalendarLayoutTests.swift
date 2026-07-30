import Foundation
import Testing
@testable import sparky

struct ContributionCalendarLayoutTests {
    @MainActor
    @Test func fourMonthRangeIsAlignedToCompleteWeeks() throws {
        let endDate = try testDate(year: 2026, month: 7, day: 18)
        let layout = ContributionCalendarLayout.make(
            activityDays: [],
            through: endDate,
            monthCount: 4,
            calendar: testCalendar
        )
        let firstCell = try #require(layout.weeks.first?.days.first)
        let lastCell = try #require(layout.weeks.last?.days.last)
        let displayedMonths = layout.weeks.compactMap(\.monthStart)
        let expectedRangeStart = try testDate(
            year: 2026,
            month: 4,
            day: 1
        )
        let expectedGridStart = try testDate(
            year: 2026,
            month: 3,
            day: 29
        )

        #expect(layout.rangeStart == expectedRangeStart)
        #expect(layout.rangeEnd == endDate)
        #expect(firstCell.date == expectedGridStart)
        #expect(lastCell.date == endDate)
        #expect(layout.weeks.allSatisfy { $0.days.count == 7 })
        #expect(displayedMonths.map { monthNumber(for: $0) } == [4, 5, 6, 7])
        #expect(layout.weekdayLabels == [nil, "Mon", nil, "Wed", nil, "Fri", nil])
    }

    @MainActor
    @Test func twelveMonthRangeIncludesThePreviousElevenMonths() throws {
        let endDate = try testDate(year: 2026, month: 7, day: 18)
        let layout = ContributionCalendarLayout.make(
            activityDays: [],
            through: endDate,
            monthCount: 12,
            calendar: testCalendar
        )
        let firstCell = try #require(layout.weeks.first?.days.first)
        let displayedMonths = layout.weeks.compactMap(\.monthStart)
        let expectedRangeStart = try testDate(
            year: 2025,
            month: 8,
            day: 1
        )
        let expectedGridStart = try testDate(
            year: 2025,
            month: 7,
            day: 27
        )

        #expect(layout.rangeStart == expectedRangeStart)
        #expect(firstCell.date == expectedGridStart)
        #expect(displayedMonths.count == 12)
        #expect(displayedMonths.map { monthNumber(for: $0) } == [
            8, 9, 10, 11, 12, 1, 2, 3, 4, 5, 6, 7
        ])
    }

    @MainActor
    @Test func layoutPreservesDailyAggregationAndFuturePlaceholders() throws {
        let activeDate = try testDate(year: 2026, month: 7, day: 16)
        let endDate = try testDate(year: 2026, month: 7, day: 17)
        let layout = ContributionCalendarLayout.make(
            activityDays: [
                MeMetrics.ActivityDay(
                    date: activeDate,
                    periodCounts: [.morning: 2, .evening: 1]
                )
            ],
            through: endDate,
            monthCount: 4,
            calendar: testCalendar
        )
        let cells = layout.weeks.flatMap(\.days)
        let activeCell = try #require(cells.first { $0.date == activeDate })
        let futureDate = try #require(
            testCalendar.date(byAdding: .day, value: 1, to: endDate)
        )
        let futureCell = try #require(
            cells.first { $0.date == futureDate }
        )

        #expect(activeCell.completionCount == 3)
        #expect(activeCell.intensityLevel == 3)
        #expect(futureCell.completionCount == nil)
        #expect(futureCell.intensityLevel == nil)
    }

    @MainActor
    @Test func intensityLevelsUseFiveStableBuckets() {
        #expect(ContributionCalendarLayout.intensityLevel(for: 0) == 0)
        #expect(ContributionCalendarLayout.intensityLevel(for: 1) == 1)
        #expect(ContributionCalendarLayout.intensityLevel(for: 2) == 2)
        #expect(ContributionCalendarLayout.intensityLevel(for: 3) == 3)
        #expect(ContributionCalendarLayout.intensityLevel(for: 4) == 3)
        #expect(ContributionCalendarLayout.intensityLevel(for: 5) == 4)
        #expect(ContributionCalendarLayout.intensityLevel(for: 20) == 4)
    }
}

private extension ContributionCalendarLayoutTests {
    var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 1
        return calendar
    }

    func testDate(year: Int, month: Int, day: Int) throws -> Date {
        try #require(testCalendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day
        )))
    }

    func monthNumber(for date: Date) -> Int {
        testCalendar.component(.month, from: date)
    }
}
