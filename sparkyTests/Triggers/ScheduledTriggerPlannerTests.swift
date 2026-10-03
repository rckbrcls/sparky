import Foundation
import Testing
@testable import sparky

@MainActor
@Suite("Scheduled trigger plans")
struct ScheduledTriggerPlannerTests {
    private var calendar: Calendar { TriggerTestSupport.calendar }
    private var fire: Date { TriggerTestSupport.fire }
    private var now: Date { TriggerTestSupport.now }

    @Test func oneTimeFutureSchedulesASingleNonRepeatingRequest() {
        let schedule = TriggerTestSupport.schedule(fireDate: fire)
        let memory = TriggerTestSupport.memory(schedule: schedule)
        let plans = ScheduledTriggerPlanner.plans(for: memory, now: now, calendar: calendar)

        #expect(plans.count == 1)
        let plan = plans[0]
        #expect(plan.repeats == false)
        #expect(plan.identifier == baseIdentifier(memory: memory, schedule: schedule))
        #expect(calendar.date(from: plan.dateComponents) == TriggerTestSupport.minute(fire))
        #expect(plan.title == memory.title)
        #expect(plan.body == memory.body)
        #expect(plan.memoryID == memory.id)
        #expect(plan.focusEnabled == false)
        #expect(plan.categoryIdentifier == NotificationCategoryID.reminderActions)
    }

    @Test func oneTimePastOrPresentSchedulesNothing() {
        let past = TriggerTestSupport.schedule(fireDate: TriggerTestSupport.adding(.day, -1, to: now))
        let present = TriggerTestSupport.schedule(fireDate: now)
        let missing = TriggerTestSupport.schedule(fireDate: nil)

        #expect(ScheduledTriggerPlanner.plans(for: TriggerTestSupport.memory(schedule: past), now: now, calendar: calendar).isEmpty)
        #expect(ScheduledTriggerPlanner.plans(for: TriggerTestSupport.memory(schedule: present), now: now, calendar: calendar).isEmpty)
        #expect(ScheduledTriggerPlanner.plans(for: TriggerTestSupport.memory(schedule: missing), now: now, calendar: calendar).isEmpty)
    }

    @Test func completedMemoryOrInactiveScheduleSchedulesNothing() {
        let schedule = TriggerTestSupport.schedule(fireDate: fire)
        let completed = TriggerTestSupport.memory(status: .completed, schedule: schedule)
        let inactive = TriggerTestSupport.schedule(fireDate: fire, isActive: false)

        #expect(ScheduledTriggerPlanner.plans(for: completed, now: now, calendar: calendar).isEmpty)
        #expect(ScheduledTriggerPlanner.plans(for: TriggerTestSupport.memory(schedule: inactive), now: now, calendar: calendar).isEmpty)

        let active = TriggerTestSupport.memory(title: "Active", schedule: TriggerTestSupport.schedule(fireDate: fire))
        let listed = ScheduledTriggerPlanner.plans(
            for: [completed, active],
            now: now,
            calendar: calendar
        )
        #expect(listed.map(\.memoryID) == [active.id])
    }

    @Test func emptyBodyIsOmitted() {
        let memory = TriggerTestSupport.memory(
            body: "",
            schedule: TriggerTestSupport.schedule(fireDate: fire)
        )
        let plans = ScheduledTriggerPlanner.plans(for: memory, now: now, calendar: calendar)
        #expect(plans.first?.body == nil)
    }

    @Test func unboundedWeekdayMaskRepeatsEachSelectedDay() {
        // A weekday mask wins over an unbounded recurrence. The series repeats on the clock.
        let schedule = TriggerTestSupport.schedule(
            fireDate: fire,
            recurrence: RecurrenceRule(frequency: .daily, interval: 1),
            weekdayMask: TriggerTestSupport.weekdayMask(2, 6)
        )
        let memory = TriggerTestSupport.memory(schedule: schedule)
        let plans = ScheduledTriggerPlanner.plans(for: memory, now: now, calendar: calendar)
        let base = baseIdentifier(memory: memory, schedule: schedule)

        #expect(plans.map(\.identifier) == ["\(base)-wd2", "\(base)-wd6"])
        #expect(plans.allSatisfy { $0.repeats })
        #expect(plans.map(\.dateComponents.weekday) == [2, 6])
        #expect(plans.allSatisfy { $0.dateComponents.hour == 9 && $0.dateComponents.minute == 30 })
        #expect(plans.allSatisfy { $0.dateComponents.year == nil && $0.dateComponents.day == nil })
    }

