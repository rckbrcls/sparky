//
//  MemoryTimelineFilter.swift
//  i-cant-miss
//

import Foundation

enum MemoryTimelineFilter: String, CaseIterable, Identifiable {
    case all
    case today
    case nextSevenDays
    case later
    case recurring
    case overdue
    case thisWeek
    case byPriority
    case byTriggerType
    case timeTriggers
    case locationTriggers
    case personTriggers
    case noTriggers

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .all: return "All"
        case .today: return "Today"
        case .nextSevenDays: return "Next 7 Days"
        case .later: return "Later"
        case .recurring: return "Recurring"
        case .overdue: return "Overdue"
        case .thisWeek: return "This Week"
        case .byPriority: return "Priority"
        case .byTriggerType: return "Type"
        case .timeTriggers: return "Scheduled"
        case .locationTriggers: return "Location"
        case .personTriggers: return "People"
        case .noTriggers: return "No Triggers"
        }
    }

    var storageKey: String {
        switch self {
        case .all: return "all"
        case .today: return "today"
        case .nextSevenDays: return "nextSevenDays"
        case .later: return "later"
        case .recurring: return "recurring"
        case .overdue: return "overdue"
        case .thisWeek: return "thisWeek"
        case .byPriority: return "byPriority"
        case .byTriggerType: return "byTriggerType"
        case .timeTriggers: return "timeTriggers"
        case .locationTriggers: return "locationTriggers"
        case .personTriggers: return "personTriggers"
        case .noTriggers: return "noTriggers"
        }
    }

    init?(storageKey: String) {
        if let match = Self.allCases.first(where: { $0.storageKey == storageKey }) {
            self = match
        } else {
            return nil
        }
    }
}
