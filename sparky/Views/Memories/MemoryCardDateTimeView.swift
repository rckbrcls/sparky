//
//  MemoryCardDateTimeView.swift
//  sparky
//
//  Created by Codex on 13/10/25.
//

import SwiftUI

struct MemoryCardDateTimeView: View {
    let trigger: ScheduleConfig
    let isCompletedForDisplay: Bool
    var occurrenceDate: Date?
    /// When set (e.g. calendar day list), omit the calendar date from the badge.
    var displayDate: Date? = nil

    private var effectiveDate: Date? {
        occurrenceDate ?? trigger.fireDate
    }

    private var badgeText: String {
        guard let date = effectiveDate else { return "" }

        var parts: [String] = []

        if trigger.isAllDay {
            if displayDate == nil {
                parts.append(date.formatted(date: .abbreviated, time: .omitted))
            } else {
                parts.append("All day")
            }
        } else {
            parts.append(date.formatted(date: .omitted, time: .shortened))
            if displayDate == nil {
                parts.append(date.formatted(date: .abbreviated, time: .omitted))
            }
        }

        if let recurrence = recurrenceString {
            parts.append(recurrence)
        }

        return parts.joined(separator: " · ")
    }

    private var recurrenceString: String? {
        if trigger.weekdayMask != 0 {
            return weekdayMaskSummary(mask: trigger.weekdayMask)
        }

        guard let recurrence = trigger.recurrenceRule else {
            return nil
        }

        switch recurrence.frequency {
        case .daily:
            return recurrence.interval > 1 ? "Every \(recurrence.interval) days" : "Daily"
        case .weekly:
            return recurrence.interval > 1 ? "Every \(recurrence.interval) weeks" : "Weekly"
        case .monthly:
            return recurrence.interval > 1 ? "Every \(recurrence.interval) months" : "Monthly"
        case .yearly:
            return recurrence.interval > 1 ? "Every \(recurrence.interval) years" : "Yearly"
        case .hourly:
            return recurrence.interval > 1 ? "Every \(recurrence.interval) hours" : "Hourly"
        case .minutely:
            return recurrence.interval > 1 ? "Every \(recurrence.interval) min" : "Minutely"
        }
    }

    var body: some View {
        MemoryCardMetaBadge(
            systemImage: "calendar",
            text: badgeText,
            isCompleted: isCompletedForDisplay
        )
    }
}
