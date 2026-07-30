import SwiftUI

extension MeMetrics.ActivityPeriod {
    var title: String {
        switch self {
        case .morning:
            return "Morning"
        case .afternoon:
            return "Afternoon"
        case .evening:
            return "Evening"
        case .night:
            return "Night"
        }
    }

    var color: Color {
        switch self {
        case .morning:
            return Color.Theme.calendarMorning
        case .afternoon:
            return Color.Theme.calendarAfternoon
        case .evening:
            return Color.Theme.calendarEvening
        case .night:
            return Color.Theme.calendarNight
        }
    }
}
