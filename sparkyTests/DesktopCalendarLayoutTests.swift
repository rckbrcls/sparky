//
//  DesktopCalendarLayoutTests.swift
//  sparkyTests
//

import Foundation
import Testing
@testable import sparky

@MainActor
@Suite("Desktop calendar layout")
struct DesktopCalendarLayoutTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    @Test("Day selector contains seven locale-aligned dates across month boundaries")
    func daySelectorMonthBoundary() {
        let anchor = makeDate(year: 2026, month: 7, day: 27)
        let dates = DesktopCalendarLayout.weekDates(
            containing: anchor,
            calendar: calendar
        )

        #expect(dates.count == 7)
        #expect(dates.first == makeDate(year: 2026, month: 7, day: 26))
        #expect(dates.last == makeDate(year: 2026, month: 8, day: 1))
    }

    @Test("Day selector honors a Monday-first locale")
    func mondayFirstDaySelector() {
        var mondayFirstCalendar = calendar
        mondayFirstCalendar.firstWeekday = 2

        let dates = DesktopCalendarLayout.weekDates(
            containing: makeDate(year: 2026, month: 7, day: 29),
            calendar: mondayFirstCalendar
        )

        #expect(dates.first == makeDate(year: 2026, month: 7, day: 27))
        #expect(dates.last == makeDate(year: 2026, month: 8, day: 2))
    }

    @Test("Day selector remains seven local dates across daylight saving time")
    func daySelectorDaylightSavingBoundary() {
        var daylightCalendar = calendar
        daylightCalendar.timeZone = TimeZone(identifier: "America/New_York")!
        let anchor = daylightCalendar.date(
            from: DateComponents(year: 2026, month: 3, day: 8, hour: 12)
        )!
        let dates = DesktopCalendarLayout.weekDates(
            containing: anchor,
            calendar: daylightCalendar
        )

        #expect(dates.count == 7)
        #expect(daylightCalendar.component(.day, from: dates.first!) == 8)
        #expect(daylightCalendar.component(.day, from: dates.last!) == 14)
    }

    @Test("Day selector remains aligned when the year changes")
    func daySelectorYearBoundary() {
        let dates = DesktopCalendarLayout.weekDates(
            containing: makeDate(year: 2027, month: 1, day: 1),
            calendar: calendar
        )

        #expect(dates.first == makeDate(year: 2026, month: 12, day: 27))
        #expect(dates.last == makeDate(year: 2027, month: 1, day: 2))
    }

    @Test("Month always renders six complete weeks")
    func monthGrid() {
        let dates = DesktopCalendarLayout.monthDates(
            containing: makeDate(year: 2026, month: 7, day: 27),
            calendar: calendar
        )

        #expect(dates.count == 42)
        #expect(dates.first == makeDate(year: 2026, month: 6, day: 28))
        #expect(dates.last == makeDate(year: 2026, month: 8, day: 8))
    }

    @Test("Navigation shifts by the active calendar mode")
    func navigationStep() {
        let anchor = makeDate(year: 2026, month: 7, day: 27)

        #expect(
            DesktopCalendarLayout.shiftedAnchor(
                anchor,
                mode: .day,
                direction: 1,
                calendar: calendar
            ) == makeDate(year: 2026, month: 7, day: 28)
        )
        #expect(
            DesktopCalendarLayout.shiftedAnchor(
                anchor,
                mode: .month,
                direction: -1,
                calendar: calendar
            ) == makeDate(year: 2026, month: 6, day: 27)
        )
    }

    @Test("Day navigation preserves local time across daylight saving changes")
    func dayNavigationAcrossDaylightSaving() {
        var daylightCalendar = calendar
        daylightCalendar.timeZone = TimeZone(identifier: "America/New_York")!
        let anchor = daylightCalendar.date(
            from: DateComponents(
                year: 2026,
                month: 3,
                day: 7,
                hour: 12
            )
        )!

        let shifted = DesktopCalendarLayout.shiftedAnchor(
            anchor,
            mode: .day,
            direction: 1,
            calendar: daylightCalendar
        )

        #expect(daylightCalendar.component(.day, from: shifted) == 8)
        #expect(daylightCalendar.component(.hour, from: shifted) == 12)
    }

    @Test("Visible ranges expose every required month once")
    func requiredMonths() {
        let months = DesktopCalendarLayout.monthsNeeded(
            for: makeDate(year: 2026, month: 7, day: 27),
            mode: .day,
            calendar: calendar
        )

        #expect(months == [
            makeDate(year: 2026, month: 7, day: 1)
        ])

        #expect(
            DesktopCalendarLayout.monthsNeeded(
                for: makeDate(year: 2026, month: 7, day: 27),
                mode: .month,
                calendar: calendar
            ) == [
                makeDate(year: 2026, month: 6, day: 1),
                makeDate(year: 2026, month: 7, day: 1),
                makeDate(year: 2026, month: 8, day: 1)
            ]
        )
    }

    private func makeDate(
        year: Int,
        month: Int,
        day: Int
    ) -> Date {
        calendar.date(
            from: DateComponents(year: year, month: month, day: day)
        )!
    }
}
