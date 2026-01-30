//
//  MemoryTriggerLocation.swift
//  sparky
//

import Foundation
import SwiftData

@Model
final class MemoryTriggerLocation: Identifiable {
    @Attribute(.unique) var id: UUID
    var latitude: Double
    var longitude: Double
    var radius: Double
    var name: String?
    var eventRaw: String = LocationEvent.onEntry.rawValue

    var trigger: MemoryTriggerModel?

    init(
        id: UUID = UUID(),
        latitude: Double,
        longitude: Double,
        radius: Double,
        name: String? = nil,
        event: LocationEvent = .onEntry,
        trigger: MemoryTriggerModel? = nil
    ) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
        self.name = name
        self.eventRaw = event.rawValue
        self.trigger = trigger
    }
}

extension MemoryTriggerLocation {
    var event: LocationEvent {
        get { LocationEvent(rawValue: eventRaw) ?? .onEntry }
        set { eventRaw = newValue.rawValue }
    }
}
