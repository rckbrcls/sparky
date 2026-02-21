//
//  RecurrenceEndType.swift
//  sparky
//

import Foundation

enum RecurrenceEndType: String, CaseIterable, Identifiable, Codable {
    case never
    case untilDate
    case afterCount

    var id: String { rawValue }

    var label: String {
        switch self {
        case .never: return "Forever"
        case .untilDate: return "Until Date"
        case .afterCount: return "After"
        }
    }
}
