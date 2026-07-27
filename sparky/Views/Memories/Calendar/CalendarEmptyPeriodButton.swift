//
//  CalendarEmptyPeriodButton.swift
//  sparky
//
//  Quick-add affordance for an empty calendar period.
//

import SwiftUI

struct CalendarEmptyPeriodButton: View {
    let period: CalendarTimePeriod
    let target: CalendarQuickMemoryTarget
    let creationBehavior: CalendarMemoryCreationBehavior

    @State private var isHovering = false
    #if os(macOS)
    @State private var createMemoryRoute: MemoryEditorRoute?
    #endif

    var body: some View {
        Button(action: presentCreation) {
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
        .accessibilityHint(accessibilityHint)
        .calendarEmptyPeriodPopover(
            item: calendarCreateMemoryRoute
        )
        .calendarEmptyPeriodHover { isHovering = $0 }
    }

    private var accessibilityHint: String {
        #if os(macOS)
        "Opens New Memory for \(period.title)"
        #else
        "Opens Quick Memory for \(period.title)"
        #endif
    }

    private func presentCreation() {
        switch creationBehavior {
        case let .action(action):
            action(target)

        #if os(macOS)
        case let .desktopPopover(makeRoute):
            createMemoryRoute = makeRoute(target)
        #endif
        }
    }

    private var calendarCreateMemoryRoute: Binding<MemoryEditorRoute?> {
        #if os(macOS)
        $createMemoryRoute
        #else
        .constant(nil)
        #endif
    }
}

private extension View {
    @ViewBuilder
    func calendarEmptyPeriodPopover(
        item: Binding<MemoryEditorRoute?>
    ) -> some View {
        #if os(macOS)
        desktopMemoryEditorPopover(item: item)
        #else
        self
        #endif
    }

    @ViewBuilder
    func calendarEmptyPeriodHover(_ action: @escaping (Bool) -> Void) -> some View {
        #if os(macOS)
        onHover(perform: action)
        #else
        self
        #endif
    }
}
