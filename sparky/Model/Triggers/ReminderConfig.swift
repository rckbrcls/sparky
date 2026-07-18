//
//  ReminderConfig.swift
//  sparky
//
//  LEGACY: Kept in SwiftData schema to avoid migration crashes.
//  Active reminder policy now lives nested on ScheduleConfig / LocationConfig.
//  Do not write new memory-level reminder configs.
//

import Foundation
import SwiftData

@Model
final class ReminderConfig: Identifiable {
    @Attribute(.unique) var id: UUID = UUID()
    var intervalValue: Int = 1
    var intervalUnitRaw: String = ReminderIntervalUnit.hours.rawValue
    var repeatCount: Int?
    var isActive: Bool = true
    var startedAt: Date?
    var startedByRaw: String?

    var memory: Memory?

    init(
        id: UUID = UUID(),
        intervalValue: Int = 1,
        intervalUnit: ReminderIntervalUnit = .hours,
        repeatCount: Int? = nil,
        isActive: Bool = true,
        startedAt: Date? = nil,
        startedBy: ReminderStartSource? = nil,
        memory: Memory? = nil
    ) {
        self.id = id
        self.intervalValue = max(1, intervalValue)
        self.intervalUnitRaw = intervalUnit.rawValue
        self.repeatCount = repeatCount
        self.isActive = isActive
        self.startedAt = startedAt
        self.startedByRaw = startedBy?.rawValue
        self.memory = memory
    }
}

extension ReminderConfig {
    var intervalUnit: ReminderIntervalUnit {
        get { ReminderIntervalUnit(rawValue: intervalUnitRaw) ?? .hours }
        set { intervalUnitRaw = newValue.rawValue }
    }

    var startedBy: ReminderStartSource? {
        get {
            guard let raw = startedByRaw else { return nil }
            return ReminderStartSource(rawValue: raw)
        }
        set {
            startedByRaw = newValue?.rawValue
        }
    }

    var isInfinite: Bool {
        repeatCount == nil
    }

    var secondsInterval: TimeInterval {
        TimeInterval(max(1, intervalValue)) * intervalUnit.secondsMultiplier
    }

    func clearStart() {
        startedAt = nil
        startedByRaw = nil
    }
}

extension ReminderConfig {
    static func createDefault() -> ReminderConfig {
        ReminderConfig(
            intervalValue: 1,
            intervalUnit: .hours,
            repeatCount: nil,
            isActive: true
        )
    }
}
