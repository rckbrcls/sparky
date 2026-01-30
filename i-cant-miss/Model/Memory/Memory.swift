//
//  Memory.swift
//  i-cant-miss
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

    /// JSON-encoded MemoryContentBundle
    @Attribute(.externalStorage) var contentsData: Data?

    /// JSON-encoded trigger array
    @Attribute(.externalStorage) var triggersData: Data?

    var space: Space?

    // MARK: - Transient Properties (not persisted, populated by service)

    @Transient var triggers: [MemoryTriggerModel] = []
    @Transient var checkItems: [CheckItemModel] = []
    @Transient var note: String?
    @Transient var photoAttachmentIDs: [UUID] = []
    @Transient var linkAttachmentIDs: [UUID] = []
    @Transient var audioAttachmentIDs: [UUID] = []
    @Transient var fileAttachmentIDs: [UUID] = []
    @Transient var attachments: [Attachment] = []
    @Transient var completedDates: [Date] = []

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
        contentsData: Data? = nil,
        triggersData: Data? = nil,
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
        self.contentsData = contentsData
        self.triggersData = triggersData
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

    var hasChecklist: Bool {
        !checkItems.isEmpty
    }

    var hasTriggers: Bool {
        triggers.contains { $0.isActive }
    }

    var hasRecurringTriggers: Bool {
        triggers.contains { $0.recurrenceRule != nil || $0.weekdayMask != 0 }
    }

    var hasAttachments: Bool {
        !attachments.isEmpty
    }

    var isCompleted: Bool {
        status == .completed
    }

    var hasSequenceTrigger: Bool {
        triggers.contains { $0.type == .sequential && $0.sequential != nil }
    }

    var isCurrentInSequence: Bool {
        guard let seqTrigger = triggers.first(where: { $0.type == .sequential }),
              let seq = seqTrigger.sequential else {
            return false
        }

        if let startDate = seq.startDate {
            let calendar = Calendar.current
            if calendar.startOfDay(for: Date()) < calendar.startOfDay(for: startDate) {
                return false
            }
        }

        return seq.stepIndex == seq.currentStepIndex
    }

    var isNextInSequence: Bool {
        guard let seqTrigger = triggers.first(where: { $0.type == .sequential }),
              let seq = seqTrigger.sequential else {
            return false
        }

        if let startDate = seq.startDate {
            let calendar = Calendar.current
            if calendar.startOfDay(for: Date()) < calendar.startOfDay(for: startDate) {
                return true
            }
        }

        return seq.stepIndex != seq.currentStepIndex
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

    func dates(from startDate: Date, to endDate: Date) -> [Date] {
        let activeTriggers = triggers.filter { $0.isActive }
        guard !activeTriggers.isEmpty else { return [] }

        var allDates: Set<Date> = []

        for trigger in activeTriggers {
            guard trigger.type == .scheduled else { continue }
            let triggerDates = trigger.dates(from: startDate, to: endDate)
            allDates.formUnion(triggerDates)
        }

        return Array(allDates).sorted()
    }

    func dates(within range: Range<Date>) -> [Date] {
        return dates(from: range.lowerBound, to: range.upperBound)
    }

    func shouldAutoCompleteChecklist(autoCompleteEnabled: Bool) -> Bool {
        autoCompleteOnChecklistCompletion || autoCompleteEnabled
    }
}

// MARK: - Static Factory Methods

extension Memory {
    static func createSingleAlarmTrigger(
        minutes: Int = 15,
        fromDate: Date = Date()
    ) -> MemoryTriggerModel {
        let fireDate = fromDate.addingTimeInterval(TimeInterval(minutes * 60))

        return MemoryTriggerModel(
            id: UUID(),
            type: .scheduled,
            fireDate: fireDate,
            startDate: nil,
            recurrenceRule: nil,
            timeZoneIdentifier: TimeZone.current.identifier,
            weekdayMask: 0,
            isActive: true,
            location: nil,
            sequential: nil,
            spacedStage: 0,
            lastReviewDate: nil,
            ignoreCount: 0
        )
    }
}
