//
//  ScheduledTriggerPlanner.swift
//  sparky
//
//  Decides which local notifications a schedule should arm.
//  The executor turns these plans into UNNotificationRequest values.
//

import Foundation

struct ScheduledNotificationPlan: Equatable {
    let identifier: String
    let dateComponents: DateComponents
    let repeats: Bool
    let title: String
    let body: String?
    let categoryIdentifier: String
    let memoryID: UUID
    let focusEnabled: Bool
}

enum ScheduledTriggerPlanner {
    /// Upcoming occurrences kept pending for an open-ended interval greater than 1.
    static let maxFutureOccurrences = 5

    /// Upcoming occurrences kept pending when the series has an end date or a count.
    static let maxBoundedOccurrences = 48

    static func plans(for memories: [Memory], now: Date, calendar: Calendar) -> [ScheduledNotificationPlan] {
        memories.flatMap { plans(for: $0, now: now, calendar: calendar) }
    }

    static func plans(for memory: Memory, now: Date, calendar: Calendar) -> [ScheduledNotificationPlan] {
        guard memory.status == .active,
              let config = memory.scheduleConfig,
              config.isActive else {
            return []
        }

        guard let fireDate = config.fireDate else { return [] }

        let content = content(for: memory, focusEnabled: config.focusEnabled)
        var requests: [ScheduledNotificationPlan] = []
        schedule(
            config: config,
            fireDate: fireDate,
            memoryID: memory.id,
            content: content,
            now: now,
            calendar: calendar,
            requests: &requests
        )
        return requests
    }

    static func identifier(memoryID: UUID, triggerID: UUID) -> String {
        "memory-\(memoryID.uuidString)-\(triggerID.uuidString)"
    }

    // MARK: - Scheduling

    private struct Content {
        let title: String
        let body: String?
        let categoryIdentifier: String
        let memoryID: UUID
        let focusEnabled: Bool
    }

    private static func content(for memory: Memory, focusEnabled: Bool) -> Content {
        let body = memory.body.flatMap { $0.isEmpty ? nil : $0 }
        return Content(
            title: memory.title,
            body: body,
            categoryIdentifier: focusEnabled
                ? NotificationCategoryID.scheduleFocusActions
                : NotificationCategoryID.reminderActions,
            memoryID: memory.id,
            focusEnabled: focusEnabled
        )
    }

    private static func schedule(
        config: ScheduleConfig,
        fireDate: Date,
        memoryID: UUID,
        content: Content,
        now: Date,
        calendar: Calendar,
        requests: inout [ScheduledNotificationPlan]
    ) {
        if config.weekdayMask != 0 {
            if let recurrence = config.recurrenceRule, isBounded(recurrence) {
                scheduleFutureOccurrences(
                    config: config,
                    recurrence: recurrence,
                    baseIdentifier: identifier(memoryID: memoryID, triggerID: config.id),
                    content: content,
                    now: now,
                    calendar: calendar,
                    limit: maxBoundedOccurrences,
                    requests: &requests
                )
            } else {
                scheduleWeekday(
                    config: config,
                    fireDate: fireDate,
                    memoryID: memoryID,
                    content: content,
                    calendar: calendar,
                    requests: &requests
                )
            }
        } else if let recurrence = config.recurrenceRule {
            scheduleRecurring(
                config: config,
                recurrence: recurrence,
                fireDate: fireDate,
                memoryID: memoryID,
                content: content,
                now: now,
                calendar: calendar,
                requests: &requests
            )
        } else {
            scheduleOneTime(
                config: config,
                fireDate: fireDate,
                memoryID: memoryID,
                content: content,
                now: now,
                calendar: calendar,
                requests: &requests
            )
        }
    }

    private static func scheduleWeekday(
        config: ScheduleConfig,
        fireDate: Date,
        memoryID: UUID,
        content: Content,
        calendar: Calendar,
        requests: inout [ScheduledNotificationPlan]
    ) {
        let timeComponents = calendar.dateComponents([.hour, .minute], from: fireDate)

        for day in 1...7 {
            let bit = Int16(1 << day)
            guard config.weekdayMask & bit != 0 else { continue }

            var components = DateComponents()
            components.weekday = day
            components.hour = timeComponents.hour
            components.minute = timeComponents.minute
            requests.append(
                plan(
                    identifier: identifier(memoryID: memoryID, triggerID: config.id) + "-wd\(day)",
                    dateComponents: components,
                    repeats: true,
                    content: content
                )
            )
        }
    }

