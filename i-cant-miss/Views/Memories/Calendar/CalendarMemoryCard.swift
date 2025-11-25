//
//  CalendarMemoryCard.swift
//  i-cant-miss
//
//  Created by Codex on 09/03/24.
//

import SwiftUI

struct CalendarMemoryCard: View {
    let memory: MemoryModel
    let fireDate: Date
    let isSelected: Bool
    let isDisabled: Bool
    let onSelect: () -> Void
    let onEdit: (() -> Void)?

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }

    private var hasTimeRange: Bool {
        // Check if memory has a duration or time range
        // For now, just show the fire time
        return false
    }

    private var timeDisplay: String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: fireDate)

        if let hour = components.hour, let minute = components.minute {
            if hour == 0 && minute == 0 {
                return "All day"
            }
            return timeFormatter.string(from: fireDate)
        }
        return "All day"
    }

    private var triggerSummary: String? {
        let scheduledTriggers = memory.triggers.filter { $0.type == .scheduled && $0.isActive }
        guard !scheduledTriggers.isEmpty else { return nil }

        // Check for recurrence
        if let trigger = scheduledTriggers.first, trigger.recurrenceRule != nil {
            if trigger.weekdayMask != 0 {
                // Weekday-based recurrence
                return "Recurring"
            }
            return "Recurring"
        }

        return nil
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Time indicator
                VStack(alignment: .leading, spacing: 2) {
                    Text(timeDisplay)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .frame(width: 60, alignment: .leading)
                }

                // Memory content
                VStack(alignment: .leading, spacing: 4) {
                    Text(memory.title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    if let summary = triggerSummary {
                        Text(summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Chips
                    HStack(spacing: 6) {
                        if memory.hasRecurringTriggers {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        if let space = memory.space {
                            Text(space.name)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accent.opacity(0.2))
                                .foregroundStyle(.accent)
                                .cornerRadius(4)
                        }

                        if memory.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.accent.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accent : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

#Preview {
    let memory = MemoryModel(
        id: UUID(),
        title: "Sample Memory",
        body: nil,
        createdAt: Date(),
        updatedAt: Date(),
        status: .active,
        isPinned: false,
        priority: nil,
        dueDate: nil,
        space: nil,
        triggers: [],
        checkItems: [],
        autoCompleteOnChecklistCompletion: false,
        contents: [],
        attachments: []
    )

    return CalendarMemoryCard(
        memory: memory,
        fireDate: Date(),
        isSelected: false,
        isDisabled: false,
        onSelect: {},
        onEdit: nil
    )
    .padding()
}
