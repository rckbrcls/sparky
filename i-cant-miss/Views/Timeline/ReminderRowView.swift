//
//  ReminderRowView.swift
//  i-cant-miss
//
//  Created by Codex on 13/10/25.
//

import SwiftUI

struct ReminderRowView: View {
    let reminder: ReminderModel
    var nextFireDate: Date? {
        reminder.nextFireDate()
    }

    private var displayTriggers: [TriggerDisplayItem] {
        var items: [TriggerDisplayItem] = []
        if let schedule = scheduleBadgeData {
            items.append(.schedule(schedule))
        }
        let additional = reminder.triggers.filter { $0.type != .time && $0.type != .dayOfWeek }
        items.append(contentsOf: additional.map { TriggerDisplayItem.trigger($0) })
        return items
    }

    private var scheduleBadgeData: ScheduleBadgeData? {
        let timeTrigger = reminder.triggers.first(where: { $0.type == .time })
        let weekdayTrigger = reminder.triggers.first(where: { $0.type == .dayOfWeek })

        guard timeTrigger != nil || weekdayTrigger != nil else { return nil }

        let scheduleId = timeTrigger?.id ?? weekdayTrigger?.id ?? UUID()
        let weekdayMask = weekdayTrigger?.weekdayMask ?? 0
        let hasWeekdays = weekdayMask != 0
        let scheduleDate = timeTrigger?.fireDate ?? weekdayTrigger?.fireDate

        var primary: String
        var detailParts: [String] = []

        if let fireDate = timeTrigger?.fireDate {
            primary = fireDate.formatted(date: .abbreviated, time: .shortened)
        } else if hasWeekdays {
            primary = weekdaySummary(mask: weekdayMask)
        } else if let fireDate = scheduleDate {
            primary = fireDate.formatted(date: .abbreviated, time: .shortened)
        } else {
            primary = "Schedule"
        }

        if let recurrence = timeTrigger?.recurrenceRule {
            detailParts.append(recurrenceDescription(recurrence))
        }

        if hasWeekdays {
            let summary = weekdaySummary(mask: weekdayMask)
            if summary != primary {
                detailParts.append(summary)
            }
        }

        if timeTrigger == nil, let fireDate = scheduleDate {
            let timeText = fireDate.formatted(date: .omitted, time: .shortened)
            if !timeText.isEmpty {
                detailParts.append(timeText)
            }
        }

        return ScheduleBadgeData(
            id: scheduleId,
            primary: primary,
            detail: detailParts.isEmpty ? nil : detailParts.joined(separator: " • ")
        )
    }

    private func recurrenceDescription(_ recurrence: RecurrenceRule) -> String {
        var text = "Repeats \(recurrence.frequency.title.lowercased())"
        if recurrence.interval > 1 {
            text += " every \(recurrence.interval)"
        }
        return text
    }

    private func weekdaySummary(mask: Int16) -> String {
        guard mask != 0 else { return "Weekdays" }
        let formatter = DateFormatter()
        let symbols = formatter.shortWeekdaySymbols ?? []
        guard !symbols.isEmpty else { return "Weekdays" }
        let days = (1...7).compactMap { day -> String? in
            let bit = 1 << day
            guard mask & Int16(bit) != 0 else { return nil }
            return symbols[(day - 1) % symbols.count]
        }
        return days.isEmpty ? "Weekdays" : days.joined(separator: ", ")
    }

    private var statusText: String {
        switch reminder.status {
        case .active:
            if let nextFireDate {
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .abbreviated
                let relative = formatter.localizedString(for: nextFireDate, relativeTo: Date())
                return "Due \(relative)"
            } else {
                return "Awaiting trigger"
            }
        case .completed:
            return "Completed"
        case .overdue:
            return "Overdue"
        case .archived:
            return "Archived"
        }
    }

    private var statusColor: Color {
        switch reminder.status {
        case .active:
            if let next = nextFireDate, next < Date() {
                return .red
            }
            return .blue
        case .completed:
            return .green
        case .overdue:
            return .red
        case .archived:
            return .secondary
        }
    }

    private var priorityColor: Color {
        switch reminder.priority {
        case .low: return .secondary
        case .medium: return .orange
        case .high: return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Triggers section
            if !displayTriggers.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(displayTriggers) { item in
                        switch item {
                        case .schedule(let data):
                            ScheduleBadge(data: data)
                        case .trigger(let trigger):
                            TriggerBadge(trigger: trigger)
                        }
                    }
                }
                .padding(.bottom, 12)

                Divider()
                    .padding(.bottom, 12)
            }

