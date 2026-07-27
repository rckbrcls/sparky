import Foundation

enum DesktopCalendarMode: String, CaseIterable, Identifiable, Hashable, Sendable {
    case week
    case month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week:
            return "Week"
        case .month:
            return "Month"
        }
    }
}
