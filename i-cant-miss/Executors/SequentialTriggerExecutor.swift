//
//  SequentialTriggerExecutor.swift
//  i-cant-miss
//
//  Created by Codex on 13/10/25.
//

import Foundation

/// Executor para triggers sequenciais (preparado para automação futura)
@MainActor
final class SequentialTriggerExecutor: TriggerExecutorProtocol {
    func register(trigger: any TriggerProtocol, for memoryID: UUID) async {
        // TODO: Implementar quando automação sequencial estiver disponível
        guard trigger is SequentialTrigger else { return }
    }

    func unregister(triggerID: UUID, for memoryID: UUID) async {
        // TODO: Implementar quando automação sequencial estiver disponível
    }

    func unregisterAll(for memoryID: UUID) async {
        // TODO: Implementar quando automação sequencial estiver disponível
    }

    func sync(memories: [MemoryModel]) async {
        // TODO: Implementar quando automação sequencial estiver disponível
    }
}
