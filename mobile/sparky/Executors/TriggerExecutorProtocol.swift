//
//  TriggerExecutorProtocol.swift
//  sparky
//
//  Created by Codex on 13/10/25.
//

import Foundation

/// Protocol for trigger executors
protocol TriggerExecutorProtocol {
    /// Remove a specific trigger
    func unregister(triggerID: UUID, for memoryID: UUID) async

    /// Remove all triggers for a memory
    func unregisterAll(for memoryID: UUID) async

    /// Sync all triggers from a list of memories
    func sync(memories: [Memory]) async
}