            // Title and priority section
            HStack(alignment: .firstTextBaseline) {
                Text(reminder.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: reminder.priority.iconName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Priority \(reminder.priority.rawValue + 1)")
            }
            .padding(.bottom, 8)

            // Notes section
            if let notes = reminder.notes, !notes.isEmpty {
                Text(notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .padding(.bottom, 12)
            }
            
            Divider()
                .padding(.bottom, 8)

            // Status and metadata section
            HStack(spacing: 16) {
                Label(statusText, systemImage: "clock.badge")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if reminder.snoozeCount > 0 {
                    Divider()
                        .frame(height: 12)

                    Label("\(reminder.snoozeCount) snoozes", systemImage: "zzz")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(24)
        .accessibilityElement(children: .combine)
    }
}

private struct TriggerBadge: View {
    let trigger: ReminderTriggerModel

    private var labelText: String {
        switch trigger.type {
        case .time:
            if let date = trigger.fireDate {
                return date.formatted(date: .abbreviated, time: .shortened)
            }
            return "Time"
        case .dayOfWeek:
            return "Weekdays"
        case .location:
            return trigger.location?.name ?? "Location"
        case .person:
            return trigger.person?.name ?? "Person"
        case .importantDate:
            if let date = trigger.fireDate {
                return date.formatted(date: .abbreviated, time: .omitted)
            }
            return "Important date"
        }
    }

    private var typeLabel: String {
        switch trigger.type {
        case .time:
            return "Time"
        case .dayOfWeek:
            return "Recurring"
        case .location:
            return "Location"
        case .person:
            return "Contact"
        case .importantDate:
            return "Important Date"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: trigger.type.systemImage)
                .font(.title3)
                .foregroundStyle(.primary)
                .frame(width: 28)

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(typeLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text(labelText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(.infinity)
    }
}

private enum TriggerDisplayItem: Identifiable {
    case schedule(ScheduleBadgeData)
    case trigger(ReminderTriggerModel)

    var id: UUID {
        switch self {
        case .schedule(let data):
            return data.id
        case .trigger(let trigger):
            return trigger.id
        }
    }
}

private struct ScheduleBadgeData: Identifiable {
    let id: UUID
    let primary: String
    let detail: String?
}

private struct ScheduleBadge: View {
    let data: ScheduleBadgeData

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.title3)
                .foregroundStyle(.primary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text("Schedule")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text(data.primary)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                if let detail = data.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(.infinity)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    // Multiple triggers for richer preview
    let timeTrigger = ReminderTriggerModel(
        id: UUID(),
        type: .time,
        fireDate: Date().addingTimeInterval(3600),
        startDate: Date(),
        recurrenceRule: RecurrenceRule(frequency: .weekly),
        timeZoneIdentifier: TimeZone.current.identifier,
        weekdayMask: 0,
        isActive: true,
        location: nil,
        person: nil,
        spacedStage: 0,
        lastReviewDate: nil,
        ignoreCount: 0
    )

    let weekdayTrigger = ReminderTriggerModel(
        id: UUID(),
        type: .dayOfWeek,
        fireDate: nil,
        startDate: Date(),
        recurrenceRule: RecurrenceRule(frequency: .weekly),
        timeZoneIdentifier: TimeZone.current.identifier,
        weekdayMask: 0b0111110, // Mon-Fri
        isActive: true,
        location: nil,
        person: nil,
        spacedStage: 0,
        lastReviewDate: nil,
        ignoreCount: 0
    )




    let importantDateTrigger = ReminderTriggerModel(
        id: UUID(),
        type: .importantDate,
        fireDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()),
        startDate: Date(),
        recurrenceRule: nil,
        timeZoneIdentifier: TimeZone.current.identifier,
        weekdayMask: 0,
        isActive: true,
        location: nil,
        person: nil,
        spacedStage: 0,
        lastReviewDate: nil,
        ignoreCount: 0
    )

    let reminder = ReminderModel(
        id: UUID(),
        title: "Submit project report",
        notes: "Include database migration plan",
        status: .active,
        priority: .high,
        createdAt: Date(),
        updatedAt: Date(),
        lastCompletionDate: nil,
        snoozeCount: 1,
        triggers: [timeTrigger, weekdayTrigger, importantDateTrigger],
        importantDate: nil
    )
    ReminderRowView(reminder: reminder)
        .padding()
}
