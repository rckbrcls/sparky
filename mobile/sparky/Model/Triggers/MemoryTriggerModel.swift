//
//  MemoryTriggerModel.swift
//  sparky
//
//  LEGACY: Kept in SwiftData schema to avoid migration crashes.
//  Do not read or write these triggers — use ScheduleConfig / LocationConfig instead.
//  Can be removed in a future release with a proper schema migration.

import Foundation
import SwiftData

@Model
final class MemoryTriggerModel: Identifiable {
    typealias TriggerLocation = MemoryTriggerLocation

    @Attribute(.unique) var id: UUID = UUID()
    var typeRaw: String = "scheduled"
    var fireDate: Date?
    var startDate: Date?
    var recurrenceFrequencyRaw: String?
    var recurrenceInterval: Int = 1
    var recurrenceEndDate: Date?
    var timeZoneIdentifier: String?
    var weekdayMask: Int16 = 0
    var isActive: Bool = true
    var isAllDay: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \MemoryTriggerLocation.trigger)
    var location: MemoryTriggerLocation?

    var spacedStage: Int = 0
    var lastReviewDate: Date?
    var ignoreCount: Int = 0

    var memory: Memory?

    init(
        id: UUID = UUID(),
        typeRaw: String = "scheduled",
        fireDate: Date? = nil,
        startDate: Date? = nil,
        recurrenceFrequencyRaw: String? = nil,
        recurrenceInterval: Int = 1,
        recurrenceEndDate: Date? = nil,
        timeZoneIdentifier: String? = nil,
        weekdayMask: Int16 = 0,
        isActive: Bool = true,
        isAllDay: Bool = false,
        location: MemoryTriggerLocation? = nil,
        spacedStage: Int = 0,
        lastReviewDate: Date? = nil,
        ignoreCount: Int = 0,
        memory: Memory? = nil
    ) {
        self.id = id
        self.typeRaw = typeRaw
        self.fireDate = fireDate
        self.startDate = startDate
        self.recurrenceFrequencyRaw = recurrenceFrequencyRaw
        self.recurrenceInterval = recurrenceInterval
        self.recurrenceEndDate = recurrenceEndDate
        self.timeZoneIdentifier = timeZoneIdentifier
        self.weekdayMask = weekdayMask
        self.isActive = isActive
        self.isAllDay = isAllDay
        self.location = location
        self.spacedStage = spacedStage
        self.lastReviewDate = lastReviewDate
        self.ignoreCount = ignoreCount
        self.memory = memory

        self.location?.trigger = self
    }
}
