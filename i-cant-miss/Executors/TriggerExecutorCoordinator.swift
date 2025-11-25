//
//  TriggerExecutorCoordinator.swift
//  i-cant-miss
//
//  Created by Codex on 13/10/25.
//

import Foundation

/// Coordenador que gerencia todos os executores de triggers
@MainActor
final class TriggerExecutorCoordinator {
    private let scheduledExecutor: ScheduledTriggerExecutor
    private let locationExecutor: LocationTriggerExecutor
    private let personExecutor: PersonTriggerExecutor
    private let sequentialExecutor: SequentialTriggerExecutor

    var scheduled: ScheduledTriggerExecutor { scheduledExecutor }
    var location: LocationTriggerExecutor { locationExecutor }

    init(settings: SettingsStore) {
        self.scheduledExecutor = ScheduledTriggerExecutor(settings: settings)
        self.locationExecutor = LocationTriggerExecutor()
        self.personExecutor = PersonTriggerExecutor()
        self.sequentialExecutor = SequentialTriggerExecutor()
    }

    /// Registra um trigger específico
    func register(trigger: any TriggerProtocol, for memory: MemoryModel) async {
        switch trigger.type {
        case .scheduled:
            await scheduledExecutor.register(trigger: trigger, for: memory)
        case .location:
            await locationExecutor.register(trigger: trigger, for: memory.id)
        case .person:
            await personExecutor.register(trigger: trigger, for: memory.id)
        case .sequential:
            await sequentialExecutor.register(trigger: trigger, for: memory.id)
        }
    }

    /// Remove um trigger específico
    func unregister(triggerID: UUID, triggerType: MemoryTriggerType, for memoryID: UUID) async {
        switch triggerType {
        case .scheduled:
            await scheduledExecutor.unregister(triggerID: triggerID, for: memoryID)
        case .location:
            await locationExecutor.unregister(triggerID: triggerID, for: memoryID)
        case .person:
            await personExecutor.unregister(triggerID: triggerID, for: memoryID)
        case .sequential:
            await sequentialExecutor.unregister(triggerID: triggerID, for: memoryID)
        }
    }

    /// Remove todos os triggers de uma memória
    func unregisterAll(for memoryID: UUID) async {
        await scheduledExecutor.unregisterAll(for: memoryID)
        await locationExecutor.unregisterAll(for: memoryID)
        await personExecutor.unregisterAll(for: memoryID)
        await sequentialExecutor.unregisterAll(for: memoryID)
    }

    /// Sincroniza todos os triggers de uma lista de memórias
    func sync(memories: [MemoryModel]) async {
        await scheduledExecutor.sync(memories: memories)
        await locationExecutor.sync(memories: memories)
        await personExecutor.sync(memories: memories)
        await sequentialExecutor.sync(memories: memories)
    }

    /// Atualiza triggers de uma memória específica
    func sync(memory: MemoryModel) async {
        await sync(memories: [memory])
    }
}
