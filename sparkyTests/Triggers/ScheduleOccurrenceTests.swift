import Foundation
import Testing
@testable import sparky

@MainActor
@Suite("Schedule occurrence calculations")
struct ScheduleOccurrenceTests {
    private var calendar: Calendar { TriggerTestSupport.calendar }

    @Test func nextFireDateBeforeTheStartReturnsTheFirstFire() {
        let fire = TriggerTestSupport.fire
        let schedule = TriggerTestSupport.schedule(
            fireDate: fire,
            recurrence: RecurrenceRule(frequency: .daily, interval: 2, occurrenceCount: 4)
        )

        #expect(schedule.nextFireDate(after: TriggerTestSupport.now, calendar: calendar) == fire)
    }

    @Test func nextFireDateAfterTheSeriesEndIsEmpty() {
        let fire = TriggerTestSupport.fire
        let rule = RecurrenceRule(frequency: .daily, interval: 2, occurrenceCount: 4)
        let schedule = TriggerTestSupport.schedule(fireDate: fire, recurrence: rule)
        let end = schedule.effectiveEndDate(fireDate: fire, recurrence: rule, calendar: calendar)!

        #expect(schedule.nextFireDate(after: end.addingTimeInterval(1), calendar: calendar) == nil)
    }

    @Test func oneShotNextFireDateIncludesTheExactInstantAndDropsThePast() {
        let fire = TriggerTestSupport.fire
        let schedule = TriggerTestSupport.schedule(fireDate: fire)

        #expect(schedule.nextFireDate(after: fire, calendar: calendar) == fire)
        #expect(schedule.nextFireDate(after: fire.addingTimeInterval(1), calendar: calendar) == nil)
    }

    @Test func occurrenceCountDefinesTheEndAndWinsOverAnEarlierEndDate() {
        let fire = TriggerTestSupport.fire
        let earlierEnd = TriggerTestSupport.adding(.day, 1, to: fire)
        let rule = RecurrenceRule(
            frequency: .daily,
            interval: 2,
            endDate: earlierEnd,
            occurrenceCount: 4
        )
        let schedule = TriggerTestSupport.schedule(fireDate: fire, recurrence: rule)
        let countEnd = TriggerTestSupport.adding(.day, (4 - 1) * 2, to: fire)

        // Count is applied before endDate. An earlier end date does not shorten the series.
        #expect(schedule.effectiveEndDate(fireDate: fire, recurrence: rule, calendar: calendar) == countEnd)

        let dates = schedule.dates(
            from: fire,
            to: TriggerTestSupport.adding(.day, 30, to: fire),
            calendar: calendar
        )
        #expect(dates == [0, 2, 4, 6].map { TriggerTestSupport.adding(.day, $0, to: fire) })
    }

    @Test func datesStopAtAnEndDateAndStayInsideTheRequestedRange() {
        let fire = TriggerTestSupport.fire
        let end = TriggerTestSupport.adding(.day, 2, to: fire)
        let schedule = TriggerTestSupport.schedule(
            fireDate: fire,
            recurrence: RecurrenceRule(frequency: .daily, interval: 1, endDate: end)
        )

        let dates = schedule.dates(
            from: fire,
            to: TriggerTestSupport.adding(.day, 10, to: fire),
            calendar: calendar
        )
        #expect(dates == [0, 1, 2].map { TriggerTestSupport.adding(.day, $0, to: fire) })

        let afterEnd = schedule.dates(
            from: end.addingTimeInterval(1),
            to: TriggerTestSupport.adding(.day, 10, to: fire),
            calendar: calendar
        )
        #expect(afterEnd.isEmpty)
    }

    @Test func oneShotAndStartDateQueriesRespectTheRange() {
        let fire = TriggerTestSupport.fire
        let oneShot = TriggerTestSupport.schedule(fireDate: fire)
        #expect(oneShot.dates(from: TriggerTestSupport.now, to: TriggerTestSupport.adding(.day, 2, to: fire), calendar: calendar) == [fire])
        #expect(oneShot.dates(from: fire.addingTimeInterval(1), to: TriggerTestSupport.adding(.day, 2, to: fire), calendar: calendar).isEmpty)

        let startOnly = ScheduleConfig(startDate: fire, timeZoneIdentifier: calendar.timeZone.identifier)
        #expect(startOnly.dates(from: TriggerTestSupport.now, to: TriggerTestSupport.adding(.hour, 1, to: fire), calendar: calendar) == [fire])
    }

    @Test func weekdayDatesMatchTheMask() {
        let fire = TriggerTestSupport.fire
        #expect(calendar.component(.weekday, from: fire) == 2)
        let schedule = TriggerTestSupport.schedule(
            fireDate: fire,
            weekdayMask: TriggerTestSupport.weekdayMask(2, 6)
        )
        let rangeEnd = TriggerTestSupport.date(2026, 10, 12)

        let dates = schedule.dates(from: TriggerTestSupport.now, to: rangeEnd, calendar: calendar)
        #expect(dates.map { calendar.component(.weekday, from: $0) } == [2, 6])
        #expect(dates.allSatisfy { calendar.component(.hour, from: $0) == 9 && calendar.component(.minute, from: $0) == 30 })
    }

    @Test func nextWeekdaySkipsATimeThatAlreadyPassed() {
        let fire = TriggerTestSupport.fire
        let schedule = TriggerTestSupport.schedule(
            fireDate: fire,
            weekdayMask: TriggerTestSupport.weekdayMask(2, 6)
        )

        #expect(
            schedule.nextFireDate(after: fire.addingTimeInterval(1), calendar: calendar)
                == TriggerTestSupport.date(2026, 10, 9, 9, 30, 15)
        )
    }

    @Test func eachFrequencyAdvancesByItsInterval() {
        let fire = TriggerTestSupport.fire
        let cases: [(RecurrenceFrequency, Int, Calendar.Component, Int, Calendar.Component, Int)] = [
            (.minutely, 5, .minute, 1, .minute, 5),
            (.hourly, 2, .hour, 1, .hour, 2),
            (.daily, 2, .day, 1, .day, 2),
            (.weekly, 2, .weekOfYear, 1, .weekOfYear, 2),
            (.monthly, 1, .day, 1, .month, 1),
            (.yearly, 1, .day, 1, .year, 1)
        ]

        for (frequency, interval, referenceComponent, referenceValue, expectedComponent, expectedValue) in cases {
            let schedule = TriggerTestSupport.schedule(
                fireDate: fire,
                recurrence: RecurrenceRule(frequency: frequency, interval: interval)
            )
            let reference = TriggerTestSupport.adding(referenceComponent, referenceValue, to: fire)
            let expected = TriggerTestSupport.adding(expectedComponent, expectedValue, to: fire)
            #expect(
                schedule.nextFireDate(after: reference, calendar: calendar) == expected,
                "\(frequency.rawValue) interval \(interval)"
            )
        }

        // A reference that lands on an occurrence moves to the following one.
        let aligned = TriggerTestSupport.schedule(
            fireDate: fire,
            recurrence: RecurrenceRule(frequency: .minutely, interval: 5)
        )
        #expect(
            aligned.nextFireDate(after: TriggerTestSupport.adding(.minute, 5, to: fire), calendar: calendar)
                == TriggerTestSupport.adding(.minute, 10, to: fire)
        )
    }
}
