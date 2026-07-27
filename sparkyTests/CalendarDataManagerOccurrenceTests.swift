import Foundation
import Testing
@testable import sparky

@MainActor
@Suite("Calendar occurrence queries")
struct CalendarDataManagerOccurrenceTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    @Test("Range queries preserve repeated intraday occurrences")
    func preservesRepeatedOccurrences() async throws {
        let environment = AppEnvironment(
            dataController: DataController(inMemory: true)
        )
        let firstFire = makeDate(hour: 9)
        let memory = try await environment.memoryService.createMemory(
            from: MemoryDraft(
                title: "Hourly practice",
                scheduleConfig: ScheduleConfigDraft(
                    fireDate: firstFire,
                    startDate: firstFire,
                    recurrenceRule: RecurrenceRule(
                        frequency: .hourly,
                        interval: 1,
                        occurrenceCount: 3
                    ),
                    timeZoneIdentifier: calendar.timeZone.identifier,
                    recurrenceEndType: .afterCount
                )
            )
        )
        let manager = CalendarDataManager(
            memoryService: environment.memoryService
        )
        manager.ensureMonthLoaded(firstFire)

        let dayStart = calendar.startOfDay(for: firstFire)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        let occurrences = manager.occurrences(from: dayStart, to: dayEnd)

        #expect(occurrences.count == 3)
        #expect(occurrences.allSatisfy { $0.memory.id == memory.id })
        #expect(Set(occurrences.map(\.id)).count == 3)
        #expect(occurrences.map { calendar.component(.hour, from: $0.occurrenceDate) } == [9, 10, 11])
    }

    private func makeDate(hour: Int) -> Date {
        calendar.date(
            from: DateComponents(
                year: 2026,
                month: 7,
                day: 27,
                hour: hour
            )
        )!
    }
}
