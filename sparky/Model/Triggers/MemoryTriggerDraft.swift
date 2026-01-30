//
//  MemoryTriggerDraft.swift
//  sparky
//

import Foundation

struct MemoryTriggerDraft: Identifiable, Hashable {
    let id: UUID
    var type: MemoryTriggerType
    var fireDate: Date?
    var startDate: Date?
    var recurrenceRule: RecurrenceRule?
    var timeZoneIdentifier: String?
    var weekdayMask: Int16
    var isActive: Bool
    var isAllDay: Bool
    var location: MemoryTriggerModel.TriggerLocation?
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
        isAllDay: Bool = false,
        location: MemoryTriggerModel.TriggerLocation? = nil,
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
        self.isAllDay = isAllDay
        self.location = location
        self.sequential = sequential
        self.spacedStage = spacedStage
        self.lastReviewDate = lastReviewDate
        self.ignoreCount = ignoreCount
    }
}

extension MemoryTriggerDraft {
    static func == (lhs: MemoryTriggerDraft, rhs: MemoryTriggerDraft) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Conversions

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
            isAllDay: isAllDay,
            location: location,
            sequential: sequential,
            spacedStage: spacedStage,
            lastReviewDate: lastReviewDate,
            ignoreCount: ignoreCount
        )
    }

    /// Converte para um trigger protocol
    func toTriggerProtocol() -> any TriggerProtocol {
        TriggerFactory.createTrigger(from: self)
    }
}
