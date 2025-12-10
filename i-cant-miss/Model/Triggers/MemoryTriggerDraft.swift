//
//  MemoryTriggerDraft.swift
//  i-cant-miss
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
    var location: MemoryTriggerModel.TriggerLocation?
    var person: MemoryTriggerModel.TriggerPerson?
    var sequential: MemoryTriggerModel.TriggerSequential?
    var focus: MemoryTriggerModel.TriggerFocus?
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
        focus: MemoryTriggerModel.TriggerFocus? = nil,
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
        self.focus = focus
        self.spacedStage = spacedStage
        self.lastReviewDate = lastReviewDate
        self.ignoreCount = ignoreCount
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
            location: location,
            person: person,
            sequential: sequential,
            focus: focus,
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
