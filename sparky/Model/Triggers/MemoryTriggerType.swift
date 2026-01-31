//
//  MemoryTriggerType.swift
//  sparky
//

import Foundation

enum MemoryTriggerType: String, CaseIterable, Identifiable, Codable {
    case scheduled
    case location

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .scheduled: return "clock.badge"
        case .location: return "mappin.and.ellipse"
        }
    }

    var label: String {
        switch self {
        case .scheduled: return "Date & Time"
        case .location: return "Location"
        }
    }
}
