//
//  CalendarPeriodEntries.swift
//  sparky
//

import Foundation

enum CalendarPeriodEntry: Identifiable {
    case single(MemoryOccurrence)
    case series(CalendarIntraDaySeries)

    var id: String {
        switch self {
        case .single(let occurrence):
            return occurrence.id
        case .series(let series):
            return "series-\(series.id)"
        }
    }
}

struct CalendarIntraDaySeries: Identifiable {
    let occurrences: [MemoryOccurrence]

    var id: String {
        memory.id.uuidString
    }

    var memory: Memory {
        occurrences[0].memory
    }

    var rangeStart: Date? {
        occurrences.first?.occurrenceDate
    }

    var rangeEnd: Date? {
        occurrences.last?.occurrenceDate
    }

    var frequencyLabel: String {
        guard let recurrence = memory.scheduleConfig?.recurrenceRule else { return "" }
        switch recurrence.frequency {
        case .hourly:
            return recurrence.interval > 1 ? "Every \(recurrence.interval) hours" : "Hourly"
        case .minutely:
            return recurrence.interval > 1 ? "Every \(recurrence.interval) min" : "Minutely"
        default:
            return recurrence.frequency.displayName
        }
    }

    var timeRangeLabel: String {
        guard let first = rangeStart else { return "" }
        let start = first.formatted(date: .omitted, time: .shortened)
        guard let last = rangeEnd, occurrences.count > 1 else {
            return start
        }
        let end = last.formatted(date: .omitted, time: .shortened)
        guard end != start else { return start }
        return "\(start)–\(end)"
    }
}

enum CalendarPeriodEntries {
    static func make(from occurrences: [MemoryOccurrence]) -> [CalendarPeriodEntry] {
        let seriesIDs = seriesMemoryIDs(in: occurrences)
        var emittedSeries = Set<Memory.ID>()
        var entries: [CalendarPeriodEntry] = []

        for occurrence in occurrences {
            let memoryID = occurrence.memory.id
            if seriesIDs.contains(memoryID) {
                guard emittedSeries.insert(memoryID).inserted else { continue }
                let grouped = occurrences.filter { $0.memory.id == memoryID }
                entries.append(.series(CalendarIntraDaySeries(occurrences: grouped)))
            } else {
                entries.append(.single(occurrence))
            }
        }

        return entries
    }

    static func monthItems(from occurrences: [MemoryOccurrence]) -> [MemoryOccurrence] {
        var earliestIndex: [Memory.ID: Int] = [:]
        var earliestDate: [Memory.ID: Date] = [:]

        for (index, occurrence) in occurrences.enumerated() where occurrence.memory.hasIntraDayRecurrence {
            let memoryID = occurrence.memory.id
            if let current = earliestDate[memoryID], occurrence.occurrenceDate >= current {
                continue
            }
            earliestDate[memoryID] = occurrence.occurrenceDate
            earliestIndex[memoryID] = index
        }

        return occurrences.enumerated().compactMap { index, occurrence in
            guard occurrence.memory.hasIntraDayRecurrence else { return occurrence }
            return earliestIndex[occurrence.memory.id] == index ? occurrence : nil
        }
    }

    private static func seriesMemoryIDs(in occurrences: [MemoryOccurrence]) -> Set<Memory.ID> {
        var counts: [Memory.ID: Int] = [:]
        for occurrence in occurrences where occurrence.memory.hasIntraDayRecurrence {
            counts[occurrence.memory.id, default: 0] += 1
        }
        return Set(counts.compactMap { memoryID, count in
            count > 2 ? memoryID : nil
        })
    }
}
