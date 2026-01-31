//
//  DataExportService.swift
//  sparky
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

        var includeAttachmentsValue: Bool {
            switch self {
            case .full, .activeOnly:
                return true
            case .withoutAttachments, .activeOnlyWithoutAttachments:
                return false
            }
        }

        var includeCompletedValue: Bool {
            switch self {
            case .full, .withoutAttachments:
                return true
            case .activeOnly, .activeOnlyWithoutAttachments:
                return false
            }
        }
    }

    private let memoryService: MemoryService
    private let mindService: MindService
    private let attachmentStore: MemoryAttachmentStore
    let logger = Logger(subsystem: "sparky", category: "DataExportService")
    private let jsonEncoder: JSONEncoder

    init(
        memoryService: MemoryService,
        mindService: MindService,
        attachmentStore: MemoryAttachmentStore
    ) {
        self.memoryService = memoryService
        self.mindService = mindService
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
        let mindsByID = Dictionary(uniqueKeysWithValues: minds.map { ($0.id, $0) })
        var exportedMinds = [ExportedMind]()
        var processedMinds = Set<UUID>()

        for mind in minds where mind.parent == nil {
            exportedMinds.append(collectMindHierarchy(from: mind, mindsByID: mindsByID, processedMinds: &processedMinds))
        }
        
        return exportedMinds
    }

    private func collectMindHierarchy(from mind: Mind, mindsByID: [UUID: Mind], processedMinds: inout Set<UUID>) -> ExportedMind {
        processedMinds.insert(mind.id)
        
        var children = [ExportedMind]()
        if let childMinds = mind.children {
            for child in childMinds {
                if !processedMinds.contains(child.id) {
                    children.append(collectMindHierarchy(from: child, mindsByID: mindsByID, processedMinds: &processedMinds))
                }
            }
        }
        
        return mind.toExported(children: children)
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
