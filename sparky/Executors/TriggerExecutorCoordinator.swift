//
//  TriggerExecutorCoordinator.swift
//  sparky
//
//  Created by Codex on 13/10/25.
//

import Foundation

/// Coordenador que gerencia todos os executores de triggers
@MainActor
final class TriggerExecutorCoordinator {
    private let scheduledExecutor: ScheduledTriggerExecutor
    private let locationExecutor: LocationTriggerExecutor
    var scheduled: ScheduledTriggerExecutor { scheduledExecutor }
    var location: LocationTriggerExecutor { locationExecutor }

    init(settings: SettingsStore) {
        self.scheduledExecutor = ScheduledTriggerExecutor(settings: settings)
        self.locationExecutor = LocationTriggerExecutor()
    }

    /// Remove todos os triggers de uma memória
    func unregisterAll(for memoryID: UUID) async {
        await scheduledExecutor.unregisterAll(for: memoryID)
        await locationExecutor.unregisterAll(for: memoryID)
    }

    /// Sincroniza todos os triggers de uma lista de memórias
    func sync(memories: [Memory]) async {
        await scheduledExecutor.sync(memories: memories)
        await locationExecutor.sync(memories: memories)
    }

    /// Atualiza triggers de uma memória específica
    func sync(memory: Memory) async {
        await sync(memories: [memory])
    }
}
