//
//  LocationGeofencePlanner.swift
//  sparky
//
//  Decides which geofences a set of memories should arm.
//  The iOS executor turns these plans into monitored regions.
//

import Foundation

struct PlannedGeofence: Equatable {
    let identifier: String
    let memoryID: UUID
    let triggerID: UUID
    let latitude: Double
    let longitude: Double
    let radius: Double
    let notifyOnEntry: Bool
    let notifyOnExit: Bool
    let title: String
    let body: String?
    let locationName: String?
}

struct LocationReminderCopy: Equatable {
    let subtitle: String?
    let body: String?
}

enum LocationGeofencePlanner {
    static let maxGeofences = 20
    static let maxRadius: Double = 1000

    static func regions(for memories: [Memory]) -> [PlannedGeofence] {
        memories
            .filter { $0.status == .active }
            .compactMap { memory -> (Memory, LocationConfig)? in
                guard let config = memory.locationConfig, config.isActive, config.radius > 0 else { return nil }
                return (memory, config)
            }
            .sorted { lhs, rhs in
                (lhs.0.updatedAt ?? Date.distantPast) > (rhs.0.updatedAt ?? Date.distantPast)
            }
            .prefix(maxGeofences)
            .map { memory, config in
                PlannedGeofence(
                    identifier: identifier(memoryID: memory.id, triggerID: config.id),
                    memoryID: memory.id,
                    triggerID: config.id,
                    latitude: config.latitude,
                    longitude: config.longitude,
                    radius: min(config.radius, maxRadius),
                    notifyOnEntry: config.event == .onEntry,
                    notifyOnExit: config.event == .onExit,
                    title: memory.title,
                    body: memory.body,
                    locationName: config.name
                )
            }
    }

    static func identifier(memoryID: UUID, triggerID: UUID) -> String {
        "memory-\(memoryID.uuidString)-location-\(triggerID.uuidString)"
    }

    static func validLocationName(_ name: String?) -> String? {
        guard let name, !name.isEmpty, name != "Select a location" else {
            return nil
        }
        return name
    }

    static func reminderCopy(didEnter: Bool, locationName: String?, body: String?) -> LocationReminderCopy {
        let name = validLocationName(locationName)
        let subtitle = name.map { didEnter ? "Arriving at \($0)" : "Leaving \($0)" }
        let resolvedBody: String?
        if let body, !body.isEmpty {
            resolvedBody = body
        } else if name != nil {
            resolvedBody = didEnter
                ? "You have a reminder for this location."
                : "You are leaving the reminder area."
        } else {
            resolvedBody = nil
        }
        return LocationReminderCopy(subtitle: subtitle, body: resolvedBody)
    }
}
