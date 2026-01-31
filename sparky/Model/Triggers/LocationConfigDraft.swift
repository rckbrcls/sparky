//
//  LocationConfigDraft.swift
//  sparky
//
//  In-memory draft for editing location configuration in UI.
//

import Foundation

struct LocationConfigDraft: Identifiable, Hashable {
    let id: UUID
    var latitude: Double
    var longitude: Double
    var radius: Double
    var name: String?
    var event: LocationEvent
    var isActive: Bool

    init(
        id: UUID = UUID(),
        latitude: Double = 37.3349,
        longitude: Double = -122.00902,
        radius: Double = 200,
        name: String? = nil,
        event: LocationEvent = .onEntry,
        isActive: Bool = true
    ) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
        self.name = name
        self.event = event
        self.isActive = isActive
    }

    static func == (lhs: LocationConfigDraft, rhs: LocationConfigDraft) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Conversions

extension LocationConfigDraft {
    /// Converts draft to persistent model
    func toModel(memory: Memory? = nil) -> LocationConfig {
        LocationConfig(
            id: id,
            latitude: latitude,
            longitude: longitude,
            radius: radius,
            name: name,
            event: event,
            isActive: isActive,
            memory: memory
        )
    }

    /// Creates draft from persistent model
    static func from(_ model: LocationConfig) -> LocationConfigDraft {
        LocationConfigDraft(
            id: model.id,
            latitude: model.latitude,
            longitude: model.longitude,
            radius: model.radius,
            name: model.name,
            event: model.event,
            isActive: model.isActive
        )
    }

    /// Creates a default draft at Apple Park
    static func createDefault() -> LocationConfigDraft {
        LocationConfigDraft(
            latitude: 37.3349,
            longitude: -122.00902,
            radius: 200,
            name: "Select a location",
            event: .onEntry,
            isActive: true
        )
    }
}
