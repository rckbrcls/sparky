#if os(iOS)
//
//  LocationTriggerExecutor.swift
//  sparky
//
//  Created by Codex on 13/10/25.
//

import Foundation
import Combine
import CoreLocation
import UserNotifications
import os

@MainActor
final class LocationTriggerExecutor: NSObject, ObservableObject, TriggerExecutorProtocol {
    nonisolated private static let logger = Logger(subsystem: "sparky", category: "LocationTriggerExecutor")
    enum GeofenceEvent {
        case didEnter(UUID)
        case didExit(UUID)
    }

    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var lastEvent: GeofenceEvent?

    private let locationManager = CLLocationManager()
    private let settings: SettingsStore
    private var monitoredIdentifiers: Set<String> = []
    private var memoryLookup: [String: MonitoredMemoryInfo] = [:]
    @Published private(set) var activeGeofenceCount: Int = 0
    static let maxGeofences = 20

    init(settings: SettingsStore) {
        self.settings = settings
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

    func unregister(triggerID: UUID, for memoryID: UUID) async {
        let identifier = identifier(memoryID: memoryID, triggerID: triggerID)
        if let region = locationManager.monitoredRegions.first(where: { $0.identifier == identifier }) {
            locationManager.stopMonitoring(for: region)
        }
        monitoredIdentifiers.remove(identifier)
        memoryLookup.removeValue(forKey: identifier)
        activeGeofenceCount = monitoredIdentifiers.count
    }

    func unregisterAll(for memoryID: UUID) async {
        for identifier in monitoredIdentifiers where identifier.contains(memoryID.uuidString) {
            if let region = locationManager.monitoredRegions.first(where: { $0.identifier == identifier }) {
                locationManager.stopMonitoring(for: region)
            }
            monitoredIdentifiers.remove(identifier)
            memoryLookup.removeValue(forKey: identifier)
        }
        activeGeofenceCount = monitoredIdentifiers.count
    }

    func isMonitoringMemory(_ memoryID: UUID) -> Bool {
        monitoredIdentifiers.contains { $0.contains(memoryID.uuidString) }
    }

    func sync(memories: [Memory]) async {
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else { return }
        let locationConfigs: [(Memory, LocationConfig)] = memories
            .filter { $0.status == .active }
            .compactMap { memory in
                guard let config = memory.locationConfig, config.isActive, config.radius > 0 else { return nil }
                return (memory, config)
            }
            .sorted { lhs, rhs in
                (lhs.0.updatedAt ?? Date.distantPast) > (rhs.0.updatedAt ?? Date.distantPast)
            }
            .prefix(Self.maxGeofences)
            .map { $0 }

        let desiredIdentifiers = Set(locationConfigs.map { identifier(memoryID: $0.0.id, triggerID: $0.1.id) })

        // Remove stale regions
        for identifier in monitoredIdentifiers.subtracting(desiredIdentifiers) {
            if let region = locationManager.monitoredRegions.first(where: { $0.identifier == identifier }) {
                locationManager.stopMonitoring(for: region)
            }
            monitoredIdentifiers.remove(identifier)
            memoryLookup.removeValue(forKey: identifier)
        }

        // Add new regions
        for (memory, config) in locationConfigs {
            let id = identifier(memoryID: memory.id, triggerID: config.id)

            // Always update memory info so notifications stay current
            memoryLookup[id] = MonitoredMemoryInfo(
                memoryID: memory.id,
                title: memory.title,
                body: memory.body,
                locationName: config.name
            )

            if monitoredIdentifiers.contains(id) { continue }

            let region = CLCircularRegion(center: CLLocationCoordinate2D(latitude: config.latitude,
                                                                         longitude: config.longitude),
                                          radius: min(config.radius, 1000),
                                          identifier: id)
            region.notifyOnEntry = config.event == .onEntry
            region.notifyOnExit = config.event == .onExit

            locationManager.startMonitoring(for: region)
            monitoredIdentifiers.insert(id)
        }

        activeGeofenceCount = monitoredIdentifiers.count
    }

    // MARK: - Private

    private func identifier(memoryID: UUID, triggerID: UUID) -> String {
        "memory-\(memoryID.uuidString)-location-\(triggerID.uuidString)"
    }

    private func handle(region: CLRegion, didEnter: Bool) {
        guard let info = memoryLookup[region.identifier] else { return }
        lastEvent = didEnter ? .didEnter(info.memoryID) : .didExit(info.memoryID)

        Task {
            let content = UNMutableNotificationContent()
            content.title = info.title

            let locationName = info.validLocationName
            if let locationName {
                content.subtitle = didEnter
                    ? "Arriving at \(locationName)"
                    : "Leaving \(locationName)"
            }

            if let body = info.body, !body.isEmpty {
                content.body = body
            } else if locationName != nil {
                content.body = didEnter
                    ? "You have a reminder for this location."
                    : "You are leaving the reminder area."
            }

            content.sound = settings.notificationSoundEnabled ? .default : nil
            content.categoryIdentifier = NotificationCategoryID.reminderActions
            content.threadIdentifier = info.memoryID.uuidString
            content.userInfo = [NotificationUserInfoKey.memoryID: info.memoryID.uuidString]

            let request = UNNotificationRequest(
                identifier: "geofence-\(UUID().uuidString)",
                content: content,
                trigger: nil
            )
            try? await UNUserNotificationCenter.current().add(request)
        }
    }
}

// MARK: - MonitoredMemoryInfo

private extension LocationTriggerExecutor {
    struct MonitoredMemoryInfo {
        let memoryID: UUID
        let title: String
        let body: String?
        let locationName: String?

        var validLocationName: String? {
            guard let name = locationName,
                  !name.isEmpty,
                  name != "Select a location" else {
                return nil
            }
            return name
        }
    }
}

// MARK: - CLLocationManagerDelegate

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
        Self.logger.error("Geofence monitoring failed: \(error.localizedDescription)")
    }
}

#endif
