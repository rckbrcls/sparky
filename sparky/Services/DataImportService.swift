//
//  DataImportService.swift
//  sparky
//
//  Created by Codex on 26/01/26.
//

import Foundation
import os.log

@MainActor
final class DataImportService {
    enum ImportError: LocalizedError {
        case invalidFormat
        case unsupportedVersion(String)
        case decodingFailed(Error)
        case fileReadFailed(Error)
        case validationFailed(String)
        case importFailed(Error)

        var errorDescription: String? {
            switch self {
            case .invalidFormat:
                return "Invalid export format."
            case .unsupportedVersion(let version):
                return "Unsupported export version: \(version)."
            case .decodingFailed(let error):
                return "Failed to decode export data: \(error.localizedDescription)"
            case .fileReadFailed(let error):
                return "Failed to read import file: \(error.localizedDescription)"
            case .validationFailed(let message):
                return "Validation failed: \(message)"
            case .importFailed(let error):
                return "Import failed: \(error.localizedDescription)"
            }
        }
    }

    struct ImportResult {
        let importedMinds: Int
        let importedMemories: Int
        let importedAttachments: Int
        let errors: [Error]

        var hasErrors: Bool {
            !errors.isEmpty
        }
    }

    private let memoryService: MemoryService
    private let mindService: MindService
    private let attachmentStore: MemoryAttachmentStore
    private let logger = Logger(subsystem: "sparky", category: "DataImportService")
    private let jsonDecoder: JSONDecoder

    init(
        memoryService: MemoryService,
        mindService: MindService,
        attachmentStore: MemoryAttachmentStore
    ) {
        self.memoryService = memoryService
        self.mindService = mindService
        self.attachmentStore = attachmentStore

        self.jsonDecoder = JSONDecoder()
        jsonDecoder.dateDecodingStrategy = .iso8601
    }

    func importFromFile(at url: URL) async throws -> ImportResult {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            logger.error("Failed to read import file: \(error.localizedDescription)")
            throw ImportError.fileReadFailed(error)
        }

