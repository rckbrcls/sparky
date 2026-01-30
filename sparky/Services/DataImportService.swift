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
        let importedLobes: Int
        let importedMemories: Int
        let importedAttachments: Int
        let errors: [Error]
        
        var hasErrors: Bool {
            !errors.isEmpty
        }
    }
    
    private let memoryService: MemoryService
    private let mindService: MindService
    private let lobeService: LobeService
    private let attachmentStore: MemoryAttachmentStore
    private let logger = Logger(subsystem: "sparky", category: "DataImportService")
    private let jsonDecoder: JSONDecoder
    
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
        var importedLobes = 0
        var importedMemories = 0
        var importedAttachments = 0
        
        // ID mapping: old ID -> new ID
        var mindIDMap: [UUID: UUID] = [:]
        var lobeIDMap: [UUID: UUID] = [:]
        var memoryIDMap: [UUID: UUID] = [:]
        var attachmentIDMap: [UUID: UUID] = [:]
        
        // Step 1: Import Minds
        for exportedMind in exportFormat.minds {
            do {
                // Check if mind with same name already exists
                let existingMind = mindService.minds.first { $0.name == exportedMind.name }
                if let existing = existingMind {
                    mindIDMap[exportedMind.id] = existing.id
                    continue
                }
                
                let newMind = try await mindService.createMind(
                    name: exportedMind.name,
                    colorHex: exportedMind.colorHex,
                    iconName: exportedMind.iconName,
                    isDefault: exportedMind.isDefault
                )
                mindIDMap[exportedMind.id] = newMind.id
                importedMinds += 1
            } catch {
                logger.error("Failed to import mind \(exportedMind.name): \(error.localizedDescription)")
                errors.append(error)
            }
        }
        
        // Step 2: Import Lobes (Spaces)
        for exportedMind in exportFormat.minds {
            guard let newMindID = mindIDMap[exportedMind.id] else { continue }
            
            for exportedLobe in exportedMind.lobes {
                do {
                    // Check if lobe with same name already exists in this mind
                    let existingLobe = lobeService.lobes.first { 
                        $0.name == exportedLobe.name && $0.mind?.id == newMindID
                    }
                    if let existing = existingLobe {
                        lobeIDMap[exportedLobe.id] = existing.id
                        continue
                    }
                    
                    let newLobe = try await lobeService.createLobe(
                        name: exportedLobe.name,
                        colorHex: exportedLobe.colorHex,
                        iconName: exportedLobe.iconName,
                        isDefault: exportedLobe.isDefault,
                        mindID: newMindID
                    )
                    lobeIDMap[exportedLobe.id] = newLobe.id
                    importedLobes += 1
                } catch {
                    logger.error("Failed to import lobe \(exportedLobe.name): \(error.localizedDescription)")
                    errors.append(error)
                }
            }
        }
        
        // Step 3: Import Memories
        for exportedMemory in exportFormat.memories {
            do {
                // Map lobe ID
                let newLobeID = exportedMemory.lobeID.flatMap { lobeIDMap[$0] }
                
                // Convert triggers
                let triggers = exportedMemory.triggers.compactMap { exportedTrigger -> MemoryTriggerModel? in
                    convertTrigger(exportedTrigger, memoryIDMap: &memoryIDMap)
                }
                
                // Convert check items
                let checkItems = exportedMemory.checkItems.enumerated().map { index, exportedItem in
                    CheckItemDraft(
                        id: UUID(), // New ID
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
                    id: UUID(), // New ID
                    title: exportedMemory.title,
                    status: MemoryStatus(rawValue: exportedMemory.status) ?? .active,
                    isPinned: exportedMemory.isPinned,
                    dueDate: exportedMemory.dueDate,
                    lobeID: newLobeID,
                    triggers: triggers,
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
                
                // Step 4: Import attachments for this memory
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
        await lobeService.refresh(force: true)
        await memoryService.refresh(force: true)
        
        return ImportResult(
            importedMinds: importedMinds,
            importedLobes: importedLobes,
            importedMemories: importedMemories,
            importedAttachments: importedAttachments,
            errors: errors
        )
    }
    
    private func convertTrigger(
        _ exported: ExportedTrigger,
        memoryIDMap: inout [UUID: UUID]
    ) -> MemoryTriggerModel? {
        guard let type = MemoryTriggerType(rawValue: exported.type) else {
            logger.warning("Unknown trigger type: \(exported.type)")
            return nil
        }
        
        // Convert recurrence rule
        let recurrenceRule: RecurrenceRule?
        if let exportedRecurrence = exported.recurrenceRule,
           let frequency = RecurrenceFrequency(rawValue: exportedRecurrence.frequency) {
            recurrenceRule = RecurrenceRule(
                frequency: frequency,
                interval: exportedRecurrence.interval,
                endDate: exportedRecurrence.endDate
            )
        } else {
            recurrenceRule = nil
        }
        
        // Convert location trigger
        let location: MemoryTriggerModel.TriggerLocation?
        if let exportedLocation = exported.location,
           let event = LocationEvent(rawValue: exportedLocation.event) {
            location = MemoryTriggerModel.TriggerLocation(
                latitude: exportedLocation.latitude,
                longitude: exportedLocation.longitude,
                radius: exportedLocation.radius,
                name: exportedLocation.name,
                event: event
            )
        } else {
            location = nil
        }
        
        // Convert sequential trigger
        let sequential: MemoryTriggerModel.TriggerSequential?
        if let exportedSequential = exported.sequential {
            // Note: sequence IDs and memory references would need to be remapped
            // For now, we'll create new sequence IDs
            sequential = MemoryTriggerModel.TriggerSequential(
                sequenceID: UUID(), // New sequence ID
                stepIndex: exportedSequential.stepIndex,
                startDate: exportedSequential.startDate,
                currentStepIndex: exportedSequential.currentStepIndex
            )
        } else {
            sequential = nil
        }
        
        return MemoryTriggerModel(
            id: UUID(), // New ID
            type: type,
            fireDate: exported.fireDate,
            startDate: exported.startDate,
            recurrenceRule: recurrenceRule,
            timeZoneIdentifier: exported.timeZoneIdentifier,
            weekdayMask: exported.weekdayMask,
            isActive: exported.isActive,
            isAllDay: exported.isAllDay,
            location: location,
            sequential: sequential,
            spacedStage: exported.spacedStage,
            lastReviewDate: exported.lastReviewDate,
            ignoreCount: exported.ignoreCount
        )
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
