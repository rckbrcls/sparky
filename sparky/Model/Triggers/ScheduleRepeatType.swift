//
//  ScheduleRepeatType.swift
//  sparky
//
//  Repeat type options for schedule configuration.
//

import Foundation
import SwiftUI

/// Repeat type for schedule triggers displayed in UI
enum ScheduleRepeatType: String, CaseIterable, Identifiable {
    case never = "Never"
    case daily = "Daily"
    case weekly = "Weekly"
    case yearly = "Yearly"
    case custom = "Custom"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .never: return "calendar"
        case .daily: return "sun.max"
        case .weekly: return "calendar.badge.clock"
        case .yearly: return "sparkles"
        case .custom: return "slider.horizontal.3"
        }
    }

    var label: String { rawValue }
}

/// Custom repeat type for more granular control
enum CustomRepeatType: String, CaseIterable, Identifiable {
    case weekly = "Weekly"
    case monthly = "Monthly"

    var id: String { rawValue }
}

/// Time of day type for schedule configuration
enum TimeOfDayType: String, CaseIterable, Identifiable {
    case specificTime = "Specific Time"
    case allDay = "All Day"

    var id: String { rawValue }
}
