#if os(macOS)

import SwiftUI

struct DesktopAllDayColumn: View {
    let occurrences: [MemoryOccurrence]
    let onSelect: (Memory) -> Void

    private let visibleLimit = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(Array(occurrences.prefix(visibleLimit))) { occurrence in
                DesktopCalendarEventPill(
                    occurrence: occurrence,
                    style: .allDay,
                    onSelect: onSelect
                )
            }

            if occurrences.count > visibleLimit {
                DesktopCalendarOverflowButton(
                    occurrences: Array(occurrences.dropFirst(visibleLimit)),
                    onSelect: onSelect
                )
            }

            Spacer(minLength: 0)
        }
        .padding(4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.Theme.separator)
                .frame(width: 1)
        }
    }
}

#endif
