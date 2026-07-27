//
//  CalendarQuickMemoryTargetTests.swift
//  sparkyTests
//

import Foundation
import Testing
@testable import sparky

@MainActor
@Suite("Calendar quick memory context")
struct CalendarQuickMemoryTargetTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    @Test("Time periods retain their boundary hours")
    func timePeriodBoundaries() {
        #expect(CalendarTimePeriod.period(containingHour: 0) == .night)
        #expect(CalendarTimePeriod.period(containingHour: 5) == .night)
        #expect(CalendarTimePeriod.period(containingHour: 6) == .morning)
        #expect(CalendarTimePeriod.period(containingHour: 11) == .morning)
        #expect(CalendarTimePeriod.period(containingHour: 12) == .afternoon)
        #expect(CalendarTimePeriod.period(containingHour: 17) == .afternoon)
        #expect(CalendarTimePeriod.period(containingHour: 18) == .evening)
        #expect(CalendarTimePeriod.period(containingHour: 21) == .evening)
        #expect(CalendarTimePeriod.period(containingHour: 22) == .night)
        #expect(CalendarTimePeriod.period(containingHour: 23) == .night)
    }

    @Test("Each period resolves its confirmed suggested time")
    func suggestedTimes() {
        let targetDate = makeDate(year: 2026, month: 7, day: 27, hour: 12)
        let expectedHours: [(CalendarTimePeriod, Int)] = [
            (.morning, 9),
            (.afternoon, 14),
            (.evening, 19),
            (.night, 22)
        ]

        for (period, expectedHour) in expectedHours {
            let target = CalendarQuickMemoryTarget(date: targetDate, period: period)
            let suggestedDate = target.suggestedDate(calendar: calendar)

            #expect(calendar.component(.year, from: suggestedDate) == 2026)
            #expect(calendar.component(.month, from: suggestedDate) == 7)
            #expect(calendar.component(.day, from: suggestedDate) == 27)
            #expect(calendar.component(.hour, from: suggestedDate) == expectedHour)
            #expect(calendar.component(.minute, from: suggestedDate) == 0)
        }
    }

    @Test("All-day context creates a non-recurring active all-day schedule")
    func allDaySchedule() {
        let target = CalendarQuickMemoryTarget(
            date: makeDate(year: 2026, month: 7, day: 27, hour: 18),
            period: .allDay
        )
        let draft = target.scheduleDraft(calendar: calendar)

        #expect(draft.isActive)
        #expect(draft.isAllDay)
        #expect(draft.recurrenceRule == nil)
        #expect(draft.weekdayMask == 0)
        #expect(draft.timeZoneIdentifier == calendar.timeZone.identifier)
        #expect(draft.fireDate == makeDate(year: 2026, month: 7, day: 27))
        #expect(draft.startDate == draft.fireDate)
    }

    @Test("Timed context creates a non-recurring active schedule in the calendar time zone")
    func timedSchedule() {
        let target = CalendarQuickMemoryTarget(
            date: makeDate(year: 2026, month: 7, day: 27, hour: 7),
            period: .evening
        )
        let draft = target.scheduleDraft(calendar: calendar)

        #expect(draft.isActive)
        #expect(!draft.isAllDay)
        #expect(draft.recurrenceRule == nil)
        #expect(draft.weekdayMask == 0)
        #expect(draft.timeZoneIdentifier == calendar.timeZone.identifier)
        #expect(draft.fireDate == makeDate(year: 2026, month: 7, day: 27, hour: 19))
        #expect(draft.startDate == draft.fireDate)
    }

    @Test("Desktop all-day target retains the selected day")
    func exactAllDayTarget() {
        let target = CalendarQuickMemoryTarget(
            allDay: makeDate(year: 2026, month: 7, day: 27, hour: 18),
            calendar: calendar
        )
        let draft = target.scheduleDraft(calendar: calendar)

        #expect(target.isAllDay)
        #expect(target.period == .allDay)
        #expect(draft.fireDate == makeDate(year: 2026, month: 7, day: 27))
        #expect(draft.isAllDay)
    }

    @Test("Desktop timed target retains its exact hour and minute")
    func exactTimedTarget() {
        let scheduledDate = makeDate(
            year: 2026,
            month: 7,
            day: 27,
            hour: 10,
            minute: 35
        )
        let target = CalendarQuickMemoryTarget(
            scheduledDate: scheduledDate,
            calendar: calendar
        )
        let draft = target.scheduleDraft(calendar: calendar)

        #expect(!target.isAllDay)
        #expect(target.period == .morning)
        #expect(target.suggestedDate(calendar: calendar) == scheduledDate)
        #expect(draft.fireDate == scheduledDate)
        #expect(!draft.isAllDay)
    }

    @Test("Initial calendar schedule overrides the editor template")
    func initialScheduleOverridesTemplate() {
        let environment = AppEnvironment(dataController: DataController(inMemory: true))
        let target = CalendarQuickMemoryTarget(
            date: makeDate(year: 2026, month: 7, day: 27),
            period: .morning
        )
        let initialSchedule = target.scheduleDraft(calendar: calendar)
        let viewModel = MemoryEditorViewModel(
            environment: environment,
            attachmentStore: environment.attachmentStore,
            memory: nil,
            defaultMind: nil,
            template: .quickReminder,
            initialTitle: "Contextual memory",
            initialScheduleConfig: initialSchedule
        )

        #expect(viewModel.title == "Contextual memory")
        #expect(viewModel.scheduleConfigDraft?.fireDate == initialSchedule.fireDate)
        #expect(viewModel.scheduleConfigDraft?.isAllDay == false)
        #expect(viewModel.scheduleConfigDraft?.recurrenceRule == nil)
    }

    private func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 0,
        minute: Int = 0
    ) -> Date {
        calendar.date(
            from: DateComponents(
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute
            )
        )!
    }
}
