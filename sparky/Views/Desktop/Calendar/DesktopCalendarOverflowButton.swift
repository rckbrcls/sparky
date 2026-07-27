#if os(macOS)

import SwiftUI

struct DesktopCalendarOverflowButton: View {
    let occurrences: [MemoryOccurrence]
    let onSelect: (Memory) -> Void

    @State private var isPresented = false

    var body: some View {
        Button("+\(occurrences.count) more") {
            isPresented.toggle()
        }
        .buttonStyle(.plain)
        .font(.caption.weight(.semibold))
        .foregroundStyle(Color.Theme.textSecondary)
        .lineLimit(1)
        .popover(isPresented: $isPresented, arrowEdge: .trailing) {
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(occurrences) { occurrence in
                        DesktopCalendarEventPill(
                            occurrence: occurrence,
                            style: occurrence.isAllDay ? .allDay : .timed,
                            onSelect: { memory in
                                isPresented = false
                                onSelect(memory)
                            }
                        )
                    }
                }
                .padding(12)
            }
            .frame(width: 300, height: min(360, CGFloat(occurrences.count * 34 + 24)))
            .background(Color.Theme.secondaryBackground)
        }
        .accessibilityLabel("\(occurrences.count) more memories")
    }
}

#endif
