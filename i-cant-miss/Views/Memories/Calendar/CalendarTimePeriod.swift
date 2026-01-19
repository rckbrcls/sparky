//
//  CalendarTimePeriod.swift
//  i-cant-miss
//
//  Created by Codex on 09/03/24.
//

import SwiftUI

enum CalendarTimePeriod: CaseIterable {
    case allDay     // All day memories (no specific time)
    case morning    // 06:00 - 12:00
    case afternoon  // 12:00 - 18:00
    case evening    // 18:00 - 22:00
    case night      // 22:00 - 06:00

    var title: String {
        switch self {
        case .allDay: return "All Day"
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        case .night: return "Night"
        }
    }

    var iconName: String {
        switch self {
        case .allDay: return "calendar"
        case .morning: return "sunrise.fill"
        case .afternoon: return "sun.max.fill"
        case .evening: return "sunset.fill"
        case .night: return "moon.stars.fill"
        }
    }

    var color: Color {
        switch self {
        case .allDay: return .cyan
        case .morning: return .orange
        case .afternoon: return .yellow
        case .evening: return .pink
        case .night: return .indigo
        }
    }

    func contains(hour: Int) -> Bool {
        switch self {
        case .allDay:
            return false // All day memories don't have a specific hour
        case .morning:
            return hour >= 6 && hour < 12
        case .afternoon:
            return hour >= 12 && hour < 18
        case .evening:
            return hour >= 18 && hour < 22
        case .night:
            return hour >= 22 || hour < 6
        }
    }
}
