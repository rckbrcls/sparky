//
//  ScheduleConfig.swift
//  sparky
//
//  Schedule configuration for memory reminders.
//

import Foundation
import SwiftData

@Model
final class ScheduleConfig: Identifiable {
    @Attribute(.unique) var id: UUID = UUID()
    var fireDate: Date?
    var startDate: Date?
    var recurrenceFrequencyRaw: String?
    var recurrenceInterval: Int = 1
    var recurrenceEndDate: Date?
    var timeZoneIdentifier: String?
    var weekdayMask: Int16 = 0
    var isActive: Bool = true
    var isAllDay: Bool = false
    var recurrenceOccurrenceCount: Int?
    var recurrenceEndTypeRaw: String = RecurrenceEndType.never.rawValue

    // Focus (pomodoro) — schedule-only
    var focusEnabled: Bool = false
    /// Zero means no concrete Focus recipe is configured.
    var focusWorkDurationMinutes: Int = 0
    var focusShortBreakDurationMinutes: Int = 0
    var focusLongBreakDurationMinutes: Int = 0
    var focusPomodorosUntilLongBreak: Int = 0
    var focusAutoContinue: Bool = true

    var memory: Memory?

    init(
        id: UUID = UUID(),
        fireDate: Date? = nil,
        startDate: Date? = nil,
        recurrenceRule: RecurrenceRule? = nil,
        timeZoneIdentifier: String? = nil,
        weekdayMask: Int16 = 0,
        isActive: Bool = true,
        isAllDay: Bool = false,
        recurrenceEndType: RecurrenceEndType = .never,
        focusEnabled: Bool = false,
        focusWorkDurationMinutes: Int = 0,
        focusShortBreakDurationMinutes: Int = 0,
        focusLongBreakDurationMinutes: Int = 0,
        focusPomodorosUntilLongBreak: Int = 0,
        focusAutoContinue: Bool = true,
        memory: Memory? = nil
    ) {
        self.id = id
        self.fireDate = fireDate
        self.startDate = startDate
        self.recurrenceFrequencyRaw = recurrenceRule?.frequency.rawValue
        self.recurrenceInterval = recurrenceRule?.interval ?? 1
        self.recurrenceEndDate = recurrenceRule?.endDate
        self.recurrenceOccurrenceCount = recurrenceRule?.occurrenceCount
        self.recurrenceEndTypeRaw = recurrenceEndType.rawValue
        self.timeZoneIdentifier = timeZoneIdentifier
        self.weekdayMask = weekdayMask
        self.isActive = isActive
        self.isAllDay = isAllDay
        self.focusEnabled = focusEnabled
        self.focusWorkDurationMinutes = focusWorkDurationMinutes
        self.focusShortBreakDurationMinutes = focusShortBreakDurationMinutes
        self.focusLongBreakDurationMinutes = focusLongBreakDurationMinutes
        self.focusPomodorosUntilLongBreak = focusPomodorosUntilLongBreak
        self.focusAutoContinue = focusAutoContinue
        self.memory = memory
    }
}

// MARK: - Computed Properties

extension ScheduleConfig {
    var recurrenceRule: RecurrenceRule? {
        get {
            guard let raw = recurrenceFrequencyRaw,
                  let frequency = RecurrenceFrequency(rawValue: raw) else {
                return nil
            }
            return RecurrenceRule(
                frequency: frequency,
                interval: recurrenceInterval,
                endDate: recurrenceEndDate,
                occurrenceCount: recurrenceOccurrenceCount
            )
        }
        set {
            recurrenceFrequencyRaw = newValue?.frequency.rawValue
            recurrenceInterval = newValue?.interval ?? 1
            recurrenceEndDate = newValue?.endDate
            recurrenceOccurrenceCount = newValue?.occurrenceCount
        }
    }

    var recurrenceEndType: RecurrenceEndType {
        get {
            RecurrenceEndType(rawValue: recurrenceEndTypeRaw) ?? .never
        }
        set {
            recurrenceEndTypeRaw = newValue.rawValue
        }
    }

