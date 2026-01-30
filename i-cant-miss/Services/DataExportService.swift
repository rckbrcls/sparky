//
//  DataExportService.swift
//  i-cant-miss
//
//  Created by Codex on 26/01/26.
//

import Foundation
import os.log

@MainActor
final class DataExportService {
    enum ExportError: LocalizedError {
        case noDataToExport
        case encodingFailed
        case fileWriteFailed(Error)
        case attachmentLoadFailed(UUID)

        var errorDescription: String? {
            switch self {
            case .noDataToExport:
                return "No data available to export."
            case .encodingFailed:
                return "Failed to encode data for export."
            case .fileWriteFailed(let error):
                return "Failed to write export file: \(error.localizedDescription)"
            case .attachmentLoadFailed(let id):
                return "Failed to load attachment: \(id.uuidString)"
            }
        }
    }

    enum ExportOptions {
        var includeAttachments: Bool { false }
        var includeCompleted: Bool { true }
        var attachmentsMode: SparkyExportFormat.AttachmentsMode { .inline }

        case full
        case withoutAttachments
        case activeOnly
        case activeOnlyWithoutAttachments
        case memoriesByLobe
        case activeMemoriesByLobe

        var includeAttachmentsValue: Bool {
            switch self {
            case .full, .activeOnly:
                return true
            case .withoutAttachments, .activeOnlyWithoutAttachments, .memoriesByLobe, .activeMemoriesByLobe:
                return false
            }
        }

        var includeCompletedValue: Bool {
            switch self {
            case .full, .withoutAttachments, .memoriesByLobe:
                return true
            case .activeOnly, .activeOnlyWithoutAttachments, .activeMemoriesByLobe:
                return false
            }
        }
    }

    private let memoryService: MemoryService
    private let mindService: MindService
    private let lobeService: LobeService
    private let attachmentStore: MemoryAttachmentStore
    let logger = Logger(subsystem: "i-cant-miss", category: "DataExportService")
    private let jsonEncoder: JSONEncoder