        return try await importFromData(data)
    }

    func importFromData(_ data: Data) async throws -> ImportResult {
        // Decode export format
        let exportFormat: SparkyExportFormat
        do {
            exportFormat = try jsonDecoder.decode(SparkyExportFormat.self, from: data)
        } catch {
            logger.error("Failed to decode export data: \(error.localizedDescription)")
            throw ImportError.decodingFailed(error)
        }

        // Validate version
        guard exportFormat.version == "1.0" else {
            throw ImportError.unsupportedVersion(exportFormat.version)
        }

        // Import data
        return try await performImport(exportFormat: exportFormat)
    }

    // MARK: - Private Import Logic

    private func performImport(exportFormat: SparkyExportFormat) async throws -> ImportResult {
        var errors: [Error] = []
        var importedMinds = 0
        var importedMemories = 0
        var importedAttachments = 0

        // ID mapping: old ID -> new ID
        var mindIDMap: [UUID: UUID] = [:]
        var memoryIDMap: [UUID: UUID] = [:]
        var attachmentIDMap: [UUID: UUID] = [:]
        
        let mindsByID = Dictionary(uniqueKeysWithValues: mindService.minds.map { ($0.id, $0) })

        // Step 1: Import Minds
        for exportedMind in exportFormat.minds {
            importedMinds += await importMindHierarchy(exportedMind: exportedMind, mindsByID: mindsByID, parentID: nil, mindIDMap: &mindIDMap, errors: &errors)
        }

        // Step 2: Import Memories
        for exportedMemory in exportFormat.memories {
            do {
                // Map mind ID
                let newMindID = exportedMemory.mindID.flatMap { mindIDMap[$0] }

                // Convert triggers to config drafts
                var scheduleDraft: ScheduleConfigDraft?
                var locationDraft: LocationConfigDraft?
                var reminderDraft: ReminderConfigDraft?

                for exported in exportedMemory.triggers {
                    if exported.type == "scheduled" {
                        let recurrenceRule: RecurrenceRule?
                        if let exportedRecurrence = exported.recurrenceRule,
                           let frequency = RecurrenceFrequency(rawValue: exportedRecurrence.frequency) {
                            recurrenceRule = RecurrenceRule(
                                frequency: frequency,
                                interval: exportedRecurrence.interval,
                                endDate: exportedRecurrence.endDate,
                                occurrenceCount: exportedRecurrence.occurrenceCount
                            )
                        } else {
                            recurrenceRule = nil
                        }

                        scheduleDraft = ScheduleConfigDraft(
                            fireDate: exported.fireDate,
                            startDate: exported.startDate,
                            recurrenceRule: recurrenceRule,
                            timeZoneIdentifier: exported.timeZoneIdentifier,
                            weekdayMask: exported.weekdayMask,
                            isActive: exported.isActive,
                            isAllDay: exported.isAllDay
                        )
                    } else if exported.type == "location",
                              let loc = exported.location,
                              let event = LocationEvent(rawValue: loc.event) {
                        locationDraft = LocationConfigDraft(
                            latitude: loc.latitude,
                            longitude: loc.longitude,
                            radius: loc.radius,
                            name: loc.name,
                            event: event,
                            isActive: exported.isActive
                        )
                    } else if exported.type == "reminder",
                              let reminder = exported.reminder {
                        reminderDraft = ReminderConfigDraft(
                            intervalValue: max(1, reminder.intervalValue),
                            intervalUnit: ReminderIntervalUnit(rawValue: reminder.intervalUnit) ?? .hours,
                            repeatCount: reminder.repeatCount,
                            isActive: exported.isActive,
                            startedAt: reminder.startedAt,
                            startedBy: reminder.startedBy.flatMap(ReminderStartSource.init(rawValue:))
                        )
                    }
                }

                // Convert check items
                let checkItems = exportedMemory.checkItems.enumerated().map { index, exportedItem in
                    CheckItemDraft(
                        id: UUID(),
                        title: exportedItem.title,
                        detail: exportedItem.detail ?? "",
                        isCompleted: exportedItem.isCompleted,
                        sortOrder: index,
                        createdAt: exportedItem.createdAt,
                        completedAt: exportedItem.completedAt
                    )
                }

                // Create memory draft
                let draft = MemoryDraft(
                    id: UUID(),
                    title: exportedMemory.title,
                    status: MemoryStatus(rawValue: exportedMemory.status) ?? .active,
                    isPinned: exportedMemory.isPinned,
                    dueDate: exportedMemory.dueDate,
                    mindID: newMindID,
                    scheduleConfig: scheduleDraft,
                    locationConfig: locationDraft,
                    reminderConfig: reminderDraft,
                    note: exportedMemory.note,
                    checkItems: checkItems,
                    photoAttachmentIDs: [],
                    linkAttachmentIDs: [],
                    audioAttachmentIDs: [],
                    fileAttachmentIDs: [],
                    attachments: [],
                    autoCompleteOnChecklistCompletion: exportedMemory.autoCompleteOnChecklistCompletion,
                    completedDates: exportedMemory.completedDates
                )

                // Create memory
                let newMemory = try await memoryService.createMemory(from: draft)
                memoryIDMap[exportedMemory.id] = newMemory.id
                importedMemories += 1

                // Step 3: Import attachments for this memory
                if let attachments = exportFormat.attachments?[exportedMemory.id] {
                    let imported = try await importAttachments(
                        attachments: attachments,
                        for: newMemory.id,
                        attachmentIDMap: &attachmentIDMap
                    )
                    importedAttachments += imported
                }
            } catch {
                logger.error("Failed to import memory \(exportedMemory.title): \(error.localizedDescription)")
                errors.append(error)
            }
        }

        // Refresh all services
        await mindService.refresh(force: true)
        await memoryService.refresh(force: true)

        return ImportResult(
            importedMinds: importedMinds,
            importedMemories: importedMemories,
            importedAttachments: importedAttachments,
            errors: errors
        )
    }
    
    private func importMindHierarchy(exportedMind: ExportedMind, mindsByID: [UUID: Mind], parentID: UUID?, mindIDMap: inout [UUID: UUID], errors: inout [Error]) async -> Int {
        var importedCount = 0
        do {
            let newMind: Mind
            if let existingMind = mindsByID.values.first(where: { $0.name == exportedMind.name && $0.parent?.id == parentID }) {
                newMind = existingMind
            } else {
                newMind = try await mindService.createMind(
                    name: exportedMind.name,
                    colorHex: exportedMind.colorHex,
                    iconName: exportedMind.iconName,
                    isDefault: exportedMind.isDefault,
                    parent: parentID.flatMap { mindsByID[$0] }
                )
                importedCount += 1
            }
            mindIDMap[exportedMind.id] = newMind.id
            
            for child in exportedMind.children {
                importedCount += await importMindHierarchy(exportedMind: child, mindsByID: mindsByID, parentID: newMind.id, mindIDMap: &mindIDMap, errors: &errors)
            }
        } catch {
            logger.error("Failed to import mind \(exportedMind.name): \(error.localizedDescription)")
            errors.append(error)
        }
        return importedCount
    }

    private func importAttachments(
        attachments: [ExportedAttachment],
        for memoryID: UUID,
        attachmentIDMap: inout [UUID: UUID]
    ) async throws -> Int {
        var imported = 0

        for exportedAttachment in attachments {
            do {
                let rawKind = exportedAttachment.kind
                let allowedKinds: Set<String> = [
                    Memory.AttachmentKind.photo.rawValue,
                    Memory.AttachmentKind.link.rawValue,
                    Memory.AttachmentKind.audio.rawValue,
                    Memory.AttachmentKind.file.rawValue
                ]

                guard allowedKinds.contains(rawKind) else {
                    logger.warning("Unknown attachment kind: \(exportedAttachment.kind)")
                    continue
                }

                let kind = Memory.AttachmentKind(rawValue: rawKind)

                // Decode attachment data
                var data: Data?
                if let base64Data = exportedAttachment.data {
                    data = Data(base64Encoded: base64Data)
                }

                // Handle URL for links
                var url: URL?
                if let urlString = exportedAttachment.url {
                    url = URL(string: urlString)
                }

                guard let attachmentData = data ?? (url != nil ? Data() : nil) else {
                    logger.warning("No data or URL for attachment: \(exportedAttachment.id)")
                    continue
                }

                let newAttachment = Memory.Attachment(
                    id: UUID(), // New ID
                    kind: kind,
                    data: attachmentData,
                    createdAt: exportedAttachment.createdAt,
                    url: url,
                    filename: exportedAttachment.filename
                )

                // Get existing attachments and add new one
                var existingAttachments = await attachmentStore.attachments(for: memoryID)
                existingAttachments.append(newAttachment)

                // Replace attachments
                try await attachmentStore.replaceAttachments(for: memoryID, with: existingAttachments)
                attachmentIDMap[exportedAttachment.id] = newAttachment.id
                imported += 1
            } catch {
                logger.error("Failed to import attachment: \(error.localizedDescription)")
                throw error
            }
        }

        return imported
    }
}
