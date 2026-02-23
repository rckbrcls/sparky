//
//  TriggerExecutorCoordinator.swift
//  sparky
//
//  Created by Codex on 13/10/25.
//

import Foundation

/// Coordinator that manages all trigger executors
@MainActor
final class TriggerExecutorCoordinator {
    private let scheduledExecutor: ScheduledTriggerExecutor
    private let locationExecutor: LocationTriggerExecutor
    private let reminderExecutor: ReminderTriggerExecutor
    private weak var memoryService: MemoryService?
    var scheduled: ScheduledTriggerExecutor { scheduledExecutor }
    var location: LocationTriggerExecutor { locationExecutor }
    var reminder: ReminderTriggerExecutor { reminderExecutor }

    init(settings: SettingsStore, memoryService: MemoryService? = nil) {
        self.scheduledExecutor = ScheduledTriggerExecutor(settings: settings)
        self.locationExecutor = LocationTriggerExecutor(settings: settings)
        self.reminderExecutor = ReminderTriggerExecutor(settings: settings)
        self.memoryService = memoryService

        self.locationExecutor.onPrimaryTriggerFired = { [weak self] memoryID, date, source in
            guard let self, let memoryService = self.memoryService else { return }
            Task {
                await memoryService.markPrimaryTriggerFired(memoryID: memoryID, at: date, source: source)
            }
        }
    }

    /// Remove a specific trigger by ID
    func unregister(triggerID: UUID, for memoryID: UUID) async {
        await scheduledExecutor.unregister(triggerID: triggerID, for: memoryID)
        await locationExecutor.unregister(triggerID: triggerID, for: memoryID)
        await reminderExecutor.unregister(triggerID: triggerID, for: memoryID)
    }

    /// Remove all triggers for a memory
    func unregisterAll(for memoryID: UUID) async {
        await scheduledExecutor.unregisterAll(for: memoryID)
        await locationExecutor.unregisterAll(for: memoryID)
        await reminderExecutor.unregisterAll(for: memoryID)
    }

    /// Sync all triggers from a list of memories
    func sync(memories: [Memory]) async {
        await scheduledExecutor.sync(memories: memories)
        await locationExecutor.sync(memories: memories)
        await reminderExecutor.sync(memories: memories)
    }

    /// Sync triggers for a single memory
    func sync(memory: Memory) async {
        await sync(memories: [memory])
    }
}
