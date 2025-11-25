//
//  ScheduledTrigger.swift
//  i-cant-miss
//
//  Created by Codex on 13/10/25.
//

import Foundation

/// Trigger agendado para data e hora específicas
struct ScheduledTrigger: TriggerProtocol {
    let id: UUID
    var type: MemoryTriggerType { .scheduled }
    var fireDate: Date?
    var startDate: Date?
    var recurrenceRule: RecurrenceRule?
    var timeZoneIdentifier: String?
    var weekdayMask: Int16
    var isActive: Bool
    var spacedStage: Int
    var lastReviewDate: Date?
    var ignoreCount: Int

    init(
        id: UUID = UUID(),
        fireDate: Date? = nil,
        startDate: Date? = nil,
        recurrenceRule: RecurrenceRule? = nil,
        timeZoneIdentifier: String? = nil,
        weekdayMask: Int16 = 0,
        isActive: Bool = true,
        spacedStage: Int = 0,
        lastReviewDate: Date? = nil,
        ignoreCount: Int = 0
    ) {
        self.id = id
        self.fireDate = fireDate
        self.startDate = startDate
        self.recurrenceRule = recurrenceRule
        self.timeZoneIdentifier = timeZoneIdentifier
        self.weekdayMask = weekdayMask
        self.isActive = isActive
        self.spacedStage = spacedStage
        self.lastReviewDate = lastReviewDate
        self.ignoreCount = ignoreCount
    }
}
