import Foundation
import Testing
@testable import sparky

@MainActor
@Suite("Calendar period series grouping")
struct CalendarPeriodEntriesTests {
    private var calendar: Calendar { Calendar.current }

    @Test("More than two intra-day times collapse into one series")
    func collapsesHourlySeries() async throws {
        let environment = makeEnvironment()
        let fireDate = makeDate(hour: 0, minute: 25)
        let memory = try await makeMemory(
            environment: environment,
            title: "Hourly practice",
            fireDate: fireDate,
            frequency: .hourly,
            occurrenceCount: 6
        )
        let occurrences = occurrences(for: memory, on: fireDate)
        let entries = CalendarPeriodEntries.make(from: occurrences)

        #expect(entries.count == 1)
        guard case .series(let series) = entries[0] else {
            Issue.record("Expected one series row")
            return
        }
        #expect(series.occurrences.count == 6)
        #expect(series.frequencyLabel == "Hourly")
        #expect(series.rangeStart == series.occurrences.first?.occurrenceDate)
        #expect(series.rangeEnd == series.occurrences.last?.occurrenceDate)
        #expect(series.timeRangeLabel.contains("–"))
    }

    @Test("Two intra-day times and other memories stay as separate cards")
    func keepsShortSeriesAndOtherMemoriesSeparate() async throws {
        let environment = makeEnvironment()
        let day = makeDate(hour: 9)
        let hourly = try await makeMemory(
            environment: environment,
            title: "Short hourly",
            fireDate: day,
            frequency: .hourly,
            occurrenceCount: 2
        )
        let single = try await makeMemory(
            environment: environment,
            title: "Once",
            fireDate: makeDate(hour: 9, minute: 30),
            frequency: nil,
            occurrenceCount: nil
        )

        var occurrences = occurrences(for: hourly, on: day)
        occurrences.append(MemoryOccurrence(memory: single, occurrenceDate: makeDate(hour: 9, minute: 30)))
        occurrences.sort { $0.occurrenceDate < $1.occurrenceDate }

        let entries = CalendarPeriodEntries.make(from: occurrences)
        #expect(entries.count == 3)
        #expect(entries.allSatisfy { entry in
            if case .single = entry { return true }
            return false
        })
    }

    @Test("Month display keeps the earliest intra-day time and other memories")
    func collapsesMonthSeriesToEarliestTime() async throws {
        let environment = makeEnvironment()
        let fireDate = makeDate(hour: 9)
        let hourly = try await makeMemory(
            environment: environment,
            title: "Hourly practice",
            fireDate: fireDate,
            frequency: .hourly,
            occurrenceCount: 3
        )
        let single = try await makeMemory(
            environment: environment,
            title: "Once",
            fireDate: makeDate(hour: 11),
            frequency: nil,
            occurrenceCount: nil
        )
        let hourlyOccurrences = occurrences(for: hourly, on: fireDate)
        let once = MemoryOccurrence(memory: single, occurrenceDate: makeDate(hour: 11))
        let chronological = hourlyOccurrences + [once]
        let monthItems = CalendarPeriodEntries.monthItems(from: chronological)

        #expect(monthItems.count == 2)
        #expect(monthItems[0].memory.id == hourly.id)
        #expect(monthItems[0].occurrenceDate == hourlyOccurrences[0].occurrenceDate)
        #expect(monthItems[1].memory.id == single.id)

        let reversed = Array(hourlyOccurrences.reversed()) + [once]
        let reordered = CalendarPeriodEntries.monthItems(from: reversed)
        #expect(reordered.map(\.memory.id) == [hourly.id, single.id])
        #expect(reordered[0].occurrenceDate == hourlyOccurrences[0].occurrenceDate)
    }

    @Test("Minutely times collapse into one series")
    func collapsesMinutelySeries() async throws {
        let environment = makeEnvironment()
        let fireDate = makeDate(hour: 8)
        let memory = try await makeMemory(
            environment: environment,
            title: "Minutely practice",
            fireDate: fireDate,
            frequency: .minutely,
            occurrenceCount: 10
        )
        let entries = CalendarPeriodEntries.make(from: occurrences(for: memory, on: fireDate))

        #expect(entries.count == 1)
        guard case .series(let series) = entries[0] else {
            Issue.record("Expected one series")
            return
        }
        #expect(series.occurrences.count == 10)
        #expect(series.frequencyLabel == "Minutely")
        #expect(series.rangeEnd != series.rangeStart)
    }

    private func makeEnvironment() -> AppEnvironment {
        AppEnvironment(dataController: DataController(inMemory: true))
    }

    private func makeMemory(
        environment: AppEnvironment,
        title: String,
        fireDate: Date,
        frequency: RecurrenceFrequency?,
        occurrenceCount: Int?
    ) async throws -> Memory {
        let rule = frequency.map {
            RecurrenceRule(frequency: $0, interval: 1, occurrenceCount: occurrenceCount)
        }
        return try await environment.memoryService.createMemory(
            from: MemoryDraft(
                title: title,
                scheduleConfig: ScheduleConfigDraft(
                    fireDate: fireDate,
                    startDate: fireDate,
                    recurrenceRule: rule,
                    timeZoneIdentifier: calendar.timeZone.identifier,
                    recurrenceEndType: occurrenceCount == nil ? .never : .afterCount
                )
            )
        )
    }

    private func occurrences(for memory: Memory, on day: Date) -> [MemoryOccurrence] {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        return memory.dates(from: start, to: end).map {
            MemoryOccurrence(memory: memory, occurrenceDate: $0)
        }
    }

    private func makeDate(hour: Int, minute: Int = 0) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components)!
    }
}
