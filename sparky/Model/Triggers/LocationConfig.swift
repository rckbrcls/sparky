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

    var memory: Memory?

    init(
        id: UUID = UUID(),
        latitude: Double,
        longitude: Double,
        radius: Double = 200,
        name: String? = nil,
        event: LocationEvent = .onEntry,
        isActive: Bool = true,
        memory: Memory? = nil
    ) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
        self.name = name
        self.eventRaw = event.rawValue
        self.isActive = isActive
        self.memory = memory
    }
}

// MARK: - Computed Properties

extension LocationConfig {
    var event: LocationEvent {
        get { LocationEvent(rawValue: eventRaw) ?? .onEntry }
        set { eventRaw = newValue.rawValue }
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
