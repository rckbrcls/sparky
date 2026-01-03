//
//  MemoryModel.swift
//  i-cant-miss
//

import Foundation

struct MemoryModel: Identifiable, Hashable {
    struct AttachmentKind: RawRepresentable, Hashable, Codable {
        let rawValue: String

        init(rawValue: String) {
            self.rawValue = rawValue
        }

        static let photo = AttachmentKind(rawValue: "photo")
        static let link = AttachmentKind(rawValue: "link")
        static let audio = AttachmentKind(rawValue: "audio")
        static let file = AttachmentKind(rawValue: "file")
    }

    struct Attachment: Identifiable, Hashable {
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

    let id: UUID
    var title: String
    var body: String?
    var createdAt: Date
    var updatedAt: Date
    var status: MemoryStatus
    var isPinned: Bool
    var dueDate: Date?
    var space: SpaceModel?
    var triggers: [MemoryTriggerModel]
    var checkItems: [CheckItemModel]
    var autoCompleteOnChecklistCompletion: Bool
    // Fixed content attributes (replacing dynamic contents array)
    var note: String?
    var photoAttachmentIDs: [UUID]
    var linkAttachmentIDs: [UUID]
    var audioAttachmentIDs: [UUID]
    var fileAttachmentIDs: [UUID]
    var attachments: [Attachment]
    /// Dates on which this memory was marked as completed (for recurring memories)
    var completedDates: [Date]

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

    /// Checks if this memory is completed for a specific date (for recurring memories)
    /// - Parameter date: The date to check completion for
    /// - Returns: True if the memory was marked as completed on that specific date
    func isCompleted(for date: Date) -> Bool {
        // If the memory status is completed globally, it's completed for all dates
        if status == .completed {
            return true
        }
        // Check if this specific date is in the completedDates array
        let calendar = Calendar.current
        return completedDates.contains { calendar.isDate($0, inSameDayAs: date) }
    }

    nonisolated func nextFireDate(referenceDate: Date = Date()) -> Date? {
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

    /// Returns all occurrence dates for this memory within the specified date range
    /// This is essential for calendar views that need to show all occurrences of recurring events
    nonisolated func dates(from startDate: Date, to endDate: Date) -> [Date] {
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

    /// Returns all occurrence dates for this memory within the specified date range (Range<Date> version)
    nonisolated func dates(within range: Range<Date>) -> [Date] {
        return dates(from: range.lowerBound, to: range.upperBound)
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

// MARK: - Reminder Trigger Convenience Methods

extension MemoryModel {
    /// Creates a single-time alarm trigger that fires once after X minutes
    /// - Parameters:
    ///   - minutes: The number of minutes from now when the alarm should fire (default: 15)
    ///   - fromDate: The reference date to calculate from (default: now)
    /// - Returns: A configured MemoryTriggerModel for a single alarm notification
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
            recurrenceRule: nil, // No recurrence - single alarm only
            timeZoneIdentifier: TimeZone.current.identifier,
            weekdayMask: 0,
            isActive: true,
            location: nil,
            person: nil,
            sequential: nil,
            spacedStage: 0,
            lastReviewDate: nil,
            ignoreCount: 0
        )
    }
}
