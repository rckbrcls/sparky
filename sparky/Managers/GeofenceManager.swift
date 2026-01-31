//
//  GeofenceManager.swift
//  sparky
//
//  Created by Codex on 13/10/25.
//

import Foundation
import Combine
import CoreLocation
import UserNotifications

@MainActor
final class GeofenceManager: NSObject, ObservableObject {
    enum GeofenceEvent {
        case didEnter(UUID)
        case didExit(UUID)
    }

    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var lastEvent: GeofenceEvent?

    var notificationScheduler: NotificationScheduler?

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

    func sync(memories: [Memory]) {
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else { return }

        // Collect all active location configs
        let locationConfigs: [(Memory, LocationConfig)] = memories
            .filter { $0.status == .active }
            .compactMap { memory -> (Memory, LocationConfig)? in
                guard let config = memory.locationConfig, config.isActive else { return nil }
                guard config.radius > 0 else { return nil }
                return (memory, config)
            }
            .sorted { lhs, rhs in
                (lhs.0.updatedAt ?? Date.distantPast) > (rhs.0.updatedAt ?? Date.distantPast)
            }

        let limitedConfigs = Array(locationConfigs.prefix(maxGeofences))
        let desiredIdentifiers = Set(limitedConfigs.map { identifier(memoryID: $0.0.id, configID: $0.1.id) })

        // Remove stale regions
        for identifier in monitoredIdentifiers.subtracting(desiredIdentifiers) {
            if let region = locationManager.monitoredRegions.first(where: { $0.identifier == identifier }) {
                locationManager.stopMonitoring(for: region)
            }
            monitoredIdentifiers.remove(identifier)
            memoryLookup.removeValue(forKey: identifier)
        }

        // Add new regions
        for (memory, config) in limitedConfigs {
            let identifier = identifier(memoryID: memory.id, configID: config.id)
            if monitoredIdentifiers.contains(identifier) { continue }

            let region = CLCircularRegion(
                center: CLLocationCoordinate2D(latitude: config.latitude, longitude: config.longitude),
                radius: min(config.radius, 1000),
                identifier: identifier
            )
            region.notifyOnEntry = config.event == .onEntry
            region.notifyOnExit = config.event == .onExit

            locationManager.startMonitoring(for: region)
            monitoredIdentifiers.insert(identifier)
            memoryLookup[identifier] = memory.id
        }
    }

    func removeGeofences(for memoryID: UUID) {
        for identifier in monitoredIdentifiers where identifier.contains(memoryID.uuidString) {
            if let region = locationManager.monitoredRegions.first(where: { $0.identifier == identifier }) {
                locationManager.stopMonitoring(for: region)
            }
            monitoredIdentifiers.remove(identifier)
            memoryLookup.removeValue(forKey: identifier)
        }
    }

    private func identifier(memoryID: UUID, configID: UUID) -> String {
        "memory-\(memoryID.uuidString)-location-\(configID.uuidString)"
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

extension GeofenceManager: CLLocationManagerDelegate {
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
