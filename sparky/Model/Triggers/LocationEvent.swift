//
//  LocationEvent.swift
//  sparky
//

import Foundation

enum LocationEvent: String, CaseIterable, Identifiable, Codable {
    case onEntry
    case onExit

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .onEntry: return "Arriving"
        case .onExit: return "Leaving"
        }
    }
}
