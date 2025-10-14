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
            if !reminder.triggers.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(reminder.triggers, id: \.id) { trigger in
                        TriggerBadge(trigger: trigger)
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

                Divider()
                    .padding(.bottom, 8)
            }

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
        .cornerRadius(12)
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
