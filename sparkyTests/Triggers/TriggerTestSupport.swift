import Foundation
@testable import sparky

@MainActor
enum TriggerTestSupport {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 1
        return calendar
    }

    static func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int = 0,
        _ minute: Int = 0,
        _ second: Int = 0
    ) -> Date {
        calendar.date(
            from: DateComponents(
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute,
                second: second
            )
        )!
    }

    /// Notification plans keep minute precision, so comparisons drop seconds.
    static func minute(_ date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date))!
    }

    static func adding(_ component: Calendar.Component, _ value: Int, to date: Date) -> Date {
        calendar.date(byAdding: component, value: value, to: date)!
    }

    static func weekdayMask(_ days: Int...) -> Int16 {
        days.reduce(Int16(0)) { $0 | Int16(1 << $1) }
    }

    static func schedule(
        id: UUID = UUID(),
        fireDate: Date?,
        recurrence: RecurrenceRule? = nil,
        weekdayMask: Int16 = 0,
        isActive: Bool = true,
        focusEnabled: Bool = false
    ) -> ScheduleConfig {
        let endType: RecurrenceEndType
        if recurrence?.occurrenceCount != nil {
            endType = .afterCount
        } else if recurrence?.endDate != nil {
            endType = .untilDate
        } else {
            endType = .never
        }
        return ScheduleConfig(
            id: id,
            fireDate: fireDate,
            startDate: fireDate,
            recurrenceRule: recurrence,
            timeZoneIdentifier: calendar.timeZone.identifier,
            weekdayMask: weekdayMask,
            isActive: isActive,
            recurrenceEndType: endType,
            focusEnabled: focusEnabled
        )
    }

    static func memory(
        id: UUID = UUID(),
        title: String = "Remember",
        body: String? = "Bring the notes",
        status: MemoryStatus = .active,
        updatedAt: Date? = nil,
        schedule: ScheduleConfig? = nil,
        location: LocationConfig? = nil
    ) -> Memory {
        Memory(
            id: id,
            title: title,
            body: body,
            statusRaw: status.rawValue,
            updatedAt: updatedAt,
            scheduleConfig: schedule,
            locationConfig: location
        )
    }

    static func location(
        id: UUID = UUID(),
        latitude: Double = 37.33,
        longitude: Double = -122.01,
        radius: Double = 200,
        name: String? = "Office",
        event: LocationEvent = .onEntry,
        isActive: Bool = true
    ) -> LocationConfig {
        LocationConfig(
            id: id,
            latitude: latitude,
            longitude: longitude,
            radius: radius,
            name: name,
            event: event,
            isActive: isActive
        )
    }

    static let fire = date(2026, 10, 5, 9, 30, 15)
    static let now = date(2026, 10, 4, 12, 0, 0)
}
