//
//  Domain.swift
//  i-cant-miss
//
//  Created by Codex on 13/10/25.
//

import Foundation
import CoreData

enum ReminderStatus: String, CaseIterable, Identifiable {
    case active
    case completed
    case overdue
    case archived

    var id: String { rawValue }
}

enum ReminderPriority: Int16, CaseIterable, Identifiable {
    case low = 0
    case medium = 1
    case high = 2

    var id: Int16 { rawValue }

    var iconName: String {
        switch self {
        case .low: return "exclamationmark"
        case .medium: return "exclamationmark.2"
        case .high: return "exclamationmark.3"
        }
    }
}

enum ReminderTriggerType: String, CaseIterable, Identifiable {
    case time
    case dayOfWeek
    case location
    case person
    case importantDate

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .time: return "clock"
        case .dayOfWeek: return "calendar"
        case .location: return "mappin.and.ellipse"
        case .person: return "person.crop.circle"
        case .importantDate: return "gift"
        }
    }

    var label: String {
        switch self {
        case .time: return "Time"
        case .dayOfWeek: return "Weekday"
        case .location: return "Location"
        case .person: return "Person"
        case .importantDate: return "Important Date"
        }
    }
}

enum LocationEvent: String, CaseIterable, Identifiable {
    case onEntry
    case onExit

    var id: String { rawValue }

    var label: String {
        switch self {
        case .onEntry: return "Arrive"
        case .onExit: return "Leave"
        }
    }
}

struct RecurrenceRule: Hashable, Codable {
    enum Frequency: String, Codable, CaseIterable {
        case daily
        case weekly
        case monthly
        case yearly
    }

    var frequency: Frequency
    var interval: Int
    var endDate: Date?
    var occurrenceCount: Int?

    init(frequency: Frequency, interval: Int = 1, endDate: Date? = nil, occurrenceCount: Int? = nil) {
        self.frequency = frequency
        self.interval = max(1, interval)
        self.endDate = endDate
        self.occurrenceCount = occurrenceCount
    }
}

struct SpacedRepetitionSchedule: Hashable, Codable {
    let stages: [Int]
    var currentStageIndex: Int
    var lastReviewDate: Date?

    init(stages: [Int] = [1, 3, 7, 14, 30, 60, 90],
         currentStageIndex: Int = 0,
         lastReviewDate: Date? = nil) {
        self.stages = stages
        self.currentStageIndex = min(max(0, currentStageIndex), stages.count - 1)
        self.lastReviewDate = lastReviewDate
    }

    var currentIntervalDays: Int {
        stages[currentStageIndex]
    }

    func nextReviewDate(from referenceDate: Date = Date()) -> Date {
        let days = Double(currentIntervalDays)
        return Calendar.current.date(byAdding: .day, value: Int(days), to: referenceDate) ?? referenceDate
    }
}

struct LeadTimeConfiguration: Hashable, Codable, Identifiable {
    let id: UUID
    let offset: TimeInterval

    init(id: UUID = UUID(), offset: TimeInterval) {
        self.id = id
        self.offset = offset
    }
}

struct ReminderTriggerModel: Identifiable, Hashable {
    let id: UUID
    let type: ReminderTriggerType
    var fireDate: Date?
    var startDate: Date?
    var recurrenceRule: RecurrenceRule?
    var timeZoneIdentifier: String?
    var weekdayMask: Int16
    var isActive: Bool
    var location: TriggerLocation?
    var person: TriggerPerson?
    var spacedStage: Int
    var lastReviewDate: Date?
    var ignoreCount: Int

    struct TriggerLocation: Hashable {
        var latitude: Double
        var longitude: Double
        var radius: Double
        var name: String?
        var event: LocationEvent
    }

    struct TriggerPerson: Hashable {
        var name: String
        var contactIdentifier: String?
    }
}

struct ReminderModel: Identifiable, Hashable {
    let id: UUID
    var title: String
    var notes: String?
    var status: ReminderStatus
    var priority: ReminderPriority
    var createdAt: Date
    var updatedAt: Date
    var lastCompletionDate: Date?
    var snoozeCount: Int
    var triggers: [ReminderTriggerModel]
    var importantDate: ImportantDateModel?

