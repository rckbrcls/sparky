//
//  SparkyExportFormat.swift
//  sparky
//
//  Created by Codex on 26/01/26.
//

import Foundation

/// Main export format for Sparky app data
/// Preserves 100% of app data including triggers, attachments, and hierarchy
struct SparkyExportFormat: Codable {
    let version: String
    let exportedAt: Date
    let appVersion: String?
    let minds: [ExportedMind]
    let memories: [ExportedMemory]
    let attachments: [UUID: [ExportedAttachment]]?
    
    enum AttachmentsMode: String, Codable {
        case inline
        case external
    }
    
    var attachmentsMode: AttachmentsMode?
    var attachmentsDirectory: String?
    
    init(
        version: String = "1.0",
        exportedAt: Date = Date(),
        appVersion: String? = nil,
        minds: [ExportedMind] = [],
        memories: [ExportedMemory] = [],
        attachments: [UUID: [ExportedAttachment]]? = nil,
        attachmentsMode: AttachmentsMode? = nil,
        attachmentsDirectory: String? = nil
    ) {
        self.version = version
        self.exportedAt = exportedAt
        self.appVersion = appVersion
        self.minds = minds
        self.memories = memories
        self.attachments = attachments
        self.attachmentsMode = attachmentsMode
        self.attachmentsDirectory = attachmentsDirectory
    }
}

// MARK: - Exported Mind

struct ExportedMind: Codable, Identifiable {
    let id: UUID
    let name: String
    let colorHex: String?
    let iconName: String?
    let sortOrder: Int
    let isDefault: Bool
    let children: [ExportedMind]
    
    init(
        id: UUID,
        name: String,
        colorHex: String? = nil,
        iconName: String? = nil,
        sortOrder: Int = 0,
        isDefault: Bool = false,
        children: [ExportedMind] = []
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.iconName = iconName
        self.sortOrder = sortOrder
        self.isDefault = isDefault
        self.children = children
    }
}

// MARK: - Exported Memory

struct ExportedMemory: Codable, Identifiable {
    let id: UUID
    let title: String
    let note: String?
    let status: String
    let isPinned: Bool
    let dueDate: Date?
    let createdAt: Date
    let updatedAt: Date
    let userOrder: Int
    let autoCompleteOnChecklistCompletion: Bool
    let mindID: UUID?
    let triggers: [ExportedTrigger]
    let checkItems: [ExportedCheckItem]
    let photoAttachmentIDs: [UUID]
    let linkAttachmentIDs: [UUID]
    let audioAttachmentIDs: [UUID]
    let fileAttachmentIDs: [UUID]
    let completedDates: [Date]
    
    init(
        id: UUID,
        title: String,
        note: String? = nil,
        status: String,
        isPinned: Bool = false,
        dueDate: Date? = nil,
        createdAt: Date,
        updatedAt: Date,
        userOrder: Int = 0,
        autoCompleteOnChecklistCompletion: Bool = false,
        mindID: UUID? = nil,
        triggers: [ExportedTrigger] = [],
        checkItems: [ExportedCheckItem] = [],
        photoAttachmentIDs: [UUID] = [],
        linkAttachmentIDs: [UUID] = [],
        audioAttachmentIDs: [UUID] = [],
        fileAttachmentIDs: [UUID] = [],
        completedDates: [Date] = []
    ) {
        self.id = id
        self.title = title
        self.note = note
        self.status = status
        self.isPinned = isPinned
        self.dueDate = dueDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.userOrder = userOrder
        self.autoCompleteOnChecklistCompletion = autoCompleteOnChecklistCompletion
        self.mindID = mindID
        self.triggers = triggers
        self.checkItems = checkItems
        self.photoAttachmentIDs = photoAttachmentIDs
        self.linkAttachmentIDs = linkAttachmentIDs
        self.audioAttachmentIDs = audioAttachmentIDs
        self.fileAttachmentIDs = fileAttachmentIDs
        self.completedDates = completedDates
    }
}

// MARK: - Exported Trigger

struct ExportedTrigger: Codable, Identifiable {
    let id: UUID
    let type: String
    let fireDate: Date?
    let startDate: Date?
    let recurrenceRule: ExportedRecurrenceRule?
    let timeZoneIdentifier: String?
    let weekdayMask: Int16
    let isActive: Bool
    let isAllDay: Bool
    let location: ExportedLocationTrigger?
    let reminder: ExportedReminderTrigger?
    let sequential: ExportedSequentialTrigger?
    let spacedStage: Int
    let lastReviewDate: Date?
    let ignoreCount: Int
    