    @Test func boundedWeekdayMaskSchedulesConcreteOccurrencesUntilTheEnd() {
        let end = TriggerTestSupport.date(2026, 10, 10)
        let schedule = TriggerTestSupport.schedule(
            fireDate: fire,
            recurrence: RecurrenceRule(frequency: .daily, interval: 1, endDate: end),
            weekdayMask: TriggerTestSupport.weekdayMask(2, 6)
        )
        let memory = TriggerTestSupport.memory(schedule: schedule)
        let plans = ScheduledTriggerPlanner.plans(for: memory, now: now, calendar: calendar)
        let base = baseIdentifier(memory: memory, schedule: schedule)

        #expect(plans.map(\.identifier) == ["\(base)-occ0", "\(base)-occ1"])
        #expect(plans.allSatisfy { $0.repeats == false })
        #expect(plans.map { calendar.date(from: $0.dateComponents) } == [
            TriggerTestSupport.minute(fire),
            TriggerTestSupport.minute(TriggerTestSupport.date(2026, 10, 9, 9, 30, 15))
        ])
    }

    @Test func minutelyAndHourlyIntervalOfOneRepeatOnTheClock() {
        let minutely = plans(recurrence: RecurrenceRule(frequency: .minutely, interval: 1))
        #expect(minutely.count == 1)
        #expect(minutely[0].repeats)
        #expect(minutely[0].dateComponents.second == 15)
        #expect(minutely[0].dateComponents.minute == nil)
        #expect(minutely[0].dateComponents.hour == nil)

        let hourly = plans(recurrence: RecurrenceRule(frequency: .hourly, interval: 1))
        #expect(hourly.count == 1)
        #expect(hourly[0].repeats)
        #expect(hourly[0].dateComponents.minute == 30)
        #expect(hourly[0].dateComponents.second == nil)
        #expect(hourly[0].dateComponents.hour == nil)
    }

    @Test func boundedMinutelyUsesConcreteOccurrencesInsteadOfARepeatingClock() {
        let plans = plans(recurrence: RecurrenceRule(frequency: .minutely, interval: 1, occurrenceCount: 4))

        #expect(plans.count == 4)
        #expect(plans.allSatisfy { $0.repeats == false })
        #expect(plans.enumerated().allSatisfy { $0.element.identifier.hasSuffix("-occ\($0.offset)") })
        #expect(plans.map { calendar.component(.minute, from: calendar.date(from: $0.dateComponents)!) } == [30, 31, 32, 33])
    }

    @Test(arguments: [RecurrenceFrequency.daily, .weekly, .monthly, .yearly])
    func intervalOfOneUsesARepeatingCalendarTrigger(frequency: RecurrenceFrequency) {
        let plans = plans(recurrence: RecurrenceRule(frequency: frequency, interval: 1))
        #expect(plans.count == 1)
        let plan = plans[0]
        #expect(plan.repeats)
        #expect(plan.identifier.hasPrefix("memory-"))
        #expect(!plan.identifier.contains("-occ"))
        #expect(!plan.identifier.contains("-wd"))
        #expect(plan.dateComponents.hour == 9)
        #expect(plan.dateComponents.minute == 30)

        switch frequency {
        case .daily:
            #expect(plan.dateComponents.weekday == nil)
            #expect(plan.dateComponents.day == nil)
            #expect(plan.dateComponents.month == nil)
        case .weekly:
            #expect(plan.dateComponents.weekday == 2)
            #expect(plan.dateComponents.day == nil)
        case .monthly:
            #expect(plan.dateComponents.day == 5)
            #expect(plan.dateComponents.weekday == nil)
            #expect(plan.dateComponents.month == nil)
        case .yearly:
            #expect(plan.dateComponents.month == 10)
            #expect(plan.dateComponents.day == 5)
            #expect(plan.dateComponents.weekday == nil)
        default:
            Issue.record("Unexpected frequency \(frequency.rawValue)")
        }
    }

    @Test func openEndedIntervalAboveOneSchedulesFiveFutureOccurrences() {
        let daily = plans(recurrence: RecurrenceRule(frequency: .daily, interval: 2))
        #expect(daily.count == ScheduledTriggerPlanner.maxFutureOccurrences)
        #expect(daily.allSatisfy { $0.repeats == false })
        #expect(daily.map { calendar.date(from: $0.dateComponents) } == (0..<5).map {
            TriggerTestSupport.minute(TriggerTestSupport.adding(.day, $0 * 2, to: fire))
        })

        let hourly = plans(recurrence: RecurrenceRule(frequency: .hourly, interval: 2))
        #expect(hourly.count == 5)
        #expect(hourly.map { calendar.date(from: $0.dateComponents) } == (0..<5).map {
            TriggerTestSupport.minute(TriggerTestSupport.adding(.hour, $0 * 2, to: fire))
        })

        let minutely = plans(recurrence: RecurrenceRule(frequency: .minutely, interval: 4))
        #expect(minutely.count == 5)
        #expect(minutely.map { calendar.component(.minute, from: calendar.date(from: $0.dateComponents)!) } == [30, 34, 38, 42, 46])
    }

    @Test func boundedSeriesStopsAtTheEndAndCapsAtFortyEight() {
        let short = plans(recurrence: RecurrenceRule(frequency: .daily, interval: 1, occurrenceCount: 3))
        #expect(short.count == 3)
        #expect(short.allSatisfy { $0.repeats == false })
        #expect(short.enumerated().allSatisfy { $0.element.identifier.hasSuffix("-occ\($0.offset)") })
        #expect(calendar.date(from: short.last!.dateComponents) == TriggerTestSupport.minute(TriggerTestSupport.adding(.day, 2, to: fire)))

        let until = plans(
            recurrence: RecurrenceRule(
                frequency: .daily,
                interval: 1,
                endDate: TriggerTestSupport.adding(.day, 2, to: fire)
            )
        )
        #expect(until.count == 3)

        let endedBeforeStart = plans(
            recurrence: RecurrenceRule(
                frequency: .daily,
                interval: 1,
                endDate: TriggerTestSupport.adding(.day, -1, to: fire)
            )
        )
        #expect(endedBeforeStart.isEmpty)

        let long = plans(recurrence: RecurrenceRule(frequency: .daily, interval: 1, occurrenceCount: 100))
        #expect(long.count == ScheduledTriggerPlanner.maxBoundedOccurrences)
        #expect(long.first?.identifier.hasSuffix("-occ0") == true)
        #expect(long.last?.identifier.hasSuffix("-occ47") == true)
        #expect(
            calendar.date(from: long.last!.dateComponents)
                == TriggerTestSupport.minute(TriggerTestSupport.adding(.day, 47, to: fire))
        )
    }

    @Test func focusSelectsTheFocusCategory() {
        let schedule = TriggerTestSupport.schedule(fireDate: fire, focusEnabled: true)
        let plans = ScheduledTriggerPlanner.plans(
            for: TriggerTestSupport.memory(schedule: schedule),
            now: now,
            calendar: calendar
        )

        #expect(plans.first?.focusEnabled == true)
        #expect(plans.first?.categoryIdentifier == NotificationCategoryID.scheduleFocusActions)
    }

    private func plans(recurrence: RecurrenceRule) -> [ScheduledNotificationPlan] {
        let schedule = TriggerTestSupport.schedule(fireDate: fire, recurrence: recurrence)
        let memory = TriggerTestSupport.memory(schedule: schedule)
        return ScheduledTriggerPlanner.plans(for: memory, now: now, calendar: calendar)
    }

    private func baseIdentifier(memory: Memory, schedule: ScheduleConfig) -> String {
        "memory-\(memory.id.uuidString)-\(schedule.id.uuidString)"
    }
}
