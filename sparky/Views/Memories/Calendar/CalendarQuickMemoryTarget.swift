//
//  CalendarQuickMemoryTarget.swift
//  sparky
//
//  Context for creating a scheduled memory from an empty calendar period.
//

import Foundation

struct CalendarQuickMemoryTarget {
    let date: Date
    let period: CalendarTimePeriod

    init(date: Date, period: CalendarTimePeriod) {
        self.date = date
        self.period = period
    }

    init(allDay date: Date, calendar: Calendar = .current) {
        self.date = calendar.startOfDay(for: date)
        self.period = .allDay
    }

    var isAllDay: Bool {
        period == .allDay
    }

    func suggestedDate(calendar: Calendar = .current) -> Date {
        let dayStart = calendar.startOfDay(for: date)
        guard let hour = period.suggestedHour else {
            return dayStart
        }

        return calendar.date(
            bySettingHour: hour,
            minute: 0,
            second: 0,
            of: dayStart
        ) ?? dayStart
    }

    func scheduleDraft(calendar: Calendar = .current) -> ScheduleConfigDraft {
        let fireDate = isAllDay
            ? calendar.startOfDay(for: date)
            : suggestedDate(calendar: calendar)

        return ScheduleConfigDraft(
            fireDate: fireDate,
            startDate: fireDate,
            timeZoneIdentifier: calendar.timeZone.identifier,
            isActive: true,
            isAllDay: isAllDay
        )
    }
}
