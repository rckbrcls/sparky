import Foundation

enum DesktopCalendarMode: String, CaseIterable, Identifiable, Hashable, Sendable {
    case day
    case month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day:
            return "Day"
        case .month:
            return "Month"
        }
    }
}
