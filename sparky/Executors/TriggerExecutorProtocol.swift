//
//  TriggerExecutorProtocol.swift
//  sparky
//
//  Created by Codex on 13/10/25.
//

import Foundation

/// Protocolo para executores de triggers
protocol TriggerExecutorProtocol {
    /// Registra um trigger para execução
    func register(trigger: any TriggerProtocol, for memoryID: UUID) async

    /// Remove um trigger específico
    func unregister(triggerID: UUID, for memoryID: UUID) async

    /// Remove todos os triggers de uma memória
    func unregisterAll(for memoryID: UUID) async

    /// Atualiza todos os triggers de uma lista de memórias
    func sync(memories: [Memory]) async
}
