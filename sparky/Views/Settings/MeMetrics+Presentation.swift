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

extension MeMetrics.Insight {
    var title: String {
        switch self {
        case .improvedWeek:
            return "Your pace is building"
        case .activePeriod:
            return "Your rhythm is taking shape"
        case .bestWeekday:
            return "A strong day is emerging"
        case .buildingPattern:
            return "Patterns are forming"
        case .restart:
            return "Ready when you are"
        }
    }

    var message: String {
        switch self {
        case let .improvedWeek(delta):
            let memoryLabel = delta == 1 ? "memory" : "memories"
            return "You completed \(delta) more \(memoryLabel) than in the previous seven days."
        case let .activePeriod(period):
            return "\(period.title) has been your most active period over the last 30 days."
        case let .bestWeekday(weekday):
            return "\(MeMetrics.englishWeekdayName(for: weekday)) has been your strongest completion day."
        case .buildingPattern:
            return "As you complete memories, Sparky will reveal more of your rhythm."
        case .restart:
            return "One completed memory will bring your weekly spark back to life."
        }
    }
}

extension MeMetrics {
    static func englishWeekdayName(for weekday: Int) -> String {
        guard (1...7).contains(weekday) else { return "This day" }
        return englishWeekdayFormatter.weekdaySymbols[weekday - 1]
    }

    private static let englishWeekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        return formatter
    }()
}
