//
//  MemoryDomain.swift
//  i-cant-miss
//
//  Created by Codex on 09/03/24.
//

import Foundation

// MARK: - Recurrence Types

enum RecurrenceFrequency: String, CaseIterable, Identifiable, Codable {
    case daily
    case weekly
    case monthly
    case yearly

    var id: String { rawValue }
}

struct RecurrenceRule: Codable, Hashable {
    let frequency: RecurrenceFrequency
    let interval: Int
    let endDate: Date?

    init(frequency: RecurrenceFrequency, interval: Int = 1, endDate: Date? = nil) {
        self.frequency = frequency
        self.interval = interval
        self.endDate = endDate
    }
}

// MARK: - Location Types

enum LocationEvent: String, CaseIterable, Identifiable, Codable {
    case onEntry
    case onExit

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .onEntry: return "On Entry"
        case .onExit: return "On Exit"
        }
    }
}

// MARK: - Memory Trigger Types

enum MemoryTriggerType: String, CaseIterable, Identifiable, Codable {
    case scheduled
    case location
    case person
    case sequential

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .scheduled: return "clock.badge"
        case .location: return "mappin.and.ellipse"
        case .person: return "person.crop.circle"
        case .sequential: return "arrowshape.turn.up.right.circle"
        }
    }

    var label: String {
        switch self {
        case .scheduled: return "Date & Time"
        case .location: return "Location"
        case .person: return "Person"
        case .sequential: return "Sequential"
        }
    }
}

struct MemoryTriggerModel: Identifiable, Hashable, Codable {
    let id: UUID
    let type: MemoryTriggerType
    var fireDate: Date?
    var startDate: Date?
    var recurrenceRule: RecurrenceRule?
    var timeZoneIdentifier: String?
    var weekdayMask: Int16
    var isActive: Bool
    var location: TriggerLocation?
    var person: TriggerPerson?
    var sequential: TriggerSequential?
    var spacedStage: Int
    var lastReviewDate: Date?
    var ignoreCount: Int

    struct TriggerLocation: Hashable, Codable {
        var latitude: Double
        var longitude: Double
        var radius: Double
        var name: String?
        var event: LocationEvent
    }

    struct TriggerPerson: Hashable, Codable {
        var name: String
        var contactIdentifier: String?
    }

    struct TriggerSequential: Hashable, Codable {
        var previousMemoryID: UUID?
        var nextMemoryID: UUID?
    }
}

struct MemoryTriggerDraft: Identifiable, Hashable {
    let id: UUID
    var type: MemoryTriggerType
    var fireDate: Date?
    var startDate: Date?
    var recurrenceRule: RecurrenceRule?
    var timeZoneIdentifier: String?
    var weekdayMask: Int16
    var isActive: Bool
    var location: MemoryTriggerModel.TriggerLocation?
    var person: MemoryTriggerModel.TriggerPerson?
    var sequential: MemoryTriggerModel.TriggerSequential?
    var spacedStage: Int
    var lastReviewDate: Date?
    var ignoreCount: Int

    init(
        id: UUID = UUID(),
        type: MemoryTriggerType,
        fireDate: Date? = nil,
        startDate: Date? = nil,
        recurrenceRule: RecurrenceRule? = nil,
        timeZoneIdentifier: String? = nil,
        weekdayMask: Int16 = 0,
        isActive: Bool = true,
        location: MemoryTriggerModel.TriggerLocation? = nil,
        person: MemoryTriggerModel.TriggerPerson? = nil,
        sequential: MemoryTriggerModel.TriggerSequential? = nil,
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
        self.sequential = sequential
        self.spacedStage = spacedStage
        self.lastReviewDate = lastReviewDate
        self.ignoreCount = ignoreCount
    }
}

extension MemoryTriggerDraft {
    func toModel() -> MemoryTriggerModel {
        MemoryTriggerModel(
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
            sequential: sequential,
            spacedStage: spacedStage,
            lastReviewDate: lastReviewDate,
            ignoreCount: ignoreCount
        )
    }
}

