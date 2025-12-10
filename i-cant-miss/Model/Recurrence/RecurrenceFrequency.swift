//
//  RecurrenceFrequency.swift
//  i-cant-miss
//

import Foundation

enum RecurrenceFrequency: String, CaseIterable, Identifiable, Codable {
    case daily
    case weekly
    case monthly
    case yearly

    var id: String { rawValue }
}

extension RecurrenceFrequency {
    nonisolated var calendarComponent: Calendar.Component {
        switch self {
        case .daily: return .day
        case .weekly: return .weekOfYear
        case .monthly: return .month
        case .yearly: return .year
        }
    }
}
