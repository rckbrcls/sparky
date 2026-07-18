//
//  MemoryCardReminderView.swift
//  sparky
//

import SwiftUI

struct MemoryCardReminderView: View {
    let policy: NestedReminderPolicy
    let sourceLabel: String
    let isCompletedForDisplay: Bool

    private var intervalText: String {
        let value = max(1, policy.intervalValue)
        return "Every \(value) \(policy.intervalUnit.unitLabel(for: value))"
    }

    private var endText: String {
        if let count = policy.repeatCount {
            let suffix = count == 1 ? "reminder" : "reminders"
            return "After \(count) \(suffix)"
        }
        return "Until completed"
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "bell.badge.fill")
                .font(.caption)
                .foregroundStyle(isCompletedForDisplay ? .secondary : .primary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(sourceLabel) · \(intervalText)")
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
