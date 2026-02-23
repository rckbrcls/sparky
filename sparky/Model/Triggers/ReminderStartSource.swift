//
//  ReminderStartSource.swift
//  sparky
//

import Foundation

enum ReminderStartSource: String, Codable {
    case schedule
    case location

    var displayName: String {
        switch self {
        case .schedule: return "Date & Time"
        case .location: return "Location"
        }
    }
}
