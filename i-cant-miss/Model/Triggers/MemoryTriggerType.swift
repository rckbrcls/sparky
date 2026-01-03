//
//  MemoryTriggerType.swift
//  i-cant-miss
//

import Foundation

enum MemoryTriggerType: String, CaseIterable, Identifiable, Codable {
    case scheduled
    case location
    case person
    case sequential

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .scheduled: return "clock.badge"
        case .location: return "mappin.and.ellipse"
        case .person: return "person.crop.circle"
        case .sequential: return "arrowshape.turn.up.right.circle"
        }
    }

    var label: String {
        switch self {
        case .scheduled: return "Date & Time"
        case .location: return "Location"
        case .person: return "Person"
        case .sequential: return "Sequential"
        }
    }
}
