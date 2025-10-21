//
//  TriggerRowView.swift
//  i-cant-miss
//
//  Created by Codex on 13/10/25.
//

import SwiftUI

struct TriggerRowView: View {
    let display: TriggersViewModel.TriggerDisplay

    private var subtitle: String {
        let trigger = display.trigger
        switch trigger.type {
        case .time:
            if let date = trigger.fireDate {
                return date.formatted(date: .abbreviated, time: .shortened)
            }
            return "Specific time"
        case .dayOfWeek:
            return weekdaysText(from: trigger.weekdayMask)
        case .location:
            return trigger.location?.name ?? "Location-based"
        case .person:
            return trigger.person?.name ?? "Person interaction"
        }
    }

    private func weekdaysText(from mask: Int16) -> String {
        guard mask != 0 else { return "Weekdays" }
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        var names: [String] = []
        for day in 1...7 {
            let bit = 1 << day
            if (mask & Int16(bit)) != 0 {
                let name = formatter.weekdaySymbols[(day - 1) % formatter.weekdaySymbols.count]
                names.append(String(name.prefix(3)))
            }
        }
        return names.joined(separator: ", ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: display.trigger.type.systemImage)
                    .foregroundStyle(Color.accentColor)
                Text(display.reminder.title)
                    .font(.headline)
                Spacer()
                if display.reminder.status == .completed {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let location = display.trigger.location, display.trigger.type == .location {
                Text("Radius: \(Int(location.radius))m • Event: \(location.event.label)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    let trigger = ReminderTriggerModel(
        id: UUID(),
        type: .location,
        fireDate: nil,
        startDate: nil,
        recurrenceRule: nil,
        timeZoneIdentifier: nil,
        weekdayMask: 0,
        isActive: true,
        location: .init(latitude: 0, longitude: 0, radius: 200, name: "Home", event: .onEntry),
        person: nil,
        spacedStage: 0,
        lastReviewDate: nil,
        ignoreCount: 0
    )
    let reminder = ReminderModel(
        id: UUID(),
        title: "Buy groceries",
        notes: nil,
        status: .active,
        priority: .medium,
        folder: nil,
        createdAt: Date(),
        updatedAt: Date(),
        lastCompletionDate: nil,
        snoozeCount: 0,
        triggers: [trigger]
    )
    TriggerRowView(display: .init(id: trigger.id, reminder: reminder, trigger: trigger))
        .padding()
}
