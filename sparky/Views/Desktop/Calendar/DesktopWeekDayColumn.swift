#if os(macOS)

import SwiftUI

struct DesktopWeekDayColumn: View {
    let day: Date
    let occurrences: [MemoryOccurrence]
    let hourHeight: CGFloat
    let onSelect: (Memory) -> Void

    private let calendar = Calendar.current

    var body: some View {
        let groups = DesktopCalendarOccurrenceLayout.simultaneousTimedGroups(
            in: occurrences,
            calendar: calendar
        )

        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                ForEach(0..<24, id: \.self) { hour in
                    DesktopCalendarHourCell(
                        date: date(at: hour),
                        height: hourHeight
                    )
                }
            }

            ForEach(groups.indices, id: \.self) { groupIndex in
                let group = groups[groupIndex]

                HStack(spacing: 2) {
                    ForEach(Array(group.prefix(2))) { occurrence in
                        DesktopCalendarEventPill(
                            occurrence: occurrence,
                            style: .timed,
                            onSelect: onSelect
                        )
                    }

                    if group.count > 2 {
                        DesktopCalendarOverflowButton(
                            occurrences: Array(group.dropFirst(2)),
                            onSelect: onSelect
                        )
                    }
                }
                .padding(.horizontal, 4)
                .offset(y: yOffset(for: group[0]))
                .zIndex(Double(groupIndex + 1))
            }
        }
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.Theme.separator)
                .frame(width: 1)
        }
    }

    private func date(at hour: Int) -> Date {
        calendar.date(
            bySettingHour: hour,
            minute: 0,
            second: 0,
            of: day
        ) ?? day
    }

    private func yOffset(for occurrence: MemoryOccurrence) -> CGFloat {
        let components = calendar.dateComponents(
            [.hour, .minute],
            from: occurrence.occurrenceDate
        )
        let minutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        return CGFloat(minutes) / 60 * hourHeight + 3
    }
}

#endif
