//
//  ReminderIntervalUnit.swift
//  sparky
//

import Foundation

enum ReminderIntervalUnit: String, CaseIterable, Identifiable, Codable {
    case minutes
    case hours

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .minutes: return "Minutes"
        case .hours: return "Hours"
        }
    }

    func unitLabel(for value: Int) -> String {
        switch self {
        case .minutes:
            return value == 1 ? "minute" : "minutes"
        case .hours:
            return value == 1 ? "hour" : "hours"
        }
    }

    var secondsMultiplier: TimeInterval {
        switch self {
        case .minutes: return 60
        case .hours: return 3600
        }
    }
}
