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
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(reminder.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: reminder.priority.iconName)
                    .font(.caption)
                    .foregroundStyle(priorityColor)
                    .accessibilityLabel("Priority \(reminder.priority.rawValue + 1)")
            }

            if let notes = reminder.notes, !notes.isEmpty {
                Text(notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if !reminder.triggers.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(reminder.triggers, id: \.id) { trigger in
                            TriggerBadge(trigger: trigger)
                        }
                    }
                }
            }

            HStack {
                Label(statusText, systemImage: "clock.badge")
                    .font(.caption)
                    .foregroundStyle(statusColor)
                Spacer()
                if reminder.snoozeCount > 0 {
                    Label("\(reminder.snoozeCount) snoozes", systemImage: "zzz")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
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
                return "On \(date.formatted(date: .abbreviated, time: .omitted))"
            }
            return "Important date"
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: trigger.type.systemImage)
            Text(labelText)
        }
        .font(.caption.weight(.medium))
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(.thinMaterial, in: Capsule())
    }
}

#Preview {
    let trigger = ReminderTriggerModel(
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
        triggers: [trigger],
        importantDate: nil
    )
    ReminderRowView(reminder: reminder)
        .padding()
        .previewLayout(.sizeThatFits)
}
