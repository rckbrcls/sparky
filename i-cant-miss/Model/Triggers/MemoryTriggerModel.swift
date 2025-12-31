//
//  MemoryTriggerModel.swift
//  i-cant-miss
//

import Foundation

struct MemoryTriggerModel: Identifiable, Hashable, Codable {
    let id: UUID
    let type: MemoryTriggerType
    var fireDate: Date?
    var startDate: Date?
    var recurrenceRule: RecurrenceRule?
    var timeZoneIdentifier: String?
    var weekdayMask: Int16
    var isActive: Bool
    var location: TriggerLocation?
    var person: TriggerPerson?
    var sequential: TriggerSequential?
    var focus: TriggerFocus?
    var spacedStage: Int
    var lastReviewDate: Date?
    var ignoreCount: Int

    struct TriggerLocation: Hashable, Codable {
        var latitude: Double
        var longitude: Double
        var radius: Double
        var name: String?
        var event: LocationEvent
    }

    struct TriggerPerson: Hashable, Codable {
        var name: String
        var contactIdentifier: String?
    }

    struct TriggerSequential: Hashable, Codable {
        var previousMemoryID: UUID?
        var nextMemoryID: UUID?
    }

    struct TriggerFocus: Hashable, Codable {
        var focusIdentifier: String?
        var focusName: String
    }
}

// MARK: - TriggerProtocol Conversion

extension MemoryTriggerModel {
    /// Converte para um trigger protocol
    func toTriggerProtocol() -> any TriggerProtocol {
        TriggerFactory.createTrigger(from: self)
    }
}

// MARK: - Date Calculations

extension MemoryTriggerModel {
    nonisolated func nextFireDate(after reference: Date = Date()) -> Date? {
        switch type {
        case .scheduled:
            return nextScheduledOccurrence(from: reference)
        case .location, .person, .sequential, .focus:
            return startDate ?? fireDate
        }
    }

    nonisolated private func nextScheduledOccurrence(from reference: Date) -> Date? {
        // If there's a weekdayMask, use weekday logic
        if weekdayMask != 0 {
            return nextWeekdayOccurrence(from: reference)
        }

        // If there's only a fireDate without recurrence, return the fireDate
        guard let fireDate = fireDate else {
            return startDate
        }

        // If there's recurrence, calculate next occurrence
        if let recurrence = recurrenceRule {
            return nextRecurrenceDate(from: reference, fireDate: fireDate, recurrence: recurrence)
        }

        // Simple case: just a date/time
        return fireDate >= reference ? fireDate : nil
    }

