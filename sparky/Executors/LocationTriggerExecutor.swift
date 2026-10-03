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
    static let maxGeofences = LocationGeofencePlanner.maxGeofences

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
        let identifier = LocationGeofencePlanner.identifier(memoryID: memoryID, triggerID: triggerID)
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
        let regions = LocationGeofencePlanner.regions(for: memories)
        let desiredIdentifiers = Set(regions.map(\.identifier))

        // Remove stale regions
        for identifier in monitoredIdentifiers.subtracting(desiredIdentifiers) {
            if let region = locationManager.monitoredRegions.first(where: { $0.identifier == identifier }) {
                locationManager.stopMonitoring(for: region)
            }
            monitoredIdentifiers.remove(identifier)
            memoryLookup.removeValue(forKey: identifier)
        }

        // Add new regions
        for plan in regions {
            // Always update memory info so notifications stay current
            memoryLookup[plan.identifier] = MonitoredMemoryInfo(
                memoryID: plan.memoryID,
                title: plan.title,
                body: plan.body,
                locationName: plan.locationName
            )

            if monitoredIdentifiers.contains(plan.identifier) { continue }

            let region = CLCircularRegion(
                center: CLLocationCoordinate2D(latitude: plan.latitude, longitude: plan.longitude),
                radius: plan.radius,
                identifier: plan.identifier
            )
            region.notifyOnEntry = plan.notifyOnEntry
            region.notifyOnExit = plan.notifyOnExit

            locationManager.startMonitoring(for: region)
            monitoredIdentifiers.insert(plan.identifier)
        }

        activeGeofenceCount = monitoredIdentifiers.count
    }

    // MARK: - Private

    private func handle(region: CLRegion, didEnter: Bool) {
        guard let info = memoryLookup[region.identifier] else { return }
        lastEvent = didEnter ? .didEnter(info.memoryID) : .didExit(info.memoryID)

        Task {
            let content = UNMutableNotificationContent()
            content.title = info.title

            let copy = LocationGeofencePlanner.reminderCopy(
                didEnter: didEnter,
                locationName: info.locationName,
                body: info.body
            )
            if let subtitle = copy.subtitle {
                content.subtitle = subtitle
            }
            if let body = copy.body {
                content.body = body
            }

            content.sound = settings.notificationSound.notificationSound
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
