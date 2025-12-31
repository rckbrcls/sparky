//
//  RecurrenceFrequency.swift
//  i-cant-miss
//

import Foundation

enum RecurrenceFrequency: String, CaseIterable, Identifiable, Codable {
    case minutely
    case hourly
    case daily
    case weekly
    case monthly
    case yearly

    var id: String { rawValue }
}

extension RecurrenceFrequency {
    nonisolated var calendarComponent: Calendar.Component {
        switch self {
        case .minutely: return .minute
        case .hourly: return .hour
        case .daily: return .day
        case .weekly: return .weekOfYear
        case .monthly: return .month
        case .yearly: return .year
        }
    }
}