    var hasRecurrence: Bool {
        recurrenceRule != nil || weekdayMask != 0
    }

}

// MARK: - Date Calculations

extension ScheduleConfig {
    nonisolated func nextFireDate(after reference: Date = Date()) -> Date? {
        return nextScheduledOccurrence(from: reference)
    }

    nonisolated private func nextScheduledOccurrence(from reference: Date) -> Date? {
        if weekdayMask != 0 {
            return nextWeekdayOccurrence(from: reference)
        }

        guard let fireDate = fireDate else {
            return startDate
        }

        if let recurrence = recurrenceRule {
            return nextRecurrenceDate(from: reference, fireDate: fireDate, recurrence: recurrence)
        }

        return fireDate >= reference ? fireDate : nil
    }

    nonisolated func effectiveEndDate(fireDate: Date, recurrence: RecurrenceRule) -> Date? {
        if let count = recurrence.occurrenceCount, count > 0 {
            let calendar = Calendar.current
            let component = recurrence.frequency.calendarComponent
            let totalIntervals = (count - 1) * recurrence.interval
            return calendar.date(byAdding: component, value: totalIntervals, to: fireDate)
        }
        return recurrence.endDate
    }

    nonisolated private func nextRecurrenceDate(from reference: Date, fireDate: Date, recurrence: RecurrenceRule) -> Date? {
        let calendar = Calendar.current
        let endDate = effectiveEndDate(fireDate: fireDate, recurrence: recurrence) ?? recurrence.endDate

        if let endDate, reference > endDate {
            return nil
        }

        if reference < fireDate {
            return fireDate
        }

        switch recurrence.frequency {
        case .minutely:
            let minutesDiff = calendar.dateComponents([.minute], from: fireDate, to: reference).minute ?? 0
            let intervalsPassed = (minutesDiff / recurrence.interval) + 1
            let totalMinutes = intervalsPassed * recurrence.interval
            guard let nextDate = calendar.date(byAdding: .minute, value: totalMinutes, to: fireDate) else {
                return nil
            }
            if let endDate, nextDate > endDate { return nil }
            return nextDate

        case .hourly:
            let hoursDiff = calendar.dateComponents([.hour], from: fireDate, to: reference).hour ?? 0
            let intervalsPassed = (hoursDiff / recurrence.interval) + 1
            let totalHours = intervalsPassed * recurrence.interval
            guard let nextDate = calendar.date(byAdding: .hour, value: totalHours, to: fireDate) else {
                return nil
            }
            if let endDate, nextDate > endDate { return nil }
            return nextDate

        case .daily:
            let daysDiff = calendar.dateComponents([.day], from: fireDate, to: reference).day ?? 0
            let intervalsPassed = (daysDiff / recurrence.interval) + 1
            let totalDays = intervalsPassed * recurrence.interval
            guard let nextDate = calendar.date(byAdding: .day, value: totalDays, to: fireDate) else {
                return nil
            }
            if let endDate, nextDate > endDate { return nil }
            return nextDate

        case .weekly:
            let weeksDiff = calendar.dateComponents([.weekOfYear], from: fireDate, to: reference).weekOfYear ?? 0
            let intervalsPassed = (weeksDiff / recurrence.interval) + 1
            let totalWeeks = intervalsPassed * recurrence.interval
            guard let nextDate = calendar.date(byAdding: .weekOfYear, value: totalWeeks, to: fireDate) else {
                return nil
            }
            if let endDate, nextDate > endDate { return nil }
            return nextDate

        case .monthly:
            let monthsDiff = calendar.dateComponents([.month], from: fireDate, to: reference).month ?? 0
            let intervalsPassed = (monthsDiff / recurrence.interval) + 1
            let totalMonths = intervalsPassed * recurrence.interval
            guard let nextDate = calendar.date(byAdding: .month, value: totalMonths, to: fireDate) else {
                return nil
            }
            if let endDate, nextDate > endDate { return nil }
            return nextDate

        case .yearly:
            let yearsDiff = calendar.dateComponents([.year], from: fireDate, to: reference).year ?? 0
            let intervalsPassed = (yearsDiff / recurrence.interval) + 1
            let totalYears = intervalsPassed * recurrence.interval
            guard let nextDate = calendar.date(byAdding: .year, value: totalYears, to: fireDate) else {
                return nil
            }
            if let endDate, nextDate > endDate { return nil }
            return nextDate
        }
    }