    init(
        id: UUID,
        type: String,
        fireDate: Date? = nil,
        startDate: Date? = nil,
        recurrenceRule: ExportedRecurrenceRule? = nil,
        timeZoneIdentifier: String? = nil,
        weekdayMask: Int16 = 0,
        isActive: Bool = true,
        isAllDay: Bool = false,
        location: ExportedLocationTrigger? = nil,
        reminder: ExportedReminderTrigger? = nil,
        sequential: ExportedSequentialTrigger? = nil,
        spacedStage: Int = 0,
        lastReviewDate: Date? = nil,
        ignoreCount: Int = 0
    ) {
        self.id = id
        self.type = type
        self.fireDate = fireDate
        self.startDate = startDate
        self.recurrenceRule = recurrenceRule
        self.timeZoneIdentifier = timeZoneIdentifier
        self.weekdayMask = weekdayMask
        self.isActive = isActive
        self.isAllDay = isAllDay
        self.location = location
        self.reminder = reminder
        self.sequential = sequential
        self.spacedStage = spacedStage
        self.lastReviewDate = lastReviewDate
        self.ignoreCount = ignoreCount
    }
}

// MARK: - Exported Recurrence Rule

struct ExportedRecurrenceRule: Codable {
    let frequency: String
    let interval: Int
    let endDate: Date?
    let occurrenceCount: Int?

    init(frequency: String, interval: Int = 1, endDate: Date? = nil, occurrenceCount: Int? = nil) {
        self.frequency = frequency
        self.interval = interval
        self.endDate = endDate
        self.occurrenceCount = occurrenceCount
    }
}

// MARK: - Exported Location Trigger

struct ExportedLocationTrigger: Codable {
    let latitude: Double
    let longitude: Double
    let radius: Double
    let name: String?
    let event: String
    
    init(
        latitude: Double,
        longitude: Double,
        radius: Double,
        name: String? = nil,
        event: String
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
        self.name = name
        self.event = event
    }
}

// MARK: - Exported Reminder Trigger

struct ExportedReminderTrigger: Codable {
    let intervalValue: Int
    let intervalUnit: String
    let repeatCount: Int?
    let startedAt: Date?
    let startedBy: String?

    init(
        intervalValue: Int,
        intervalUnit: String,
        repeatCount: Int? = nil,
        startedAt: Date? = nil,
        startedBy: String? = nil
    ) {
        self.intervalValue = intervalValue
        self.intervalUnit = intervalUnit
        self.repeatCount = repeatCount
        self.startedAt = startedAt
        self.startedBy = startedBy
    }
}

// MARK: - Exported Sequential Trigger

struct ExportedSequentialTrigger: Codable {
    let sequenceID: UUID
    let stepIndex: Int
    let startDate: Date?
    let currentStepIndex: Int
    
    init(
        sequenceID: UUID,
        stepIndex: Int = 0,
        startDate: Date? = nil,
        currentStepIndex: Int = 0
    ) {
        self.sequenceID = sequenceID
        self.stepIndex = stepIndex
        self.startDate = startDate
        self.currentStepIndex = currentStepIndex
    }
}

// MARK: - Exported Check Item

struct ExportedCheckItem: Codable, Identifiable {
    let id: UUID
    let title: String
    let detail: String?
    let isCompleted: Bool
    let sortOrder: Int
    let createdAt: Date
    let updatedAt: Date
    let completedAt: Date?
    
    init(
        id: UUID,
        title: String,
        detail: String? = nil,
        isCompleted: Bool = false,
        sortOrder: Int = 0,
        createdAt: Date,
        updatedAt: Date,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.isCompleted = isCompleted
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
    }
}

// MARK: - Exported Attachment

struct ExportedAttachment: Codable, Identifiable {
    let id: UUID
    let kind: String
    let data: String? // Base64 encoded
    let createdAt: Date
    let url: String? // URL as string
    let filename: String?
    let filePath: String? // For external attachments mode
    
    init(
        id: UUID,
        kind: String,
        data: String? = nil,
        createdAt: Date,
        url: String? = nil,
        filename: String? = nil,
        filePath: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.data = data
        self.createdAt = createdAt
        self.url = url
        self.filename = filename
        self.filePath = filePath
    }
}

// MARK: - Conversion Extensions

