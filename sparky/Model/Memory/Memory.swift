//
//  Memory.swift
//  sparky
//

import Foundation
import SwiftData

@Model
final class Memory: Identifiable {
    // MARK: - Nested Types

    struct AttachmentKind: RawRepresentable, Hashable, Codable, Sendable {
        let rawValue: String

        init(rawValue: String) {
            self.rawValue = rawValue
        }

        static let photo = AttachmentKind(rawValue: "photo")
        static let link = AttachmentKind(rawValue: "link")
        static let audio = AttachmentKind(rawValue: "audio")
        static let file = AttachmentKind(rawValue: "file")
    }

    struct Attachment: Identifiable, Hashable, Sendable {
        let id: UUID
        var kind: AttachmentKind
        var data: Data
        var createdAt: Date
        var url: URL?
        var filename: String?

        init(id: UUID = UUID(),
             kind: AttachmentKind,
             data: Data,
             createdAt: Date,
             url: URL? = nil,
             filename: String? = nil) {
            self.id = id
            self.kind = kind
            self.data = data
            self.createdAt = createdAt
            self.url = url
            self.filename = filename
        }

        static func == (lhs: Attachment, rhs: Attachment) -> Bool {
            lhs.id == rhs.id
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }

    // MARK: - Persisted Properties

    @Attribute(.unique) var id: UUID
    var title: String
    var body: String?
    var statusRaw: String
    var isPinned: Bool
    var priorityRaw: Int?
    var dueDate: Date?
    var createdAt: Date?
    var updatedAt: Date?
    var userOrder: Int
    var autoCompleteOnChecklistCompletion: Bool

    @Relationship(deleteRule: .cascade, inverse: \CheckItemModel.memory)
    var checkItems: [CheckItemModel] = []

    // MARK: - New Trigger Configs (1:1 relationships)

    @Relationship(deleteRule: .cascade, inverse: \ScheduleConfig.memory)
    var scheduleConfig: ScheduleConfig?

    @Relationship(deleteRule: .cascade, inverse: \LocationConfig.memory)
    var locationConfig: LocationConfig?

    // MARK: - Legacy Triggers (kept temporarily for migration)

    @Relationship(deleteRule: .cascade, inverse: \MemoryTriggerModel.memory)
    var triggers: [MemoryTriggerModel] = []

    @Relationship(deleteRule: .cascade, inverse: \MemoryAttachmentReference.memory)
    var attachmentReferences: [MemoryAttachmentReference] = []

    @Relationship(deleteRule: .cascade, inverse: \MemoryCompletionDate.memory)
    var completionDateEntries: [MemoryCompletionDate] = []

    var space: Space?

    // MARK: - Transient Properties (not persisted, populated by service)

    @Transient var attachments: [Attachment] = []

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        title: String = "Untitled",
        body: String? = nil,
        statusRaw: String = "active",
        isPinned: Bool = false,
        priorityRaw: Int? = nil,
        dueDate: Date? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        userOrder: Int = 0,
        autoCompleteOnChecklistCompletion: Bool = false,
        checkItems: [CheckItemModel] = [],
        scheduleConfig: ScheduleConfig? = nil,
        locationConfig: LocationConfig? = nil,
        triggers: [MemoryTriggerModel] = [],
        attachmentReferences: [MemoryAttachmentReference] = [],
        completionDateEntries: [MemoryCompletionDate] = [],
        space: Space? = nil
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.statusRaw = statusRaw
        self.isPinned = isPinned
        self.priorityRaw = priorityRaw
        self.dueDate = dueDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.userOrder = userOrder
        self.autoCompleteOnChecklistCompletion = autoCompleteOnChecklistCompletion
        self.checkItems = checkItems
        self.scheduleConfig = scheduleConfig
        self.locationConfig = locationConfig
        self.triggers = triggers
        self.attachmentReferences = attachmentReferences
        self.completionDateEntries = completionDateEntries
        self.space = space
    }

    // MARK: - Computed Properties

    /// Alias for `space` - domain term "lobe" used across the app
    var lobe: Space? {
        get { space }
        set { space = newValue }
    }

    var status: MemoryStatus {
        get { MemoryStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    var note: String? {
        get { body }
        set { body = newValue }
    }

    var photoAttachmentIDs: [UUID] {
        attachmentIDs(for: AttachmentKind.photo.rawValue)
    }

    var linkAttachmentIDs: [UUID] {
        attachmentIDs(for: AttachmentKind.link.rawValue)
    }

    var audioAttachmentIDs: [UUID] {
        attachmentIDs(for: AttachmentKind.audio.rawValue)
    }

    var fileAttachmentIDs: [UUID] {
        attachmentIDs(for: AttachmentKind.file.rawValue)
    }

    var completedDates: [Date] {
        completionDateEntries.map(\.date).sorted()
    }

    var hasChecklist: Bool {
        !checkItems.isEmpty
    }

    // MARK: - New Config-based Computed Properties

    var hasSchedule: Bool {
        scheduleConfig?.isActive ?? false
    }

    var hasLocation: Bool {
        locationConfig?.isActive ?? false
    }

    var hasTriggers: Bool {
        hasSchedule || hasLocation
    }

    var hasRecurringTriggers: Bool {
        scheduleConfig?.hasRecurrence ?? false
    }

    var hasAttachments: Bool {
        !attachments.isEmpty
    }

    var isCompleted: Bool {
        status == .completed
    }

    // MARK: - Methods

    func isCompleted(for date: Date) -> Bool {
        if status == .completed {
            return true
        }
        let calendar = Calendar.current
        return completedDates.contains { calendar.isDate($0, inSameDayAs: date) }
    }

    func nextFireDate(referenceDate: Date = Date()) -> Date? {
        guard hasTriggers else { return nil }

        var nextDates: [Date] = []

        if let schedule = scheduleConfig, schedule.isActive,
           let date = schedule.nextFireDate(after: referenceDate) {
            nextDates.append(date)
        }

        // Location triggers don't have a "next fire date" in the traditional sense
        // They fire based on geofence events

        return nextDates.min()
    }

    func dates(from startDate: Date, to endDate: Date) -> [Date] {
        guard let schedule = scheduleConfig, schedule.isActive else { return [] }
        return schedule.dates(from: startDate, to: endDate)
    }

    func dates(within range: Range<Date>) -> [Date] {
        return dates(from: range.lowerBound, to: range.upperBound)
    }

    func shouldAutoCompleteChecklist(autoCompleteEnabled: Bool) -> Bool {
        autoCompleteOnChecklistCompletion || autoCompleteEnabled
    }

    private func attachmentIDs(for kindRaw: String) -> [UUID] {
        attachmentReferences
            .filter { $0.kindRaw == kindRaw }
            .sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder {
                    return lhs.sortOrder < rhs.sortOrder
                }
                return lhs.createdAt < rhs.createdAt
            }
            .map(\.id)
    }
}

// MARK: - Static Factory Methods

extension Memory {
    static func createDefaultScheduleConfig(
        minutes: Int = 15,
        fromDate: Date = Date()
    ) -> ScheduleConfig {
        ScheduleConfig.createDefault(minutes: minutes, from: fromDate)
    }

    static func createDefaultLocationConfig() -> LocationConfig {
        LocationConfig.createDefault()
    }
}
