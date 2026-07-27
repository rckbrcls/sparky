//
//  CalendarEmptyPeriodButton.swift
//  sparky
//
//  Quick-add affordance for an empty calendar period.
//

import SwiftUI

struct CalendarEmptyPeriodButton: View {
    let period: CalendarTimePeriod
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(period.emptyStateTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.Theme.textSecondary)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 12)

                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.Theme.textTertiary)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 56)
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        Color.Theme.textTertiary.opacity(isHovering ? 0.9 : 0.55),
                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])
                    )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(CalendarEmptyPeriodButtonStyle())
        .accessibilityLabel(period.emptyStateTitle)
        .accessibilityHint("Opens Quick Memory for \(period.title)")
        .calendarEmptyPeriodHover { isHovering = $0 }
    }
}

private extension View {
    @ViewBuilder
    func calendarEmptyPeriodHover(_ action: @escaping (Bool) -> Void) -> some View {
        #if os(macOS)
        onHover(perform: action)
        #else
        self
        #endif
    }
}