extension MemoryTriggerModel {
    func nextFireDate(after reference: Date = Date()) -> Date? {
        switch type {
        case .scheduled:
            return nextScheduledOccurrence(from: reference)
        case .location, .person, .sequential:
            return startDate ?? fireDate
        }
    }

    private func nextScheduledOccurrence(from reference: Date) -> Date? {
        // If there's a weekdayMask, use weekday logic
        if weekdayMask != 0 {
            return nextWeekdayOccurrence(from: reference)
        }

        // If there's only a fireDate without recurrence, return the fireDate
        guard let fireDate = fireDate else {
            return startDate
        }

        // If there's recurrence, calculate next occurrence
        if let recurrence = recurrenceRule {
            return nextRecurrenceDate(from: reference, fireDate: fireDate, recurrence: recurrence)
        }

        // Simple case: just a date/time
        return fireDate >= reference ? fireDate : nil
    }

    private func nextRecurrenceDate(from reference: Date, fireDate: Date, recurrence: RecurrenceRule) -> Date? {
        let calendar = Calendar.current

        // If reference date is before fireDate, return fireDate
        if reference < fireDate {
            return fireDate
        }

        switch recurrence.frequency {
        case .daily:
            var nextDate = fireDate
            while nextDate <= reference {
                guard let date = calendar.date(byAdding: .day, value: recurrence.interval, to: nextDate) else {
                    return nil
                }
                nextDate = date
            }
            return nextDate

        case .weekly:
            var nextDate = fireDate
            while nextDate <= reference {
                guard let date = calendar.date(byAdding: .weekOfYear, value: recurrence.interval, to: nextDate) else {
                    return nil
                }
                nextDate = date
            }
            return nextDate

        case .monthly:
            var nextDate = fireDate
            while nextDate <= reference {
                guard let date = calendar.date(byAdding: .month, value: recurrence.interval, to: nextDate) else {
                    return nil
                }
                nextDate = date
            }
            return nextDate

        case .yearly:
            var nextDate = fireDate
            while nextDate <= reference {
                guard let date = calendar.date(byAdding: .year, value: recurrence.interval, to: nextDate) else {
                    return nil
                }
                nextDate = date
            }
            return nextDate
        }
    }

    private func nextWeekdayOccurrence(from reference: Date) -> Date? {
        guard weekdayMask != 0 else { return fireDate ?? startDate }
        let calendar = Calendar.current
        let targetDays = (1...7).compactMap { day -> Int? in
            let bit = 1 << day
            return (weekdayMask & Int16(bit)) != 0 ? day : nil
        }

        guard !targetDays.isEmpty else { return fireDate ?? startDate }

        for dayOffset in 0..<7 {
            let candidate = calendar.date(byAdding: .day, value: dayOffset, to: reference) ?? reference
            let weekday = calendar.component(.weekday, from: candidate)
            if targetDays.contains(weekday) {
                // If there's a fireDate, use its time
                if let fireDate = fireDate {
                    let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: fireDate)
                    if let dateWithTime = calendar.date(bySettingHour: timeComponents.hour ?? 0,
                                                         minute: timeComponents.minute ?? 0,
                                                         second: timeComponents.second ?? 0,
                                                         of: candidate) {
                        let start = startDate ?? dateWithTime
                        return dateWithTime < start ? start : dateWithTime
                    }
                }
                let start = startDate ?? candidate
                return candidate < start ? start : candidate
            }
        }

        return fireDate ?? startDate
    }
}

// MARK: - Memory Status and Priority

enum MemoryStatus: String, CaseIterable, Identifiable, Codable {
    case active
    case completed

    var id: String { rawValue }
}

enum MemoryPriority: Int16, CaseIterable, Identifiable, Codable {
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

    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
}

// MARK: - Memory Types and Filters

