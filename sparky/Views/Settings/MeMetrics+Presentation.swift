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

extension MeMetrics {
    static let unavailableDisplayText = "—"
    static let unavailableAccessibilityText = "Not available"

    static func percentageText(for rate: CompletionRate) -> String {
        guard rate.isAvailable else { return unavailableDisplayText }
        return "\(Int((rate.value * 100).rounded()))%"
    }

    static func activityPeriodText(for period: ActivityPeriod?) -> String {
        period?.title ?? unavailableDisplayText
    }

    static func weekdayText(for weekday: Int?) -> String {
        guard let weekday else { return unavailableDisplayText }
        return englishWeekdayName(for: weekday)
    }

    static func accessibilityText(for displayText: String) -> String {
        displayText == unavailableDisplayText
            ? unavailableAccessibilityText
            : displayText
    }

    static func englishWeekdayName(for weekday: Int) -> String {
        guard (1...7).contains(weekday) else {
            return unavailableDisplayText
        }
        return englishWeekdayFormatter.weekdaySymbols[weekday - 1]
    }

    private static let englishWeekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        return formatter
    }()
}
