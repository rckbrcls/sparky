//
//  CalendarTimePeriod.swift
//  sparky
//
//  Created by Codex on 09/03/24.
//

import SwiftUI

enum CalendarTimePeriod: CaseIterable, Hashable {
    case allDay     // All day memories (no specific time)
    case earlyMorning // 00:00 - 06:00
    case morning    // 06:00 - 12:00
    case afternoon  // 12:00 - 18:00
    case evening    // 18:00 - 22:00
    case night      // 22:00 - 24:00

    var title: String {
        switch self {
        case .allDay: return "All Day"
        case .earlyMorning: return "Early Morning"
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        case .night: return "Night"
        }
    }

    var timeRangeDescription: String {
        switch self {
        case .allDay: return "All Day: No specific time"
        case .earlyMorning: return "Early Morning: 00:00–05:59"
        case .morning: return "Morning: 06:00–11:59"
        case .afternoon: return "Afternoon: 12:00–17:59"
        case .evening: return "Evening: 18:00–21:59"
        case .night: return "Night: 22:00–23:59"
        }
    }

    var iconName: String {
        switch self {
        case .allDay: return "calendar"
        case .earlyMorning: return "moon.fill"
        case .morning: return "sunrise.fill"
        case .afternoon: return "sun.max.fill"
        case .evening: return "sunset.fill"
        case .night: return "moon.stars.fill"
        }
    }

    var color: Color {
        switch self {
        case .allDay: return .accentColor
        case .earlyMorning: return Color.Theme.calendarNight
        case .morning: return Color.Theme.calendarMorning
        case .afternoon: return Color.Theme.calendarAfternoon
        case .evening: return Color.Theme.calendarEvening
        case .night: return Color.Theme.calendarNight
        }
    }

    var emptyStateTitle: String {
        switch self {
        case .allDay: return "Add something for this day"
        case .earlyMorning: return "Plan an early morning memory"
        case .morning: return "Start the morning with a memory"
        case .afternoon: return "Plan an afternoon memory"
        case .evening: return "Add something for this evening"
        case .night: return "Save something for tonight"
        }
    }

    var suggestedHour: Int? {
        switch self {
        case .allDay: return nil
        case .earlyMorning: return 1
        case .morning: return 9
        case .afternoon: return 14
        case .evening: return 19
        case .night: return 22
        }
    }

    func contains(hour: Int) -> Bool {
        switch self {
        case .allDay:
            return false // All day memories don't have a specific hour
        case .earlyMorning:
            return hour >= 0 && hour < 6
        case .morning:
            return hour >= 6 && hour < 12
        case .afternoon:
            return hour >= 12 && hour < 18
        case .evening:
            return hour >= 18 && hour < 22
        case .night:
            return hour >= 22 && hour < 24
        }
    }

    static func period(containingHour hour: Int) -> CalendarTimePeriod {
        allCases.first { period in
            period != .allDay && period.contains(hour: hour)
        } ?? .night
    }
}