enum MemoryType: String, CaseIterable, Identifiable {
    case text
    case checklist
    case photos
    case triggered

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .text: return "Text"
        case .checklist: return "Checklist"
        case .photos: return "Photos"
        case .triggered: return "With Triggers"
        }
    }

    var label: String {
        switch self {
        case .text: return "Notes"
        case .checklist: return "Checklists"
        case .photos: return "Photos"
        case .triggered: return "Triggers"
        }
    }

    var systemImage: String {
        switch self {
        case .text: return "note.text"
        case .checklist: return "checklist"
        case .photos: return "photo.on.rectangle"
        case .triggered: return "alarm"
        }
    }
}

enum MemoryContentFilterType: String, CaseIterable, Identifiable {
    case richText
    case checklist
    case photos
    case links
    case audio

    var id: String { rawValue }

    var label: String {
        switch self {
        case .richText: return "Notes"
        case .checklist: return "Checklists"
        case .photos: return "Photos"
        case .links: return "Links"
        case .audio: return "Audio"
        }
    }

    var systemImage: String {
        switch self {
        case .richText: return "text.justify.leading"
        case .checklist: return "checklist"
        case .photos: return "photo.on.rectangle.angled"
        case .links: return "link"
        case .audio: return "waveform"
        }
    }
}

enum MemoryTimelineFilter: String, CaseIterable, Identifiable {
    case all
    case today
    case nextSevenDays
    case later
    case recurring
    case overdue
    case thisWeek
    case byPriority
    case byTriggerType
    case timeTriggers
    case locationTriggers
    case personTriggers
    case noTriggers

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .all: return "All"
        case .today: return "Today"
        case .nextSevenDays: return "Next 7 Days"
        case .later: return "Later"
        case .recurring: return "Recurring"
        case .overdue: return "Overdue"
        case .thisWeek: return "This Week"
        case .byPriority: return "Priority"
        case .byTriggerType: return "Type"
        case .timeTriggers: return "Scheduled"
        case .locationTriggers: return "Location"
        case .personTriggers: return "People"
        case .noTriggers: return "No Triggers"
        }
    }

    var storageKey: String {
        switch self {
        case .all: return "all"
        case .today: return "today"
        case .nextSevenDays: return "nextSevenDays"
        case .later: return "later"
        case .recurring: return "recurring"
        case .overdue: return "overdue"
        case .thisWeek: return "thisWeek"
        case .byPriority: return "byPriority"
        case .byTriggerType: return "byTriggerType"
        case .timeTriggers: return "timeTriggers"
        case .locationTriggers: return "locationTriggers"
        case .personTriggers: return "personTriggers"
        case .noTriggers: return "noTriggers"
        }
    }

    init?(storageKey: String) {
        if let match = Self.allCases.first(where: { $0.storageKey == storageKey }) {
            self = match
        } else {
            return nil
        }
    }
}

// MARK: - Check Items

struct CheckItemModel: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var detail: String?
    var isCompleted: Bool
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date
    var completedAt: Date?
}

struct CheckItemDraft: Identifiable, Hashable {
    let id: UUID
    var title: String
    var detail: String
    var isCompleted: Bool
    var sortOrder: Int
    var createdAt: Date
    var completedAt: Date?

    init(id: UUID = UUID(),
         title: String = "",
         detail: String = "",
         isCompleted: Bool = false,
         sortOrder: Int = 0,
         createdAt: Date = Date(),
         completedAt: Date? = nil) {
        self.id = id
        self.title = title
        self.detail = detail
        self.isCompleted = isCompleted
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.completedAt = completedAt
    }
}

// MARK: - Memory Content Types

enum MemoryContent: Codable, Hashable {
    case richText(String)
    case checklist([CheckItemModel])
    case photos([UUID])
    case links([UUID])
    case audio([UUID])

    private enum CodingKeys: String, CodingKey {
        case type
        case text
        case items
        case attachmentIDs
    }

    private enum ContentType: String, Codable {
        case richText
        case checklist
        case photos
        case links
        case audio
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ContentType.self, forKey: .type)

