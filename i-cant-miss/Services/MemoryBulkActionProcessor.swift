//
//  MemoryBulkActionProcessor.swift
//  i-cant-miss
//
//  Created by GPT-5 Codex on 12/11/25.
//

import Foundation

@MainActor
final class MemoryBulkActionProcessor {
    struct MemoryBulkActionResult {
        let succeededIDs: Set<UUID>
        let failedIDs: [UUID: Error]

        var hasFailures: Bool { !failedIDs.isEmpty }
        var hasSuccesses: Bool { !succeededIDs.isEmpty }
    }

    enum ProcessorError: LocalizedError {
        case memoryNotFound
        case underlying(Error)

        var errorDescription: String? {
            switch self {
            case .memoryNotFound:
                return "Memory not found."
            case .underlying(let error):
                return error.localizedDescription
            }
        }
    }

    private let environment: AppEnvironment

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    func moveMemories(_ ids: Set<UUID>, to space: SpaceModel) async -> MemoryBulkActionResult {
        await process(ids: ids) { memory in
            try await self.environment.memoryService.moveMemory(memory.id, to: space)
        }
    }

    func updateStatus(of ids: Set<UUID>, to status: MemoryStatus) async -> MemoryBulkActionResult {
        await process(ids: ids) { memory in
            try await self.environment.memoryService.setStatus(memoryID: memory.id, status: status)
        }
    }

    // MARK: - Helpers

    private func process(
        ids: Set<UUID>,
        handler: @escaping (MemoryModel) async throws -> Void
    ) async -> MemoryBulkActionResult {
        var succeeded: Set<UUID> = []
        var failed: [UUID: Error] = [:]

        for id in ids {
            guard let memory = environment.memoryService.memory(id: id) else {
                failed[id] = ProcessorError.memoryNotFound
                continue
            }

            do {
                try await handler(memory)
                succeeded.insert(id)
            } catch {
                failed[id] = ProcessorError.underlying(error)
            }
        }

        return MemoryBulkActionResult(succeededIDs: succeeded, failedIDs: failed)
    }
}
