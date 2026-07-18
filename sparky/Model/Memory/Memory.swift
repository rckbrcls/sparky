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
    var completedAt: Date?
    var userOrder: Int
    var autoCompleteOnChecklistCompletion: Bool

    @Relationship(deleteRule: .cascade, inverse: \CheckItemModel.memory)
    var checkItems: [CheckItemModel] = []

    // MARK: - Trigger Configs (1:1 relationships)

    @Relationship(deleteRule: .cascade, inverse: \ScheduleConfig.memory)
    var scheduleConfig: ScheduleConfig?

    @Relationship(deleteRule: .cascade, inverse: \LocationConfig.memory)
    var locationConfig: LocationConfig?

    @Relationship(deleteRule: .cascade, inverse: \MemoryAttachmentReference.memory)
    var attachmentReferences: [MemoryAttachmentReference] = []

    @Relationship(deleteRule: .cascade, inverse: \MemoryCompletionDate.memory)
    var completionDateEntries: [MemoryCompletionDate] = []

    var mind: Mind?

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
        completedAt: Date? = nil,
        userOrder: Int = 0,
        autoCompleteOnChecklistCompletion: Bool = false,
        checkItems: [CheckItemModel] = [],
        scheduleConfig: ScheduleConfig? = nil,
        locationConfig: LocationConfig? = nil,
        attachmentReferences: [MemoryAttachmentReference] = [],
        completionDateEntries: [MemoryCompletionDate] = [],
        mind: Mind? = nil
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
        self.completedAt = completedAt
        self.userOrder = userOrder
        self.autoCompleteOnChecklistCompletion = autoCompleteOnChecklistCompletion
        self.checkItems = checkItems
        self.scheduleConfig = scheduleConfig
        self.locationConfig = locationConfig
        self.attachmentReferences = attachmentReferences
        self.completionDateEntries = completionDateEntries
        self.mind = mind
    }

    // MARK: - Computed Properties

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

    // MARK: - Config-based Computed Properties

    var hasSchedule: Bool {
        scheduleConfig?.isActive ?? false
    }

    var hasLocation: Bool {
        locationConfig?.isActive ?? false
    }

    var hasFocus: Bool {
        scheduleConfig?.isActive == true && (scheduleConfig?.focusEnabled ?? false)
    }

    func focusRecipe() -> FocusRecipe? {
        guard let schedule = scheduleConfig, schedule.isActive else { return nil }
        return FocusRecipe.resolve(schedule: schedule)
    }

    var hasTriggers: Bool {
        hasSchedule || hasLocation
    }

    var hasRecurringTriggers: Bool {
        scheduleConfig?.hasRecurrence ?? false
    }

    var hasIntraDayRecurrence: Bool {
        guard let rule = scheduleConfig?.recurrenceRule else { return false }
        return rule.frequency == .hourly || rule.frequency == .minutely
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
        if hasIntraDayRecurrence {
            return completedDates.contains {
                calendar.isDate($0, inSameDayAs: date) &&
                calendar.component(.hour, from: $0) == calendar.component(.hour, from: date) &&
                calendar.component(.minute, from: $0) == calendar.component(.minute, from: date)
            }
        }
        return completedDates.contains { calendar.isDate($0, inSameDayAs: date) }
    }

    func nextFireDate(referenceDate: Date = Date()) -> Date? {
        guard hasTriggers else { return nil }

        if let schedule = scheduleConfig, schedule.isActive,
           let date = schedule.nextFireDate(after: referenceDate) {
            return date
        }

        return nil
    }

    func dates(from startDate: Date, to endDate: Date) -> [Date] {
        if let schedule = scheduleConfig, schedule.isActive {
            return schedule.dates(from: startDate, to: endDate)
        }
        return []
    }

    func dates(within range: Range<Date>) -> [Date] {
        return dates(from: range.lowerBound, to: range.upperBound)
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