    var isArchived: Bool {
        status == .archived
    }
}

struct ReminderSnoozeModel: Identifiable, Hashable {
    let id: UUID
    var originalFireDate: Date
    var newFireDate: Date
    var createdAt: Date
}

struct ReminderTriggerDraft: Identifiable {
    let id: UUID
    var type: ReminderTriggerType
    var fireDate: Date?
    var startDate: Date?
    var recurrenceRule: RecurrenceRule?
    var timeZoneIdentifier: String?
    var weekdayMask: Int16
    var isActive: Bool
    var location: ReminderTriggerModel.TriggerLocation?
    var person: ReminderTriggerModel.TriggerPerson?
    var spacedStage: Int
    var lastReviewDate: Date?
    var ignoreCount: Int

    init(
        id: UUID = UUID(),
        type: ReminderTriggerType,
        fireDate: Date? = nil,
        startDate: Date? = nil,
        recurrenceRule: RecurrenceRule? = nil,
        timeZoneIdentifier: String? = nil,
        weekdayMask: Int16 = 0,
        isActive: Bool = true,
        location: ReminderTriggerModel.TriggerLocation? = nil,
        person: ReminderTriggerModel.TriggerPerson? = nil,
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
        self.location = location
        self.person = person
        self.spacedStage = spacedStage
        self.lastReviewDate = lastReviewDate
        self.ignoreCount = ignoreCount
    }
}

struct ReminderDraft {
    var id: UUID = UUID()
    var title: String
    var notes: String?
    var status: ReminderStatus = .active
    var priority: ReminderPriority = .medium
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var triggers: [ReminderTriggerDraft] = []
    var importantDate: ImportantDateModel?
}

extension ReminderTriggerDraft {
    func toModel() -> ReminderTriggerModel {
        ReminderTriggerModel(
            id: id,
            type: type,
            fireDate: fireDate,
            startDate: startDate,
            recurrenceRule: recurrenceRule,
            timeZoneIdentifier: timeZoneIdentifier,
            weekdayMask: weekdayMask,
            isActive: isActive,
            location: location,
            person: person,
            spacedStage: spacedStage,
            lastReviewDate: lastReviewDate,
            ignoreCount: ignoreCount
        )
    }
}

struct NoteModel: Identifiable, Hashable {
    let id: UUID
    var title: String?
    var content: String
    var createdAt: Date
    var updatedAt: Date
    var isPinned: Bool
    var folder: FolderModel?
    var tags: [TagModel]
}

struct FolderModel: Identifiable, Hashable {
    let id: UUID
    var name: String
    var colorHex: String?
    var iconName: String?
    var isDefault: Bool
    var sortOrder: Int
}

struct TagModel: Identifiable, Hashable {
    let id: UUID
    var name: String
    var colorHex: String?
}

struct ImportantDateModel: Identifiable, Hashable {
    let id: UUID
    var title: String
    var date: Date
    var personName: String?
    var isBirthday: Bool
    var createdAt: Date
    var updatedAt: Date
    var leadTimes: [LeadTimeConfiguration]
}

// MARK: - Mapping helpers

extension Reminder {
    var status: ReminderStatus {
        ReminderStatus(rawValue: statusRaw ?? "active") ?? .active
    }

    func setStatus(_ status: ReminderStatus) {
        statusRaw = status.rawValue
    }

    var priorityLevel: ReminderPriority {
        ReminderPriority(rawValue: priority) ?? .medium
    }

    func setPriority(_ priority: ReminderPriority) {
        self.priority = priority.rawValue
    }

    func toModel() -> ReminderModel {
        let triggerSet = (triggers as? Set<ReminderTrigger>) ?? []

        return ReminderModel(
            id: id ?? UUID(),
            title: title ?? "Untitled reminder",
            notes: notes,
            status: status,
            priority: priorityLevel,
            createdAt: createdAt ?? Date(),
            updatedAt: updatedAt ?? Date(),
            lastCompletionDate: lastCompletionDate,
            snoozeCount: Int(snoozeCount),
            triggers: triggerSet
                .map { $0.toModel() }
                .sorted(by: { ($0.fireDate ?? .distantFuture) < ($1.fireDate ?? .distantFuture) }),
            importantDate: importantDate?.toModel()
        )
    }
}