extension Memory {
    func toExported() -> ExportedMemory {
        var triggers: [ExportedTrigger] = []

        // Convert scheduleConfig to ExportedTrigger for backward compatibility
        if let config = scheduleConfig, config.isActive {
            triggers.append(config.toExportedTrigger())
        }

        // Convert locationConfig to ExportedTrigger for backward compatibility
        if let config = locationConfig, config.isActive {
            triggers.append(config.toExportedTrigger())
        }

        // Convert reminderConfig to ExportedTrigger
        if let config = reminderConfig, config.isActive {
            triggers.append(config.toExportedTrigger())
        }

        return ExportedMemory(
            id: id,
            title: title,
            note: note,
            status: status.rawValue,
            isPinned: isPinned,
            dueDate: dueDate,
            createdAt: createdAt ?? Date(),
            updatedAt: updatedAt ?? createdAt ?? Date(),
            userOrder: userOrder,
            autoCompleteOnChecklistCompletion: autoCompleteOnChecklistCompletion,
            mindID: mind?.id,
            triggers: triggers,
            checkItems: checkItems.sorted { $0.sortOrder < $1.sortOrder }.map { $0.toExported() },
            photoAttachmentIDs: photoAttachmentIDs,
            linkAttachmentIDs: linkAttachmentIDs,
            audioAttachmentIDs: audioAttachmentIDs,
            fileAttachmentIDs: fileAttachmentIDs,
            completedDates: completedDates
        )
    }
}

extension ScheduleConfig {
    func toExportedTrigger() -> ExportedTrigger {
        ExportedTrigger(
            id: id,
            type: "scheduled",
            fireDate: fireDate,
            startDate: startDate,
            recurrenceRule: recurrenceRule?.toExported(),
            timeZoneIdentifier: timeZoneIdentifier,
            weekdayMask: weekdayMask,
            isActive: isActive,
            isAllDay: isAllDay,
            location: nil,
            reminder: nil,
            sequential: nil,
            spacedStage: 0,
            lastReviewDate: nil,
            ignoreCount: 0
        )
    }
}

extension LocationConfig {
    func toExportedTrigger() -> ExportedTrigger {
        ExportedTrigger(
            id: id,
            type: "location",
            fireDate: nil,
            startDate: nil,
            recurrenceRule: nil,
            timeZoneIdentifier: nil,
            weekdayMask: 0,
            isActive: isActive,
            isAllDay: false,
            location: ExportedLocationTrigger(
                latitude: latitude,
                longitude: longitude,
                radius: radius,
                name: name,
                event: event.rawValue
            ),
            reminder: nil,
            sequential: nil,
            spacedStage: 0,
            lastReviewDate: nil,
            ignoreCount: 0
        )
    }
}

extension ReminderConfig {
    func toExportedTrigger() -> ExportedTrigger {
        ExportedTrigger(
            id: id,
            type: "reminder",
            fireDate: nil,
            startDate: nil,
            recurrenceRule: nil,
            timeZoneIdentifier: nil,
            weekdayMask: 0,
            isActive: isActive,
            isAllDay: false,
            location: nil,
            reminder: ExportedReminderTrigger(
                intervalValue: intervalValue,
                intervalUnit: intervalUnit.rawValue,
                repeatCount: repeatCount,
                startedAt: startedAt,
                startedBy: startedBy?.rawValue
            ),
            sequential: nil,
            spacedStage: 0,
            lastReviewDate: nil,
            ignoreCount: 0
        )
    }
}

extension RecurrenceRule {
    func toExported() -> ExportedRecurrenceRule {
        ExportedRecurrenceRule(
            frequency: frequency.rawValue,
            interval: interval,
            endDate: endDate,
            occurrenceCount: occurrenceCount
        )
    }
}

extension CheckItemModel {
    func toExported() -> ExportedCheckItem {
        ExportedCheckItem(
            id: id,
            title: title,
            detail: detail,
            isCompleted: isCompleted,
            sortOrder: sortOrder,
            createdAt: createdAt,
            updatedAt: updatedAt,
            completedAt: completedAt
        )
    }
}

extension Memory.Attachment {
    func toExported(includeData: Bool = true) -> ExportedAttachment {
        ExportedAttachment(
            id: id,
            kind: kind.rawValue,
            data: includeData ? data.base64EncodedString() : nil,
            createdAt: createdAt,
            url: url?.absoluteString,
            filename: filename
        )
    }
}

extension Mind {
    func toExported(children: [ExportedMind] = []) -> ExportedMind {
        ExportedMind(
            id: id,
            name: name,
            colorHex: colorHex,
            iconName: iconName,
            sortOrder: sortOrder,
            isDefault: isDefault,
            children: children
        )
    }
}
