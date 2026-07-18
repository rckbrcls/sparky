//
//  NestedReminderPolicy.swift
//  sparky
//
//  Follow-up reminder policy nested under a primary trigger (schedule/location).
//

import Foundation

struct NestedReminderPolicy: Hashable, Codable, Sendable {
    var isActive: Bool
    var intervalValue: Int
    var intervalUnit: ReminderIntervalUnit
    var repeatCount: Int?
    var startedAt: Date?

    init(
        isActive: Bool = false,
        intervalValue: Int = 1,
        intervalUnit: ReminderIntervalUnit = .hours,
        repeatCount: Int? = nil,
        startedAt: Date? = nil
    ) {
        self.isActive = isActive
        self.intervalValue = max(1, intervalValue)
        self.intervalUnit = intervalUnit
        self.repeatCount = repeatCount
        self.startedAt = startedAt
    }

    var isInfinite: Bool {
        repeatCount == nil
    }

    var secondsInterval: TimeInterval {
        TimeInterval(max(1, intervalValue)) * intervalUnit.secondsMultiplier
    }

    static func createDefault(isActive: Bool = true) -> NestedReminderPolicy {
        NestedReminderPolicy(
            isActive: isActive,
            intervalValue: 1,
            intervalUnit: .hours,
            repeatCount: nil,
            startedAt: nil
        )
    }

    func clearingStart() -> NestedReminderPolicy {
        var copy = self
        copy.startedAt = nil
        return copy
    }
}
