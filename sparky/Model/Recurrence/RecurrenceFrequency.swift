//
//  RecurrenceFrequency.swift
//  sparky
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
    static var userVisible: [RecurrenceFrequency] {
        [.hourly, .daily, .weekly, .monthly, .yearly]
    }

    nonisolated var displayName: String {
        switch self {
        case .minutely: return "Minutely"
        case .hourly: return "Hourly"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        }
    }

    nonisolated var unitLabel: String {
        switch self {
        case .minutely: return "minutes"
        case .hourly: return "hours"
        case .daily: return "days"
        case .weekly: return "weeks"
        case .monthly: return "months"
        case .yearly: return "years"
        }
    }

    nonisolated var singularUnitLabel: String {
        switch self {
        case .minutely: return "minute"
        case .hourly: return "hour"
        case .daily: return "day"
        case .weekly: return "week"
        case .monthly: return "month"
        case .yearly: return "year"
        }
    }

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