        switch type {
        case .richText:
            let text = try container.decode(String.self, forKey: .text)
            self = .richText(text)
        case .checklist:
            let items = try container.decode([CheckItemModel].self, forKey: .items)
            self = .checklist(items)
        case .photos:
            let ids = try container.decode([UUID].self, forKey: .attachmentIDs)
            self = .photos(ids)
        case .links:
            let ids = try container.decode([UUID].self, forKey: .attachmentIDs)
            self = .links(ids)
        case .audio:
            let ids = try container.decode([UUID].self, forKey: .attachmentIDs)
            self = .audio(ids)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .richText(let text):
            try container.encode(ContentType.richText, forKey: .type)
            try container.encode(text, forKey: .text)
        case .checklist(let items):
            try container.encode(ContentType.checklist, forKey: .type)
            try container.encode(items, forKey: .items)
        case .photos(let ids):
            try container.encode(ContentType.photos, forKey: .type)
            try container.encode(ids, forKey: .attachmentIDs)
        case .links(let ids):
            try container.encode(ContentType.links, forKey: .type)
            try container.encode(ids, forKey: .attachmentIDs)
        case .audio(let ids):
            try container.encode(ContentType.audio, forKey: .type)
            try container.encode(ids, forKey: .attachmentIDs)
        }
    }
}

// MARK: - Content Extensions

extension Array where Element == MemoryContent {
    func aggregatedBodyText() -> String? {
        let textContents = self.compactMap { content -> String? in
            switch content {
            case .richText(let text):
                return text
            default:
                return nil
            }
        }
        let combined = textContents.joined(separator: "\n\n")
        return combined.isEmpty ? nil : combined
    }

    func referencedAttachmentIDs() -> [UUID] {
        return self.flatMap { content -> [UUID] in
            switch content {
            case .photos(let attachmentIDs):
                return attachmentIDs
            case .links(let attachmentIDs):
                return attachmentIDs
            case .audio(let attachmentIDs):
                return attachmentIDs
            default:
                return []
            }
        }
    }

    func flattenedChecklistItems() -> [CheckItemModel] {
        return self.compactMap { content -> [CheckItemModel]? in
            if case .checklist(let items) = content {
                return items
            }
            return nil
        }.flatMap { $0 }
    }
}

// MARK: - Content Helpers

struct MemoryDomain {
    struct MemoryContentBundle: Codable {
        let contents: [MemoryContent]
    }
}

// MARK: - Memory Models

struct MemoryModel: Identifiable, Hashable {
    struct AttachmentKind: RawRepresentable, Hashable, Codable {
        let rawValue: String

        init(rawValue: String) {
            self.rawValue = rawValue
        }

        static let photo = AttachmentKind(rawValue: "photo")
        static let link = AttachmentKind(rawValue: "link")
        static let audio = AttachmentKind(rawValue: "audio")
    }

    struct Attachment: Identifiable, Hashable {
        let id: UUID
        var kind: AttachmentKind
        var data: Data
        var createdAt: Date
        var url: URL?

        init(id: UUID = UUID(),
             kind: AttachmentKind,
             data: Data,
             createdAt: Date,
             url: URL? = nil) {
            self.id = id
            self.kind = kind
            self.data = data
            self.createdAt = createdAt
            self.url = url
        }

        static func == (lhs: Attachment, rhs: Attachment) -> Bool {
            lhs.id == rhs.id
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }

    let id: UUID
    var title: String
    var body: String?
    var createdAt: Date
    var updatedAt: Date
    var status: MemoryStatus
    var isPinned: Bool
    var priority: MemoryPriority?
    var dueDate: Date?
    var space: SpaceModel?
    var triggers: [MemoryTriggerModel]
    var checkItems: [CheckItemModel]
    var autoCompleteOnChecklistCompletion: Bool
    var contents: [MemoryContent]
    var attachments: [Attachment]

    var hasChecklist: Bool {
        !checkItems.isEmpty
    }

    var hasTriggers: Bool {
        triggers.contains { $0.isActive }
    }

