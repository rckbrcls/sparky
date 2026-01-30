//
//  LocationTriggerExecutor.swift
//  i-cant-miss
//
//  Created by Codex on 13/10/25.
//

import Foundation
import Combine
import CoreLocation
import UserNotifications

@MainActor
final class LocationTriggerExecutor: NSObject, ObservableObject, TriggerExecutorProtocol {
    enum GeofenceEvent {
        case didEnter(UUID)
        case didExit(UUID)
    }

    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var lastEvent: GeofenceEvent?

    private let locationManager = CLLocationManager()
    private var monitoredIdentifiers: Set<String> = []
    private var memoryLookup: [String: UUID] = [:]
    private let maxGeofences = 20

    override init() {
        authorizationStatus = locationManager.authorizationStatus
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.pausesLocationUpdatesAutomatically = true
    }

    func requestAuthorization(always: Bool = true) {
        if always {
            locationManager.requestAlwaysAuthorization()
        } else {
            locationManager.requestWhenInUseAuthorization()
        }
    }

    func register(trigger: any TriggerProtocol, for memoryID: UUID) async {
        guard let location = trigger as? LocationTrigger else { return }
        guard location.isActive else {
            await unregister(triggerID: trigger.id, for: memoryID)
            return
        }
        // A implementação completa será feita no sync
    }

    func unregister(triggerID: UUID, for memoryID: UUID) async {
        let identifier = identifier(memoryID: memoryID, triggerID: triggerID)
        if let region = locationManager.monitoredRegions.first(where: { $0.identifier == identifier }) {
            locationManager.stopMonitoring(for: region)
        }
        monitoredIdentifiers.remove(identifier)
        memoryLookup.removeValue(forKey: identifier)
    }

    func unregisterAll(for memoryID: UUID) async {
        for identifier in monitoredIdentifiers where identifier.contains(memoryID.uuidString) {
            if let region = locationManager.monitoredRegions.first(where: { $0.identifier == identifier }) {
                locationManager.stopMonitoring(for: region)
            }
            monitoredIdentifiers.remove(identifier)
            memoryLookup.removeValue(forKey: identifier)
        }
    }

    func sync(memories: [Memory]) async {
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else { return }
        let locationTriggers = memories
            .filter { $0.status == .active }
            .flatMap { memory in
                memory.triggers
                    .filter { $0.type == .location }
                    .compactMap { trigger -> (Memory, MemoryTriggerModel)? in
                        guard let location = trigger.location else { return nil }
                        guard location.radius > 0 else { return nil }
                        return (memory, trigger)
                    }
            }
            .sorted { lhs, rhs in
                (lhs.0.updatedAt ?? Date.distantPast) > (rhs.0.updatedAt ?? Date.distantPast)
            }
            .prefix(maxGeofences)

        let desiredIdentifiers = Set(locationTriggers.map { identifier(memoryID: $0.0.id, triggerID: $0.1.id) })

        // Remove stale regions
        for identifier in monitoredIdentifiers.subtracting(desiredIdentifiers) {
            if let region = locationManager.monitoredRegions.first(where: { $0.identifier == identifier }) {
                locationManager.stopMonitoring(for: region)
            }
            monitoredIdentifiers.remove(identifier)
            memoryLookup.removeValue(forKey: identifier)
        }

        // Add new regions
        for (memory, trigger) in locationTriggers {
            let identifier = identifier(memoryID: memory.id, triggerID: trigger.id)
            if monitoredIdentifiers.contains(identifier) { continue }
            guard let location = trigger.location else { continue }

            let region = CLCircularRegion(center: CLLocationCoordinate2D(latitude: location.latitude,
                                                                         longitude: location.longitude),
                                          radius: min(location.radius, 1000),
                                          identifier: identifier)
            region.notifyOnEntry = location.event == LocationEvent.onEntry
            region.notifyOnExit = location.event == LocationEvent.onExit

            locationManager.startMonitoring(for: region)
            monitoredIdentifiers.insert(identifier)
            memoryLookup[identifier] = memory.id
        }
    }

    private func identifier(memoryID: UUID, triggerID: UUID) -> String {
        "memory-\(memoryID.uuidString)-location-\(triggerID.uuidString)"
    }

    private func handle(region: CLRegion, didEnter: Bool) {
        guard let memoryID = memoryLookup[region.identifier] else { return }
        lastEvent = didEnter ? .didEnter(memoryID) : .didExit(memoryID)
        Task {
            let content = UNMutableNotificationContent()
            content.title = didEnter ? "You're at the right place" : "Leaving the area"
            content.body = "Reminder triggered by location."
            content.sound = .default
            let request = UNNotificationRequest(identifier: "geofence-\(UUID().uuidString)",
                                                content: content,
                                                trigger: nil)
            try? await UNUserNotificationCenter.current().add(request)
        }
    }
}

extension LocationTriggerExecutor: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            if authorizationStatus == .authorizedAlways {
                manager.startUpdatingLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        Task { @MainActor in
            handle(region: region, didEnter: true)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        Task { @MainActor in
            handle(region: region, didEnter: false)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("Monitoring failed: \(error.localizedDescription)")
    }
}
