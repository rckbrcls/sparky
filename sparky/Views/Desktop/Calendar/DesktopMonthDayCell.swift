#if os(macOS)

import SwiftUI

struct DesktopMonthDayCell: View {
    let date: Date
    let isInDisplayedMonth: Bool
    let occurrences: [MemoryOccurrence]
    let onOpenDay: (Date) -> Void

    @State private var isHovered = false
    @State private var createMemoryRoute: MemoryEditorRoute?

    private let calendar = Calendar.current

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.Theme.secondaryBackground

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    if isHovered || createMemoryRoute != nil {
                        Button {
                            let target = CalendarQuickMemoryTarget(allDay: date)
                            createMemoryRoute = MemoryEditorRoute(
                                mode: .create(mind: nil, template: .blank),
                                initialScheduleConfig: target.scheduleDraft()
                            )
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                                .frame(width: 22, height: 22)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.Theme.textSecondary)
                        .help("New all-day Memory")
                        .accessibilityLabel("New all-day Memory")
                        .desktopMemoryEditorPopover(item: $createMemoryRoute)
                    }

                    Spacer(minLength: 0)

                    Button {
                        onOpenDay(date)
                    } label: {
                        Text(dayLabel)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(dayForeground)
                            .frame(minWidth: 28, minHeight: 28)
                            .background {
                                if calendar.isDateInToday(date) {
                                    Circle().fill(Color.accentColor)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .help("Open day")
                    .accessibilityLabel(
                        date.formatted(.dateTime.weekday(.wide).month(.wide).day().year())
                    )
                }

                if let first = occurrences.first {
                    DesktopCalendarEventPill(
                        occurrence: first,
                        style: .month
                    )
                }

                if occurrences.count > 1 {
                    DesktopCalendarOverflowButton(
                        occurrences: Array(occurrences.dropFirst())
                    )
                }

                Spacer(minLength: 0)
            }
            .padding(6)
        }
        .opacity(isInDisplayedMonth ? 1 : 0.48)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.Theme.separator)
                .frame(height: 1)
        }
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.Theme.separator)
                .frame(width: 1)
        }
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .contain)
    }

    private var dayLabel: String {
        if calendar.component(.day, from: date) == 1 {
            return date.formatted(.dateTime.day().month(.abbreviated))
        }
        return date.formatted(.dateTime.day())
    }

    private var dayForeground: Color {
        if calendar.isDateInToday(date) {
            return Color.Theme.accentForeground
        }
        return isInDisplayedMonth
            ? Color.Theme.textPrimary
            : Color.Theme.textTertiary
    }
}

#endif
