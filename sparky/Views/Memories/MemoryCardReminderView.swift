//
//  MemoryCardReminderView.swift
//  sparky
//

import SwiftUI

struct MemoryCardReminderView: View {
    let reminder: ReminderConfig
    let isCompletedForDisplay: Bool

    private var intervalText: String {
        let value = max(1, reminder.intervalValue)
        return "Every \(value) \(reminder.intervalUnit.unitLabel(for: value))"
    }

    private var endText: String {
        if let count = reminder.repeatCount {
            let suffix = count == 1 ? "reminder" : "reminders"
            return "After \(count) \(suffix)"
        }
        return "Until completed"
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.badge.fill")
                .font(.caption)
                .foregroundStyle(isCompletedForDisplay ? .secondary : .primary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(intervalText)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(isCompletedForDisplay ? .secondary : .primary)
                    .strikethrough(isCompletedForDisplay, color: .secondary)
            }

            Spacer(minLength: 0)

            Text(endText)
                .font(.caption)
                .foregroundStyle(Color.secondary.opacity(isCompletedForDisplay ? 0.7 : 1.0))
                .strikethrough(isCompletedForDisplay, color: .secondary)
        }
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .padding(.vertical, 10)
    }
}
