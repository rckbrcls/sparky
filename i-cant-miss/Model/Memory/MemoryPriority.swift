//
//  MemoryPriority.swift
//  i-cant-miss
//

import Foundation

enum MemoryPriority: Int16, CaseIterable, Identifiable, Codable {
    case noPriority = -1
    case low = 0
    case medium = 1
    case high = 2

    var id: Int16 { rawValue }

    var iconName: String {
        switch self {
        case .noPriority: return "minus.circle"
        case .low: return "exclamationmark"
        case .medium: return "exclamationmark.2"
        case .high: return "exclamationmark.3"
        }
    }

    var displayName: String {
        switch self {
        case .noPriority: return "No Priority"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
}
