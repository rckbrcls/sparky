//
//  LocationConfig.swift
//  sparky
//
//  Location configuration for memory geofence reminders.
//

import Foundation
import SwiftData

@Model
final class LocationConfig: Identifiable {
    @Attribute(.unique) var id: UUID = UUID()
    var latitude: Double = 0
    var longitude: Double = 0
    var radius: Double = 200
    var name: String?
    var eventRaw: String = LocationEvent.onEntry.rawValue
    var isActive: Bool = true

    // Nested reminder policy (follow-ups after this geofence fires)
    var reminderIsActive: Bool = false
    var reminderIntervalValue: Int = 1
    var reminderIntervalUnitRaw: String = ReminderIntervalUnit.hours.rawValue
    var reminderRepeatCount: Int?
    var reminderStartedAt: Date?

    var memory: Memory?

    init(
        id: UUID = UUID(),
        latitude: Double,
        longitude: Double,
        radius: Double = 200,
        name: String? = nil,
        event: LocationEvent = .onEntry,
        isActive: Bool = true,
        reminder: NestedReminderPolicy = NestedReminderPolicy(),
        memory: Memory? = nil
    ) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
        self.name = name
        self.eventRaw = event.rawValue
        self.isActive = isActive
        self.reminderIsActive = reminder.isActive
        self.reminderIntervalValue = max(1, reminder.intervalValue)
        self.reminderIntervalUnitRaw = reminder.intervalUnit.rawValue
        self.reminderRepeatCount = reminder.repeatCount
        self.reminderStartedAt = reminder.startedAt
        self.memory = memory
    }
}

// MARK: - Computed Properties

extension LocationConfig {
    var event: LocationEvent {
        get { LocationEvent(rawValue: eventRaw) ?? .onEntry }
        set { eventRaw = newValue.rawValue }
    }

    var reminderIntervalUnit: ReminderIntervalUnit {
        get { ReminderIntervalUnit(rawValue: reminderIntervalUnitRaw) ?? .hours }
        set { reminderIntervalUnitRaw = newValue.rawValue }
    }

    var reminder: NestedReminderPolicy {
        get {
            NestedReminderPolicy(
                isActive: reminderIsActive,
                intervalValue: reminderIntervalValue,
                intervalUnit: reminderIntervalUnit,
                repeatCount: reminderRepeatCount,
                startedAt: reminderStartedAt
            )
        }
        set {
            reminderIsActive = newValue.isActive
            reminderIntervalValue = max(1, newValue.intervalValue)
            reminderIntervalUnit = newValue.intervalUnit
            reminderRepeatCount = newValue.repeatCount
            reminderStartedAt = newValue.startedAt
        }
    }

    var hasActiveReminder: Bool {
        isActive && reminderIsActive
    }

    func clearReminderStart() {
        reminderStartedAt = nil
    }
}

// MARK: - Static Factory Methods

extension LocationConfig {
    /// Creates a default location config at Apple Park
    static func createDefault() -> LocationConfig {
        LocationConfig(
            latitude: 37.3349,
            longitude: -122.00902,
            radius: 200,
            name: "Select a location",
            event: .onEntry,
            isActive: true
        )
    }
}