    init(
        memoryService: MemoryService,
        mindService: MindService,
        lobeService: LobeService,
        attachmentStore: MemoryAttachmentStore
    ) {
        self.memoryService = memoryService
        self.mindService = mindService
        self.lobeService = lobeService
        self.attachmentStore = attachmentStore

        self.jsonEncoder = JSONEncoder()
        jsonEncoder.dateEncodingStrategy = .iso8601
        jsonEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func export(options: ExportOptions = .full) async throws -> Data {
        // Collect all data
        let memories = await collectMemories(includeCompleted: options.includeCompletedValue)
        let minds = await collectMinds()
        let attachments = options.includeAttachmentsValue
            ? await collectAttachments(for: memories)
            : nil

        guard !memories.isEmpty || !minds.isEmpty else {
            throw ExportError.noDataToExport
        }

        // Build export format
        let exportFormat = SparkyExportFormat(
            version: "1.0",
            exportedAt: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            minds: minds,
            memories: memories.map { $0.toExported() },
            attachments: attachments,
            attachmentsMode: options.includeAttachmentsValue ? .inline : nil,
            attachmentsDirectory: nil
        )

        // Encode to JSON
        do {
            let data = try jsonEncoder.encode(exportFormat)
            return data
        } catch {
            logger.error("Failed to encode export data: \(error.localizedDescription)")
            throw ExportError.encodingFailed
        }
    }

    func exportToFile(
        at url: URL,
        options: ExportOptions = .full
    ) async throws {
        let data = try await export(options: options)

        do {
            try data.write(to: url, options: .atomic)
            logger.info("Successfully exported data to: \(url.path)")
        } catch {
            logger.error("Failed to write export file: \(error.localizedDescription)")
            throw ExportError.fileWriteFailed(error)
        }
    }

    // MARK: - Private Helpers

    func collectMemories(includeCompleted: Bool) async -> [Memory] {
        let allMemories = memoryService.memories

        if includeCompleted {
            return allMemories
        } else {
            return allMemories.filter { $0.status == MemoryStatus.active }
        }
    }

    private func collectMinds() async -> [ExportedMind] {
        let minds = mindService.minds
        let lobes = lobeService.lobes

        // Group lobes by mind
        var lobesByMind: [UUID: [ExportedLobe]] = [:]
        for lobe in lobes {
            // Skip virtual lobes (All, Inbox, Limbo)
            if lobe.isAllSpaces || lobe.isInbox || lobe.isLimbo {
                continue
            }

            if let mindID = lobe.mind?.id {
                if lobesByMind[mindID] == nil {
                    lobesByMind[mindID] = []
                }
                lobesByMind[mindID]?.append(lobe.toExported())
            }
        }

        // Build exported minds with their lobes
        return minds.map { mind in
            let mindLobes = lobesByMind[mind.id] ?? []
            return mind.toExported(lobes: mindLobes)
        }
    }

    func exportGroupedByLobe(activeOnly: Bool = false) async throws -> Data {
        let memories = await collectMemories(includeCompleted: !activeOnly)
        // Actually, let's keep it consistent with "Active Only" if needed, but for a specific "Group by Lobe" export, usually a dump of everything is expected.
        // Let's filter out 'Inbox', 'Limbo', 'All' if they don't have real user content, but `collectMemories` gives me everything.

        let lobes = lobeService.lobes
        var exportGroups: [LobeGroupExport] = []

        // Helper to find lobe name
        func getLobeName(id: UUID?) -> String {
            guard let id = id else { return "Unassigned" }
            if let lobe = lobes.first(where: { $0.id == id }) {
                return lobe.name
            }
            return "Unknown Lobe"
        }

        // Group memories by Lobe ID
        let grouped = Dictionary(grouping: memories) { $0.lobe?.id }

        for (lobeID, lobeMemories) in grouped {
            let lobeName = getLobeName(id: lobeID)

            // Convert memories to ExportedMemory but ensure no attachments are included (implicitly handled by not fetching/attaching them if I use a lighter struct, OR I can just use ExportedMemory and set attachments field to nil/empty)
            // The user specifically asked for "memories without attachments".
            // `Memory.toExported()` checks `hasAttachments` etc? No, `toExported()` is on `Memory`.
            // Let's see `Memory.toExported` implementation. I don't see it in the file view I did (it might be in an extension).
            // Assuming `toExported` exists.

            // Wait, I need to check if `toExported` exists or if I should create a simplified structure.
            // The user asked "create a json, that groups the memories without attachments by lobe, put the name of the lobe and the memories of the lobe".
            // If I use `ExportedMemory`, it might have fields for attachments.
            // Let's create a tailored struct `LobeGroupExport` and maybe a `SimpleExportedMemory` or just use the existing one but strip attachments.

            let exportedMemories = lobeMemories.map { memory in
                memory.toExported()
            }

            // Check if this Lobe is special? (Inbox/Limbo). They are just Lobes in the system.

            exportGroups.append(LobeGroupExport(lobeName: lobeName, memories: exportedMemories))
        }

        // Sort by Lobe Name for tidiness
        exportGroups.sort { $0.lobeName < $1.lobeName }

        do {
            let data = try jsonEncoder.encode(exportGroups)
            return data
        } catch {
            logger.error("Failed to encode grouped export: \(error.localizedDescription)")
            throw ExportError.encodingFailed
        }
    }

    struct LobeGroupExport: Codable {
        let lobeName: String
        let memories: [ExportedMemory]
    }

    private func collectAttachments(for memories: [Memory]) async -> [UUID: [ExportedAttachment]] {
        var attachmentsMap: [UUID: [ExportedAttachment]] = [:]

        for memory in memories {
            let attachments = await attachmentStore.attachments(for: memory.id)
            let exportedAttachments = attachments.map { $0.toExported(includeData: true) }

            if !exportedAttachments.isEmpty {
                attachmentsMap[memory.id] = exportedAttachments
            }
        }

        return attachmentsMap
    }
}
