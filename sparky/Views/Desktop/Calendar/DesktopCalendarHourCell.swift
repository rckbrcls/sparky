#if os(macOS)

import SwiftUI

struct DesktopCalendarHourCell: View {
    let date: Date
    let height: CGFloat

    @State private var isHovered = false
    @State private var createMemoryRoute: MemoryEditorRoute?

    var body: some View {
        Button {
            let target = CalendarQuickMemoryTarget(scheduledDate: date)
            createMemoryRoute = MemoryEditorRoute(
                mode: .create(mind: nil, template: .blank),
                initialScheduleConfig: target.scheduleDraft()
            )
        } label: {
            Rectangle()
                .fill(Color.clear)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .overlay(alignment: .topTrailing) {
                    if isHovered {
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.Theme.textTertiary)
                            .padding(5)
                    }
                }
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.Theme.separator)
                        .frame(height: 1)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .desktopMemoryEditorPopover(item: $createMemoryRoute)
        .onHover { isHovered = $0 }
        .help("New Memory at \(date.formatted(.dateTime.hour().minute()))")
        .accessibilityLabel(
            "New Memory, \(date.formatted(.dateTime.weekday().hour().minute()))"
        )
    }
}

#endif
