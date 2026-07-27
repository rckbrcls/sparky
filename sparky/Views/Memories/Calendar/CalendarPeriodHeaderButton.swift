//
//  CalendarPeriodHeaderButton.swift
//  sparky
//
//  Created by Codex on 09/03/24.
//

import SwiftUI

struct CalendarPeriodHeaderButton: View {
    let period: CalendarTimePeriod
    let count: Int
    let isExpanded: Bool
    let onToggle: () -> Void

    private var accessibilityCount: String {
        count == 1 ? "1 memory" : "\(count) memories"
    }

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 6) {
                Image(systemName: period.iconName)
                    .font(.caption2)

                Text(period.title)
                    .font(.caption2)
                    .fontWeight(.medium)

                Text("\(count)")
                    .font(.caption2)

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .foregroundStyle(Color.Theme.accentForeground)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(period.color, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(period.title), \(accessibilityCount)")
        .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
        .accessibilityHint(isExpanded ? "Collapses this period" : "Expands this period")
    }
}