extension ReminderTrigger {
    var triggerType: ReminderTriggerType {
        ReminderTriggerType(rawValue: typeRaw ?? ReminderTriggerType.time.rawValue) ?? .time
    }

    func setType(_ type: ReminderTriggerType) {
        typeRaw = type.rawValue
    }

    var locationEvent: LocationEvent? {
        guard let raw = locationEventRaw else { return nil }
        return LocationEvent(rawValue: raw)
    }

    func setLocationEvent(_ event: LocationEvent?) {
        locationEventRaw = event?.rawValue
    }

    var recurrence: RecurrenceRule? {
        guard let text = recurrenceRule, let data = text.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(RecurrenceRule.self, from: data)
    }

    func setRecurrence(_ rule: RecurrenceRule?) {
        guard let rule else {
            recurrenceRule = nil
            return
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(rule) {
            recurrenceRule = String(data: data, encoding: .utf8)
        }
    }

    func toModel() -> ReminderTriggerModel {
        let location: ReminderTriggerModel.TriggerLocation? = {
            guard triggerType == .location else { return nil }
            return ReminderTriggerModel.TriggerLocation(
                latitude: locationLatitude,
                longitude: locationLongitude,
                radius: locationRadius,
                name: locationName,
                event: locationEvent ?? .onEntry
            )
        }()

        let person: ReminderTriggerModel.TriggerPerson? = {
            guard triggerType == .person else { return nil }
            guard let name = personName else { return nil }
            return ReminderTriggerModel.TriggerPerson(name: name, contactIdentifier: personContactIdentifier)
        }()

        return ReminderTriggerModel(
            id: id ?? UUID(),
            type: triggerType,
            fireDate: fireDate,
            startDate: startDate,
            recurrenceRule: recurrence,
            timeZoneIdentifier: timeZoneIdentifier,
            weekdayMask: weekdayMask,
            isActive: isActive,
            location: location,
            person: person,
            spacedStage: Int(spacedStage),
            lastReviewDate: lastReviewDate,
            ignoreCount: Int(ignoreCount)
        )
    }
}

extension ReminderSnooze {
    func toModel() -> ReminderSnoozeModel {
        ReminderSnoozeModel(
            id: id ?? UUID(),
            originalFireDate: originalFireDate ?? Date(),
            newFireDate: newFireDate ?? Date(),
            createdAt: createdAt ?? Date()
        )
    }
}

extension Note {
    func toModel() -> NoteModel {
        let tagSet = (tags as? Set<Tag>) ?? []

        return NoteModel(
            id: id ?? UUID(),
            title: title,
            content: content ?? "",
            createdAt: createdAt ?? Date(),
            updatedAt: updatedAt ?? Date(),
            isPinned: isPinned,
            folder: folder?.toModel(),
            tags: tagSet.map { $0.toModel() }.sorted(by: { $0.name < $1.name })
        )
    }
}

extension Folder {
    func toModel() -> FolderModel {
        FolderModel(
            id: id ?? UUID(),
            name: name ?? "Folder",
            colorHex: colorHex,
            iconName: iconName,
            isDefault: isDefault,
            sortOrder: Int(sortOrder)
        )
    }
}

extension Tag {
    func toModel() -> TagModel {
        TagModel(id: id ?? UUID(), name: name ?? "Tag", colorHex: colorHex)
    }
}

extension ImportantDate {
    func toModel() -> ImportantDateModel {
        let leadTimesSet = (leadTimes as? Set<ImportantDateLeadTime>) ?? []

        return ImportantDateModel(
            id: id ?? UUID(),
            title: title ?? "Important Date",
            date: date ?? Date(),
            personName: personName,
            isBirthday: isBirthday,
            createdAt: createdAt ?? Date(),
            updatedAt: updatedAt ?? Date(),
            leadTimes: leadTimesSet
                .map { LeadTimeConfiguration(id: $0.id ?? UUID(), offset: TimeInterval($0.offsetSeconds)) }
                .sorted(by: { $0.offset < $1.offset })
        )
    }
}
