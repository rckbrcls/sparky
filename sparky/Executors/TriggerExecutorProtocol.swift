//
//  TriggerExecutorProtocol.swift
//  sparky
//
//  Created by Codex on 13/10/25.
//

import Foundation

/// Sync and unregister surface used by MemoryService.
/// Tests can substitute a recorder without touching the system executors.
@MainActor
protocol TriggerSyncing: AnyObject {
    func unregister(triggerID: UUID, for memoryID: UUID) async
    func unregisterAll(for memoryID: UUID) async
    func sync(memories: [Memory]) async
}

/// Protocol for trigger executors
protocol TriggerExecutorProtocol {
    /// Remove a specific trigger
    func unregister(triggerID: UUID, for memoryID: UUID) async

    /// Remove all triggers for a memory
    func unregisterAll(for memoryID: UUID) async

    /// Sync all triggers from a list of memories
    func sync(memories: [Memory]) async
}
