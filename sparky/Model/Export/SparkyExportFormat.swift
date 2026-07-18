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
        version: String = "2.0",
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
    let completedAt: Date?
    let userOrder: Int
    let autoCompleteOnChecklistCompletion: Bool
    let mindID: UUID?
    let scheduleConfig: ExportedScheduleConfig?
    let locationConfig: ExportedLocationConfig?
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
        completedAt: Date? = nil,
        userOrder: Int = 0,
        autoCompleteOnChecklistCompletion: Bool = false,
        mindID: UUID? = nil,
        scheduleConfig: ExportedScheduleConfig? = nil,
        locationConfig: ExportedLocationConfig? = nil,
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
        self.completedAt = completedAt
        self.userOrder = userOrder
        self.autoCompleteOnChecklistCompletion = autoCompleteOnChecklistCompletion
        self.mindID = mindID
        self.scheduleConfig = scheduleConfig
        self.locationConfig = locationConfig
        self.checkItems = checkItems
        self.photoAttachmentIDs = photoAttachmentIDs
        self.linkAttachmentIDs = linkAttachmentIDs
        self.audioAttachmentIDs = audioAttachmentIDs
        self.fileAttachmentIDs = fileAttachmentIDs
        self.completedDates = completedDates
    }
}

// MARK: - Exported Schedule Config

struct ExportedScheduleConfig: Codable, Identifiable {
    let id: UUID
    let fireDate: Date?
    let startDate: Date?
    let recurrenceRule: ExportedRecurrenceRule?
    let timeZoneIdentifier: String?
    let weekdayMask: Int16
    let isActive: Bool
    let isAllDay: Bool
    let recurrenceEndType: String
    let focusEnabled: Bool
    let focusWorkDurationMinutes: Int
    let focusShortBreakDurationMinutes: Int
    let focusLongBreakDurationMinutes: Int
    let focusPomodorosUntilLongBreak: Int
    let focusAutoContinue: Bool

    init(
        id: UUID,
        fireDate: Date? = nil,
        startDate: Date? = nil,
        recurrenceRule: ExportedRecurrenceRule? = nil,
        timeZoneIdentifier: String? = nil,
        weekdayMask: Int16 = 0,
        isActive: Bool = true,
        isAllDay: Bool = false,
        recurrenceEndType: String = RecurrenceEndType.never.rawValue,
        focusEnabled: Bool = false,
        focusWorkDurationMinutes: Int = 0,
        focusShortBreakDurationMinutes: Int = 0,
        focusLongBreakDurationMinutes: Int = 0,
        focusPomodorosUntilLongBreak: Int = 0,
        focusAutoContinue: Bool = true
    ) {
        self.id = id
        self.fireDate = fireDate
        self.startDate = startDate
        self.recurrenceRule = recurrenceRule
        self.timeZoneIdentifier = timeZoneIdentifier
        self.weekdayMask = weekdayMask
        self.isActive = isActive
        self.isAllDay = isAllDay
        self.recurrenceEndType = recurrenceEndType
        self.focusEnabled = focusEnabled
        self.focusWorkDurationMinutes = focusWorkDurationMinutes
        self.focusShortBreakDurationMinutes = focusShortBreakDurationMinutes
        self.focusLongBreakDurationMinutes = focusLongBreakDurationMinutes
        self.focusPomodorosUntilLongBreak = focusPomodorosUntilLongBreak
        self.focusAutoContinue = focusAutoContinue
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

// MARK: - Exported Location Config

struct ExportedLocationConfig: Codable, Identifiable {
    let id: UUID
    let latitude: Double
    let longitude: Double
    let radius: Double
    let name: String?
    let event: String
    let isActive: Bool
    
    init(
        id: UUID,
        latitude: Double,
        longitude: Double,
        radius: Double,
        name: String? = nil,
        event: String,
        isActive: Bool = true
    ) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
        self.name = name
        self.event = event
        self.isActive = isActive
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
        return ExportedMemory(
            id: id,
            title: title,
            note: note,
            status: status.rawValue,
            isPinned: isPinned,
            dueDate: dueDate,
            createdAt: createdAt ?? Date(),
            updatedAt: updatedAt ?? createdAt ?? Date(),
            completedAt: completedAt,
            userOrder: userOrder,
            autoCompleteOnChecklistCompletion: autoCompleteOnChecklistCompletion,
            mindID: mind?.id,
            scheduleConfig: scheduleConfig?.toExported(),
            locationConfig: locationConfig?.toExported(),
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
    func toExported() -> ExportedScheduleConfig {
        ExportedScheduleConfig(
            id: id,
            fireDate: fireDate,
            startDate: startDate,
            recurrenceRule: recurrenceRule?.toExported(),
            timeZoneIdentifier: timeZoneIdentifier,
            weekdayMask: weekdayMask,
            isActive: isActive,
            isAllDay: isAllDay,
            recurrenceEndType: recurrenceEndType.rawValue,
            focusEnabled: focusEnabled,
            focusWorkDurationMinutes: focusWorkDurationMinutes,
            focusShortBreakDurationMinutes: focusShortBreakDurationMinutes,
            focusLongBreakDurationMinutes: focusLongBreakDurationMinutes,
            focusPomodorosUntilLongBreak: focusPomodorosUntilLongBreak,
            focusAutoContinue: focusAutoContinue
        )
    }
}

extension LocationConfig {
    func toExported() -> ExportedLocationConfig {
        ExportedLocationConfig(
            id: id,
            latitude: latitude,
            longitude: longitude,
            radius: radius,
            name: name,
            event: event.rawValue,
            isActive: isActive
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
