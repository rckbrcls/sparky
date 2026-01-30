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

    var body: some View {
        Button(action: onToggle) {
            HStack {
                Image(systemName: period.iconName)
                    .font(.caption2)
                    .foregroundStyle(.elementBorder)

                Text(period.title)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.elementBorder)

                Text("\(count)")
                    .font(.caption2)
                    .foregroundStyle(.elementBorder)

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.elementBorder)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .padding(6)
            .background(Color.accentColor)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.accentColor.opacity(0.8), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
