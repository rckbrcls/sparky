//
//  TriggerExecutorCoordinator.swift
//  sparky
//
//  Created by Codex on 13/10/25.
//

import Foundation

/// Coordinator that manages trigger executors.
/// Location/geofence execution is optional (iOS only in v1 multiplatform).
@MainActor
final class TriggerExecutorCoordinator {
    private let scheduledExecutor: ScheduledTriggerExecutor
    #if os(iOS)
    private let locationExecutor: LocationTriggerExecutor
    #endif

    var scheduled: ScheduledTriggerExecutor { scheduledExecutor }

    #if os(iOS)
    var location: LocationTriggerExecutor { locationExecutor }
    #endif

    /// Whether live location/geofence monitoring is available on this build.
    var supportsLocationExecution: Bool {
        PlatformCapabilities.current.supportsLocationExecution
    }

    init(settings: SettingsStore) {
        self.scheduledExecutor = ScheduledTriggerExecutor(settings: settings)
        #if os(iOS)
        self.locationExecutor = LocationTriggerExecutor(settings: settings)
        #endif
    }

    /// Remove a specific trigger by ID
    func unregister(triggerID: UUID, for memoryID: UUID) async {
        await scheduledExecutor.unregister(triggerID: triggerID, for: memoryID)
        #if os(iOS)
        await locationExecutor.unregister(triggerID: triggerID, for: memoryID)
        #endif
    }

    /// Remove all triggers for a memory
    func unregisterAll(for memoryID: UUID) async {
        await scheduledExecutor.unregisterAll(for: memoryID)
        #if os(iOS)
        await locationExecutor.unregisterAll(for: memoryID)
        #endif
    }

    /// Sync all triggers from a list of memories
    func sync(memories: [Memory]) async {
        await scheduledExecutor.sync(memories: memories)
        #if os(iOS)
        await locationExecutor.sync(memories: memories)
        #endif
    }

    /// Sync triggers for a single memory
    func sync(memory: Memory) async {
        await sync(memories: [memory])
    }
}
