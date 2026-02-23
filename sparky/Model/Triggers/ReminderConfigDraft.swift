//
//  ReminderConfigDraft.swift
//  sparky
//
//  In-memory draft for editing reminder policy.
//

import Foundation

struct ReminderConfigDraft: Identifiable, Hashable {
    let id: UUID
    var intervalValue: Int
    var intervalUnit: ReminderIntervalUnit
    var repeatCount: Int?
    var isActive: Bool
    var startedAt: Date?
    var startedBy: ReminderStartSource?

    init(
        id: UUID = UUID(),
        intervalValue: Int = 1,
        intervalUnit: ReminderIntervalUnit = .hours,
        repeatCount: Int? = nil,
        isActive: Bool = true,
        startedAt: Date? = nil,
        startedBy: ReminderStartSource? = nil
    ) {
        self.id = id
        self.intervalValue = max(1, intervalValue)
        self.intervalUnit = intervalUnit
        self.repeatCount = repeatCount
        self.isActive = isActive
        self.startedAt = startedAt
        self.startedBy = startedBy
    }

    static func == (lhs: ReminderConfigDraft, rhs: ReminderConfigDraft) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension ReminderConfigDraft {
    func toModel(memory: Memory? = nil) -> ReminderConfig {
        ReminderConfig(
            id: id,
            intervalValue: intervalValue,
            intervalUnit: intervalUnit,
            repeatCount: repeatCount,
            isActive: isActive,
            startedAt: startedAt,
            startedBy: startedBy,
            memory: memory
        )
    }

    static func from(_ model: ReminderConfig) -> ReminderConfigDraft {
        ReminderConfigDraft(
            id: model.id,
            intervalValue: model.intervalValue,
            intervalUnit: model.intervalUnit,
            repeatCount: model.repeatCount,
            isActive: model.isActive,
            startedAt: model.startedAt,
            startedBy: model.startedBy
        )
    }

    static func createDefault() -> ReminderConfigDraft {
        ReminderConfigDraft(
            intervalValue: 1,
            intervalUnit: .hours,
            repeatCount: nil,
            isActive: true
        )
    }
}
