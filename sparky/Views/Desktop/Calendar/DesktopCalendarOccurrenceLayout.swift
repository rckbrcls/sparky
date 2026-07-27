import Foundation

struct DesktopCalendarOccurrenceLayout {
    static func allDay(
        in occurrences: [MemoryOccurrence]
    ) -> [MemoryOccurrence] {
        occurrences
            .filter(\.isAllDay)
            .sorted { lhs, rhs in
                stableOrder(lhs, rhs)
            }
    }

    static func timed(
        in occurrences: [MemoryOccurrence]
    ) -> [MemoryOccurrence] {
        occurrences
            .filter { !$0.isAllDay }
            .sorted { lhs, rhs in
                chronologicalOrder(lhs, rhs)
            }
    }

    static func simultaneousTimedGroups(
        in occurrences: [MemoryOccurrence],
        calendar: Calendar = .current
    ) -> [[MemoryOccurrence]] {
        let timedOccurrences = timed(in: occurrences)
        let groups = Dictionary(grouping: timedOccurrences) { occurrence in
            calendar.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: occurrence.occurrenceDate
            )
        }

        return groups.values
            .map { group in
                group.sorted { lhs, rhs in
                    stableOrder(lhs, rhs)
                }
            }
            .sorted { lhs, rhs in
                guard let leftDate = lhs.first?.occurrenceDate,
                      let rightDate = rhs.first?.occurrenceDate else {
                    return !lhs.isEmpty
                }
                return leftDate < rightDate
            }
    }

    private static func chronologicalOrder(
        _ lhs: MemoryOccurrence,
        _ rhs: MemoryOccurrence
    ) -> Bool {
        if lhs.occurrenceDate != rhs.occurrenceDate {
            return lhs.occurrenceDate < rhs.occurrenceDate
        }
        return stableOrder(lhs, rhs)
    }

    private static func stableOrder(
        _ lhs: MemoryOccurrence,
        _ rhs: MemoryOccurrence
    ) -> Bool {
        let titleOrder = lhs.memory.title.localizedCaseInsensitiveCompare(
            rhs.memory.title
        )
        if titleOrder != .orderedSame {
            return titleOrder == .orderedAscending
        }
        return lhs.id < rhs.id
    }
}