    var hasRecurringTriggers: Bool {
        triggers.contains { $0.recurrenceRule != nil }
    }

    var hasAttachments: Bool {
        !attachments.isEmpty
    }

    var isCompleted: Bool {
        status == .completed
    }

    var isInbox: Bool {
        status == .active && !hasTriggers && space == nil
    }

    func nextFireDate(referenceDate: Date = Date()) -> Date? {
        let activeTriggers = triggers.filter { $0.isActive }
        guard !activeTriggers.isEmpty else { return nil }

        var nextDates: [Date] = []
        for trigger in activeTriggers {
            if let date = trigger.nextFireDate(after: referenceDate) {
                nextDates.append(date)
            }
        }

        return nextDates.min()
    }

    func shouldAutoCompleteChecklist(autoCompleteEnabled: Bool) -> Bool {
        autoCompleteOnChecklistCompletion || autoCompleteEnabled
    }

    static func == (lhs: MemoryModel, rhs: MemoryModel) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct MemoryDraft: Identifiable, Hashable {
    let id: UUID
    var title: String
    var status: MemoryStatus
    var priority: MemoryPriority?
    var isPinned: Bool
    var dueDate: Date?
    var spaceID: UUID?
    var triggers: [MemoryTriggerModel]
    var contents: [MemoryContent]
    var attachments: [MemoryModel.Attachment]
    var autoCompleteOnChecklistCompletion: Bool

    init(id: UUID = UUID(),
         title: String,
         status: MemoryStatus = .active,
         priority: MemoryPriority? = nil,
         isPinned: Bool = false,
         dueDate: Date? = nil,
         spaceID: UUID? = nil,
         triggers: [MemoryTriggerModel] = [],
         contents: [MemoryContent] = [],
         attachments: [MemoryModel.Attachment] = [],
         autoCompleteOnChecklistCompletion: Bool = false) {
        self.id = id
        self.title = title
        self.status = status
        self.priority = priority
        self.isPinned = isPinned
        self.dueDate = dueDate
        self.spaceID = spaceID
        self.triggers = triggers
        self.contents = contents
        self.attachments = attachments
        self.autoCompleteOnChecklistCompletion = autoCompleteOnChecklistCompletion
    }

    static func == (lhs: MemoryDraft, rhs: MemoryDraft) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Space Models

struct SpaceModel: Identifiable, Hashable {
    let id: UUID
    var name: String
    var colorHex: String?
    var iconName: String?
    var sortOrder: Int
    var parentID: UUID?
    var childIDs: [UUID]
    var isDefault: Bool

    init(id: UUID,
         name: String,
         colorHex: String? = nil,
         iconName: String? = nil,
         sortOrder: Int = 0,
         parentID: UUID? = nil,
         childIDs: [UUID] = [],
         isDefault: Bool = false) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.iconName = iconName
        self.sortOrder = sortOrder
        self.parentID = parentID
        self.childIDs = childIDs
        self.isDefault = isDefault
    }

    var isRoot: Bool { parentID == nil }
    var hasChildren: Bool { !childIDs.isEmpty }
}

extension SpaceModel {
    static let allSpacesIdentifier = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    static var allSpaces: SpaceModel {
        SpaceModel(
            id: allSpacesIdentifier,
            name: "All",
            colorHex: nil,
            iconName: "square.grid.2x2",
            sortOrder: Int.min,
            parentID: nil,
            childIDs: [],
            isDefault: true
        )
    }

    var isAllSpaces: Bool {
        id == SpaceModel.allSpacesIdentifier
    }

    func isAncestor(of space: SpaceModel, using lookup: (UUID) -> SpaceModel?) -> Bool {
        guard let parentID else { return false }
        if parentID == space.id { return true }
        guard let parent = lookup(parentID) else { return false }
        return parent.isAncestor(of: space, using: lookup)
    }
}

// MARK: - Tag Models

struct TagModel: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var colorHex: String?

    init(id: UUID, name: String, colorHex: String? = nil) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
    }
}
