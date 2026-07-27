#if os(macOS)

import SwiftUI

struct DesktopCalendarEventPill: View {
    enum Style {
        case allDay
        case timed
        case month
    }

    let occurrence: MemoryOccurrence
    let style: Style
    let onSelect: ((Memory) -> Void)?

    @State private var editorRoute: MemoryEditorRoute?

    init(
        occurrence: MemoryOccurrence,
        style: Style,
        onSelect: ((Memory) -> Void)? = nil
    ) {
        self.occurrence = occurrence
        self.style = style
        self.onSelect = onSelect
    }

    private var color: Color {
        CalendarColorHelper.color(for: occurrence.memory)
    }

    private var isCompleted: Bool {
        occurrence.memory.isCompleted(for: occurrence.occurrenceDate)
    }

    var body: some View {
        Button {
            if let onSelect {
                onSelect(occurrence.memory)
            } else {
                editorRoute = MemoryEditorRoute(
                    mode: .preview(memory: occurrence.memory)
                )
            }
        } label: {
            HStack(spacing: 6) {
                indicator

                Text(occurrence.memory.title)
                    .font(.system(size: style == .month ? 12 : 13, weight: .semibold))
                    .lineLimit(1)
                    .foregroundStyle(
                        isCompleted
                            ? Color.Theme.textTertiary
                            : Color.Theme.textPrimary
                    )

                Spacer(minLength: 2)

                if occurrence.memory.hasRecurringTriggers && style != .month {
                    Image(systemName: "arrow.trianglehead.2.clockwise")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color.Theme.textTertiary)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, style == .month ? 4 : 7)
            .frame(maxWidth: .infinity, minHeight: pillHeight, alignment: .leading)
            .background(backgroundShape)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(occurrence.memory.title)
        .accessibilityLabel(accessibilityLabel)
        .desktopMemoryEditorPopover(item: $editorRoute)
    }

    @ViewBuilder
    private var indicator: some View {
        if style == .month {
            Capsule()
                .fill(color)
                .frame(width: 4, height: 14)
        } else {
            Circle()
                .stroke(color, lineWidth: 2)
                .background {
                    if isCompleted {
                        Circle().fill(color)
                    }
                }
                .frame(width: 12, height: 12)
        }
    }

    @ViewBuilder
    private var backgroundShape: some View {
        if style == .month {
            Color.clear
        } else {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.Theme.elementBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(Color.Theme.elementBorder, lineWidth: 1)
                }
        }
    }

    private var pillHeight: CGFloat {
        style == .month ? 20 : 24
    }

    private var accessibilityLabel: String {
        let timeDescription = occurrence.isAllDay
            ? "All day"
            : occurrence.occurrenceDate.formatted(.dateTime.hour().minute())
        let recurrence = occurrence.memory.hasRecurringTriggers ? ", repeating" : ""
        return "\(occurrence.memory.title), \(timeDescription)\(recurrence)"
    }
}

#endif
