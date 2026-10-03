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
                mode: .week,
                direction: 1,
                calendar: calendar
            ) == makeDate(year: 2026, month: 8, day: 3)
        )
        #expect(
            DesktopCalendarLayout.shiftedAnchor(
                anchor,
                mode: .week,
                direction: -1,
                calendar: calendar
            ) == makeDate(year: 2026, month: 7, day: 20)
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
                for: makeDate(year: 2026, month: 7, day: 15),
                mode: .week,
                calendar: calendar
            ) == [
                makeDate(year: 2026, month: 7, day: 1)
            ]
        )

        #expect(
            DesktopCalendarLayout.monthsNeeded(
                for: makeDate(year: 2026, month: 7, day: 27),
                mode: .week,
                calendar: calendar
            ) == [
                makeDate(year: 2026, month: 7, day: 1),
                makeDate(year: 2026, month: 8, day: 1)
            ]
        )

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

    @Test("Week title names one month, a month range, or both years")
    func weekTitle() {
        var englishCalendar = calendar
        englishCalendar.locale = Locale(identifier: "en_US")

        #expect(
            DesktopCalendarLayout.title(
                for: makeDate(year: 2026, month: 7, day: 15),
                mode: .week,
                calendar: englishCalendar
            ) == DesktopCalendarTitle(leading: "July", trailing: "2026")
        )
        #expect(
            DesktopCalendarLayout.title(
                for: makeDate(year: 2026, month: 7, day: 27),
                mode: .week,
                calendar: englishCalendar
            ) == DesktopCalendarTitle(leading: "July – August", trailing: "2026")
        )
        #expect(
            DesktopCalendarLayout.title(
                for: makeDate(year: 2027, month: 1, day: 1),
                mode: .week,
                calendar: englishCalendar
            ) == DesktopCalendarTitle(
                leading: "December 2026 – January 2027",
                trailing: ""
            )
        )
    }

    @Test("Week blocks keep a one hour minimum and share overlapping columns")
    func weekBlockFrames() {
        let point = frame(id: "point", in: [
            DesktopWeekTimeSpan(id: "point", startMinute: 10 * 60 + 30, endMinute: 10 * 60 + 30)
        ])
        #expect(point?.column == 0)
        #expect(point?.columnCount == 1)
        #expect(point?.y == 10.5 * DesktopWeekCalendarLayout.hourHeight)
        #expect(point?.height == DesktopWeekCalendarLayout.hourHeight)

        let late = frame(id: "late", in: [
            DesktopWeekTimeSpan(id: "late", startMinute: 23 * 60 + 30, endMinute: 23 * 60 + 30)
        ])
        #expect(late?.height == 0.5 * DesktopWeekCalendarLayout.hourHeight)

        let spans = [
            DesktopWeekTimeSpan(id: "early", startMinute: 9 * 60, endMinute: 10 * 60),
            DesktopWeekTimeSpan(id: "next", startMinute: 10 * 60, endMinute: 11 * 60),
            DesktopWeekTimeSpan(id: "overlap", startMinute: 10 * 60 + 30, endMinute: 11 * 60 + 30)
        ]
        #expect(frame(id: "early", in: spans)?.column == 0)
        #expect(frame(id: "early", in: spans)?.columnCount == 1)
        #expect(frame(id: "next", in: spans)?.columnCount == 2)
        #expect(frame(id: "overlap", in: spans)?.columnCount == 2)
        #expect(frame(id: "next", in: spans)?.column != frame(id: "overlap", in: spans)?.column)

        let series = frame(id: "series", in: [
            DesktopWeekTimeSpan(id: "series", startMinute: 9 * 60, endMinute: 11 * 60)
        ])
        #expect(series?.height == 2 * DesktopWeekCalendarLayout.hourHeight)
    }

    @Test("Week scroll starts an hour before now, or at 7:00")
    func weekScrollOffset() {
        let now = calendar.date(
            from: DateComponents(year: 2026, month: 7, day: 27, hour: 15, minute: 30)
        )!

        #expect(
            DesktopWeekCalendarLayout.initialScrollOffset(
                now: now,
                weekContainsToday: true,
                viewportHeight: 400,
                calendar: calendar
            ) == DesktopWeekCalendarLayout.yOffset(minutes: 15 * 60 + 30)
                - DesktopWeekCalendarLayout.hourHeight
        )
        #expect(
            DesktopWeekCalendarLayout.initialScrollOffset(
                now: now,
                weekContainsToday: false,
                viewportHeight: 400,
                calendar: calendar
            ) == DesktopWeekCalendarLayout.yOffset(minutes: 7 * 60)
        )
    }

    private func frame(
        id: String,
        in spans: [DesktopWeekTimeSpan]
    ) -> DesktopWeekTimeFrame? {
        DesktopWeekCalendarLayout.frames(for: spans).first { $0.id == id }
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
