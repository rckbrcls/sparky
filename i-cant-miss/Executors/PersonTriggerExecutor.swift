//
//  PersonTriggerExecutor.swift
//  i-cant-miss
//
//  Created by Codex on 13/10/25.
//

import Foundation

/// Executor para triggers de pessoa (preparado para futuras integrações)
@MainActor
final class PersonTriggerExecutor: TriggerExecutorProtocol {
    func register(trigger: any TriggerProtocol, for memoryID: UUID) async {
        // TODO: Implementar quando APIs nativas de contatos estiverem disponíveis
        guard trigger is PersonTrigger else { return }
    }

    func unregister(triggerID: UUID, for memoryID: UUID) async {
        // TODO: Implementar quando APIs nativas de contatos estiverem disponíveis
    }

    func unregisterAll(for memoryID: UUID) async {
        // TODO: Implementar quando APIs nativas de contatos estiverem disponíveis
    }

    func sync(memories: [MemoryModel]) async {
        // TODO: Implementar quando APIs nativas de contatos estiverem disponíveis
    }
}
