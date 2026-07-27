import Foundation
import Testing
@testable import sparky

@MainActor
@Suite("Desktop calendar occurrence layout")
struct DesktopCalendarOccurrenceLayoutTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    @Test("All-day and timed occurrences remain separate")
    func separatesOccurrenceKinds() {
        let allDay = occurrence(title: "All day", hour: 0, isAllDay: true)
        let timed = occurrence(title: "Timed", hour: 9, isAllDay: false)
        let occurrences = [timed, allDay]

        #expect(
            DesktopCalendarOccurrenceLayout.allDay(in: occurrences).map(\.id)
                == [allDay.id]
        )
        #expect(
            DesktopCalendarOccurrenceLayout.timed(in: occurrences).map(\.id)
                == [timed.id]
        )
    }

    @Test("Simultaneous occurrences are grouped and ordered deterministically")
    func simultaneousGroups() {
        let later = occurrence(title: "Later", hour: 10, minute: 30)
        let beta = occurrence(title: "Beta", hour: 9, minute: 15)
        let alpha = occurrence(title: "Alpha", hour: 9, minute: 15)

        let groups = DesktopCalendarOccurrenceLayout.simultaneousTimedGroups(
            in: [later, beta, alpha],
            calendar: calendar
        )

        #expect(groups.count == 2)
        #expect(groups[0].map(\.memory.title) == ["Alpha", "Beta"])
        #expect(groups[1].map(\.memory.title) == ["Later"])
    }

    private func occurrence(
        title: String,
        hour: Int,
        minute: Int = 0,
        isAllDay: Bool = false
    ) -> MemoryOccurrence {
        let date = calendar.date(
            from: DateComponents(
                year: 2026,
                month: 7,
                day: 27,
                hour: hour,
                minute: minute
            )
        )!
        let memory = Memory(title: title)
        memory.scheduleConfig = ScheduleConfig(
            fireDate: date,
            startDate: date,
            timeZoneIdentifier: calendar.timeZone.identifier,
            isAllDay: isAllDay,
            memory: memory
        )
        return MemoryOccurrence(memory: memory, occurrenceDate: date)
    }
}