    nonisolated private func nextWeekdayOccurrence(from reference: Date) -> Date? {
        guard weekdayMask != 0 else { return fireDate ?? startDate }
        let calendar = Calendar.current
        let targetDays = (1...7).compactMap { day -> Int? in
            let bit = 1 << day
            return (weekdayMask & Int16(bit)) != 0 ? day : nil
        }

        guard !targetDays.isEmpty else { return fireDate ?? startDate }

        for dayOffset in 0..<7 {
            let candidate = calendar.date(byAdding: .day, value: dayOffset, to: reference) ?? reference
            let weekday = calendar.component(.weekday, from: candidate)
            if targetDays.contains(weekday) {
                if let fireDate = fireDate {
                    let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: fireDate)
                    if let dateWithTime = calendar.date(bySettingHour: timeComponents.hour ?? 0,
                                                         minute: timeComponents.minute ?? 0,
                                                         second: timeComponents.second ?? 0,
                                                         of: candidate) {
                        let start = startDate ?? dateWithTime
                        return dateWithTime < start ? start : dateWithTime
                    }
                }
                let start = startDate ?? candidate
                return candidate < start ? start : candidate
            }
        }

        return fireDate ?? startDate
    }

    /// Returns all occurrence dates within the specified date range
    nonisolated func dates(from startDate: Date, to endDate: Date) -> [Date] {
        if weekdayMask != 0 {
            return weekdayOccurrences(from: startDate, to: endDate)
        }

        guard let fireDate = fireDate else {
            if let start = self.startDate, start >= startDate && start < endDate {
                return [start]
            }
            return []
        }

        if let recurrence = recurrenceRule {
            return recurrenceDates(from: startDate, to: endDate, fireDate: fireDate, recurrence: recurrence)
        }

        if fireDate >= startDate && fireDate < endDate {
            return [fireDate]
        }

        return []
    }

    nonisolated func dates(within range: Range<Date>) -> [Date] {
        return dates(from: range.lowerBound, to: range.upperBound)
    }

    nonisolated private func weekdayOccurrences(from startDate: Date, to endDate: Date) -> [Date] {
        guard weekdayMask != 0 else {
            if let fireDate = fireDate, fireDate >= startDate && fireDate < endDate {
                return [fireDate]
            }
            return []
        }

        let calendar = Calendar.current
        let targetDays = (1...7).compactMap { day -> Int? in
            let bit = 1 << day
            return (weekdayMask & Int16(bit)) != 0 ? day : nil
        }

        guard !targetDays.isEmpty else { return [] }

        var occurrences: [Date] = []
        var currentDate = startDate

        let timeComponents: DateComponents?
        if let fireDate = fireDate {
            timeComponents = calendar.dateComponents([.hour, .minute, .second], from: fireDate)
        } else {
            timeComponents = nil
        }

        while currentDate < endDate {
            let weekday = calendar.component(.weekday, from: currentDate)
            if targetDays.contains(weekday) {
                var dateToAdd = currentDate

                if let timeComponents = timeComponents,
                   let dateWithTime = calendar.date(bySettingHour: timeComponents.hour ?? 0,
                                                    minute: timeComponents.minute ?? 0,
                                                    second: timeComponents.second ?? 0,
                                                    of: currentDate) {
                    dateToAdd = dateWithTime
                }

                if let triggerStartDate = self.startDate {
                    if dateToAdd >= triggerStartDate {
                        occurrences.append(dateToAdd)
                    }
                } else {
                    occurrences.append(dateToAdd)
                }
            }

            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDay
        }

        return occurrences
    }

    nonisolated private func recurrenceDates(from startDate: Date, to endDate: Date, fireDate: Date, recurrence: RecurrenceRule) -> [Date] {
        let calendar = Calendar.current
        var occurrences: [Date] = []
        let effectiveEnd = effectiveEndDate(fireDate: fireDate, recurrence: recurrence)

        if fireDate > endDate {
            return []
        }

        if let recurrenceEndDate = effectiveEnd ?? recurrence.endDate, startDate > recurrenceEndDate {
            return []
        }

        let firstOccurrence: Date
        if fireDate >= startDate {
            firstOccurrence = fireDate
        } else {
            let intervalsToSkip: Int
            switch recurrence.frequency {
            case .minutely:
                let minutesDiff = calendar.dateComponents([.minute], from: fireDate, to: startDate).minute ?? 0
                intervalsToSkip = max(0, Int(ceil(Double(minutesDiff) / Double(recurrence.interval))))
            case .hourly:
                let hoursDiff = calendar.dateComponents([.hour], from: fireDate, to: startDate).hour ?? 0
                intervalsToSkip = max(0, Int(ceil(Double(hoursDiff) / Double(recurrence.interval))))
            case .daily:
                let daysDiff = calendar.dateComponents([.day], from: fireDate, to: startDate).day ?? 0
                intervalsToSkip = max(0, Int(ceil(Double(daysDiff) / Double(recurrence.interval))))
            case .weekly:
                let weeksDiff = calendar.dateComponents([.weekOfYear], from: fireDate, to: startDate).weekOfYear ?? 0
                intervalsToSkip = max(0, Int(ceil(Double(weeksDiff) / Double(recurrence.interval))))
            case .monthly:
                let monthsDiff = calendar.dateComponents([.month], from: fireDate, to: startDate).month ?? 0
                intervalsToSkip = max(0, Int(ceil(Double(monthsDiff) / Double(recurrence.interval))))
            case .yearly:
                let yearsDiff = calendar.dateComponents([.year], from: fireDate, to: startDate).year ?? 0
                intervalsToSkip = max(0, Int(ceil(Double(yearsDiff) / Double(recurrence.interval))))
            }

            let startingInterval = intervalsToSkip * recurrence.interval
            let component = recurrence.frequency.calendarComponent
            guard let calculatedDate = calendar.date(byAdding: component, value: startingInterval, to: fireDate) else {
                return []
            }

            if calculatedDate < startDate {
                guard let adjustedDate = calendar.date(byAdding: component, value: recurrence.interval, to: calculatedDate) else {
                    return []
                }
                firstOccurrence = adjustedDate
            } else {
                firstOccurrence = calculatedDate
            }
        }

        if firstOccurrence > endDate {
            return []
        }

        let recurrenceEndDate = effectiveEnd ?? recurrence.endDate
        if let recurrenceEndDate, firstOccurrence > recurrenceEndDate {
            return []
        }

        var nextDate = firstOccurrence
        var maxIterations = 10000
        let component = recurrence.frequency.calendarComponent
        while nextDate < endDate && maxIterations > 0 {
            if let recurrenceEndDate, nextDate > recurrenceEndDate {
                break
            }

            occurrences.append(nextDate)

            guard let date = calendar.date(byAdding: component, value: recurrence.interval, to: nextDate) else {
                break
            }
            nextDate = date
            maxIterations -= 1
        }

        return occurrences
    }
}

// MARK: - Static Factory Methods

extension ScheduleConfig {
    static func createDefault(minutes: Int = 60, from date: Date = Date()) -> ScheduleConfig {
        let fireDate = date.addingTimeInterval(TimeInterval(minutes * 60))
        return ScheduleConfig(
            fireDate: fireDate,
            startDate: fireDate,
            timeZoneIdentifier: TimeZone.current.identifier,
            isActive: true
        )
    }
}
