//
//  CalendarPeriodHeaderButton.swift
//  i-cant-miss
//
//  Created by Codex on 09/03/24.
//

import SwiftUI

struct CalendarPeriodHeaderButton: View {
    let period: CalendarTimePeriod
    let count: Int
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack {
                Image(systemName: period.iconName)
                    .foregroundStyle(period.color)
                    .font(.subheadline)
                Text(period.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                Text("\(count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(period.color.opacity(0.20))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(period.color.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
