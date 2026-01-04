//
//  MemoryTriggerType.swift
//  i-cant-miss
//

import Foundation

enum MemoryTriggerType: String, CaseIterable, Identifiable, Codable {
    case scheduled
    case location
    case sequential

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .scheduled: return "clock.badge"
        case .location: return "mappin.and.ellipse"
        case .sequential: return "arrowshape.turn.up.right.circle"
        }
    }

    var label: String {
        switch self {
        case .scheduled: return "Date & Time"
        case .location: return "Location"
        case .sequential: return "Sequential"
        }
    }
}