    nonisolated private func nextRecurrenceDate(from reference: Date, fireDate: Date, recurrence: RecurrenceRule) -> Date? {
        let calendar = Calendar.current

        // Check endDate first
        if let endDate = recurrence.endDate, reference > endDate {
            return nil
        }

        // If reference date is before fireDate, return fireDate
        if reference < fireDate {
            return fireDate
        }

        // Use mathematical calculation instead of loop (O(1) instead of O(N))
        switch recurrence.frequency {
        case .minutely:
            let minutesDiff = calendar.dateComponents([.minute], from: fireDate, to: reference).minute ?? 0
            let intervalsPassed = (minutesDiff / recurrence.interval) + 1
            let totalMinutes = intervalsPassed * recurrence.interval
            guard let nextDate = calendar.date(byAdding: .minute, value: totalMinutes, to: fireDate) else {
                return nil
            }
            // Verify endDate if exists
            if let endDate = recurrence.endDate, nextDate > endDate {
                return nil
            }
            return nextDate

        case .hourly:
            let hoursDiff = calendar.dateComponents([.hour], from: fireDate, to: reference).hour ?? 0
            let intervalsPassed = (hoursDiff / recurrence.interval) + 1
            let totalHours = intervalsPassed * recurrence.interval
            guard let nextDate = calendar.date(byAdding: .hour, value: totalHours, to: fireDate) else {
                return nil
            }
            // Verify endDate if exists
            if let endDate = recurrence.endDate, nextDate > endDate {
                return nil
            }
            return nextDate

        case .daily:
            let daysDiff = calendar.dateComponents([.day], from: fireDate, to: reference).day ?? 0
            let intervalsPassed = (daysDiff / recurrence.interval) + 1
            let totalDays = intervalsPassed * recurrence.interval
            guard let nextDate = calendar.date(byAdding: .day, value: totalDays, to: fireDate) else {
                return nil
            }
            // Verify endDate if exists
            if let endDate = recurrence.endDate, nextDate > endDate {
                return nil
            }
            return nextDate

        case .weekly:
            let weeksDiff = calendar.dateComponents([.weekOfYear], from: fireDate, to: reference).weekOfYear ?? 0
            let intervalsPassed = (weeksDiff / recurrence.interval) + 1
            let totalWeeks = intervalsPassed * recurrence.interval
            guard let nextDate = calendar.date(byAdding: .weekOfYear, value: totalWeeks, to: fireDate) else {
                return nil
            }
            // Verify endDate if exists
            if let endDate = recurrence.endDate, nextDate > endDate {
                return nil
            }
            return nextDate

        case .monthly:
            let monthsDiff = calendar.dateComponents([.month], from: fireDate, to: reference).month ?? 0
            let intervalsPassed = (monthsDiff / recurrence.interval) + 1
            let totalMonths = intervalsPassed * recurrence.interval
            guard let nextDate = calendar.date(byAdding: .month, value: totalMonths, to: fireDate) else {
                return nil
            }
            // Verify endDate if exists
            if let endDate = recurrence.endDate, nextDate > endDate {
                return nil
            }
            return nextDate

        case .yearly:
            let yearsDiff = calendar.dateComponents([.year], from: fireDate, to: reference).year ?? 0
            let intervalsPassed = (yearsDiff / recurrence.interval) + 1
            let totalYears = intervalsPassed * recurrence.interval
            guard let nextDate = calendar.date(byAdding: .year, value: totalYears, to: fireDate) else {
                return nil
            }
            // Verify endDate if exists
            if let endDate = recurrence.endDate, nextDate > endDate {
                return nil
            }
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
                // If there's a fireDate, use its time
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

    /// Returns all occurrence dates for this trigger within the specified date range
    nonisolated func dates(from startDate: Date, to endDate: Date) -> [Date] {
        // For non-scheduled triggers, return single date if in range
        guard type == .scheduled else {
            if let date = self.startDate ?? fireDate, date >= startDate && date <= endDate {
                return [date]
            }
            return []
        }

        // If there's a weekdayMask, use weekday logic
        if weekdayMask != 0 {
            return weekdayOccurrences(from: startDate, to: endDate)
        }

        guard let fireDate = fireDate else {
            if let start = self.startDate, start >= startDate && start <= endDate {
                return [start]
            }
            return []
        }

        // If there's recurrence, calculate all occurrences
        if let recurrence = recurrenceRule {
            return recurrenceDates(from: startDate, to: endDate, fireDate: fireDate, recurrence: recurrence)
        }

        // Simple case: just a date/time
        if fireDate >= startDate && fireDate <= endDate {
            return [fireDate]
        }

        return []
    }

    /// Returns all occurrence dates for this trigger within the specified date range (Range<Date> version)
    nonisolated func dates(within range: Range<Date>) -> [Date] {
        return dates(from: range.lowerBound, to: range.upperBound)
    }

    nonisolated private func weekdayOccurrences(from startDate: Date, to endDate: Date) -> [Date] {
        guard weekdayMask != 0 else {
            if let fireDate = fireDate, fireDate >= startDate && fireDate <= endDate {
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

        // Get time components from fireDate if available
        let timeComponents: DateComponents?
        if let fireDate = fireDate {
            timeComponents = calendar.dateComponents([.hour, .minute, .second], from: fireDate)
        } else {
            timeComponents = nil
        }

        // Iterate through each day in the range
        while currentDate <= endDate {
            let weekday = calendar.component(.weekday, from: currentDate)
            if targetDays.contains(weekday) {
                var dateToAdd = currentDate

                // Apply time from fireDate if available
                if let timeComponents = timeComponents,
                   let dateWithTime = calendar.date(bySettingHour: timeComponents.hour ?? 0,
                                                    minute: timeComponents.minute ?? 0,
                                                    second: timeComponents.second ?? 0,
                                                    of: currentDate) {
                    dateToAdd = dateWithTime
                }

                // Check startDate constraint
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

        // If fireDate is after endDate, no occurrences
        if fireDate > endDate {
            return []
        }

        // Check if recurrence has ended
        if let recurrenceEndDate = recurrence.endDate, startDate > recurrenceEndDate {
            return []
        }

        // Calculate first occurrence >= startDate using mathematical calculation (O(1))
        let firstOccurrence: Date
        if fireDate >= startDate {
            // Fire date is already in range
            firstOccurrence = fireDate
        } else {
            // Calculate how many intervals to skip to reach or exceed startDate
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

            // Calculate starting date mathematically
            let startingInterval = intervalsToSkip * recurrence.interval
            let component = recurrence.frequency.calendarComponent
            guard let calculatedDate = calendar.date(byAdding: component, value: startingInterval, to: fireDate) else {
                return []
            }

            // Ensure we're at or after startDate (handle edge cases with time components)
            if calculatedDate < startDate {
                guard let adjustedDate = calendar.date(byAdding: component, value: recurrence.interval, to: calculatedDate) else {
                    return []
                }
                firstOccurrence = adjustedDate
            } else {
                firstOccurrence = calculatedDate
            }
        }

        // Verify first occurrence is not after endDate
        if firstOccurrence > endDate {
            return []
        }

        // Verify first occurrence is not after recurrence endDate
        if let recurrenceEndDate = recurrence.endDate, firstOccurrence > recurrenceEndDate {
            return []
        }

        // Generate all occurrences in range (loop is acceptable here as it's only ~30 days for month, ~365 for year)
        var nextDate = firstOccurrence
        var maxIterations = 10000 // Safety limit
        let component = recurrence.frequency.calendarComponent
        while nextDate <= endDate && maxIterations > 0 {
            // Check endDate constraint
            if let recurrenceEndDate = recurrence.endDate, nextDate > recurrenceEndDate {
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