    private static func scheduleRecurring(
        config: ScheduleConfig,
        recurrence: RecurrenceRule,
        fireDate: Date,
        memoryID: UUID,
        content: Content,
        now: Date,
        calendar: Calendar,
        requests: inout [ScheduledNotificationPlan]
    ) {
        let baseIdentifier = identifier(memoryID: memoryID, triggerID: config.id)
        let interval = recurrence.interval

        // A repeating system trigger cannot stop on a date or a count.
        if isBounded(recurrence) {
            scheduleFutureOccurrences(
                config: config,
                recurrence: recurrence,
                baseIdentifier: baseIdentifier,
                content: content,
                now: now,
                calendar: calendar,
                limit: maxBoundedOccurrences,
                requests: &requests
            )
            return
        }

        // Minutely / hourly interval of 1 repeats on the clock, not on a countdown
        // from the last sync. A time-interval trigger restarts whenever triggers
        // are resynced, so an open app can postpone the reminder forever.
        switch recurrence.frequency {
        case .minutely where interval == 1:
            var components = DateComponents()
            components.second = calendar.component(.second, from: fireDate)
            requests.append(
                plan(
                    identifier: baseIdentifier,
                    dateComponents: components,
                    repeats: true,
                    content: content
                )
            )
            return

        case .hourly where interval == 1:
            var components = DateComponents()
            components.minute = calendar.component(.minute, from: fireDate)
            requests.append(
                plan(
                    identifier: baseIdentifier,
                    dateComponents: components,
                    repeats: true,
                    content: content
                )
            )
            return

        case .minutely, .hourly:
            scheduleFutureOccurrences(
                config: config,
                recurrence: recurrence,
                baseIdentifier: baseIdentifier,
                content: content,
                now: now,
                calendar: calendar,
                limit: maxFutureOccurrences,
                requests: &requests
            )
            return

        default:
            break
        }

        if interval == 1 {
            let components = calendarComponents(for: recurrence.frequency, from: fireDate, calendar: calendar)
            requests.append(
                plan(
                    identifier: baseIdentifier,
                    dateComponents: components,
                    repeats: true,
                    content: content
                )
            )
        } else {
            scheduleFutureOccurrences(
                config: config,
                recurrence: recurrence,
                baseIdentifier: baseIdentifier,
                content: content,
                now: now,
                calendar: calendar,
                limit: maxFutureOccurrences,
                requests: &requests
            )
        }
    }

    private static func isBounded(_ recurrence: RecurrenceRule) -> Bool {
        if recurrence.endDate != nil { return true }
        if let count = recurrence.occurrenceCount, count > 0 { return true }
        return false
    }

    private static func scheduleOneTime(
        config: ScheduleConfig,
        fireDate: Date,
        memoryID: UUID,
        content: Content,
        now: Date,
        calendar: Calendar,
        requests: inout [ScheduledNotificationPlan]
    ) {
        guard fireDate > now else { return }

        let dateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        requests.append(
            plan(
                identifier: identifier(memoryID: memoryID, triggerID: config.id),
                dateComponents: dateComponents,
                repeats: false,
                content: content
            )
        )
    }

    private static func calendarComponents(
        for frequency: RecurrenceFrequency,
        from date: Date,
        calendar: Calendar
    ) -> DateComponents {
        var components = DateComponents()
        let time = calendar.dateComponents([.hour, .minute], from: date)

        switch frequency {
        case .daily:
            components.hour = time.hour
            components.minute = time.minute

        case .weekly:
            components.weekday = calendar.component(.weekday, from: date)
            components.hour = time.hour
            components.minute = time.minute

        case .monthly:
            components.day = calendar.component(.day, from: date)
            components.hour = time.hour
            components.minute = time.minute

        case .yearly:
            components.month = calendar.component(.month, from: date)
            components.day = calendar.component(.day, from: date)
            components.hour = time.hour
            components.minute = time.minute

        case .minutely, .hourly:
            components.hour = time.hour
            components.minute = time.minute
        }

        return components
    }

    private static func scheduleFutureOccurrences(
        config: ScheduleConfig,
        recurrence: RecurrenceRule,
        baseIdentifier: String,
        content: Content,
        now: Date,
        calendar: Calendar,
        limit: Int,
        requests: inout [ScheduledNotificationPlan]
    ) {
        var reference = now
        var scheduled = 0
        var attempts = 0

        let effectiveEnd: Date? = {
            if let fireDate = config.fireDate {
                return config.effectiveEndDate(fireDate: fireDate, recurrence: recurrence, calendar: calendar)
            }
            return recurrence.endDate
        }()

        while scheduled < limit && attempts < limit * 8 {
            attempts += 1
            guard let nextDate = config.nextFireDate(after: reference, calendar: calendar) else { break }
            if let effectiveEnd, nextDate > effectiveEnd { break }

            if nextDate <= now {
                let start = calendar.startOfDay(for: max(nextDate, reference))
                reference = calendar.date(byAdding: .day, value: 1, to: start)
                    ?? reference.addingTimeInterval(86_400)
                continue
            }

            let dateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: nextDate)
            requests.append(
                plan(
                    identifier: "\(baseIdentifier)-occ\(scheduled)",
                    dateComponents: dateComponents,
                    repeats: false,
                    content: content
                )
            )
            scheduled += 1
            reference = nextDate.addingTimeInterval(1)
        }
    }

    private static func plan(
        identifier: String,
        dateComponents: DateComponents,
        repeats: Bool,
        content: Content
    ) -> ScheduledNotificationPlan {
        ScheduledNotificationPlan(
            identifier: identifier,
            dateComponents: dateComponents,
            repeats: repeats,
            title: content.title,
            body: content.body,
            categoryIdentifier: content.categoryIdentifier,
            memoryID: content.memoryID,
            focusEnabled: content.focusEnabled
        )
    }
}
