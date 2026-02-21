//
//  MemoryType.swift
//  sparky
//

import Foundation

enum MemoryType: String, CaseIterable, Identifiable {
    case text
    case checklist
    case photos
    case triggered

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .text: return "Text"
        case .checklist: return "Checklist"
        case .photos: return "Photos"
        case .triggered: return "With Triggers"
        }
    }

    var label: String {
        switch self {
        case .text: return "Notes"
        case .checklist: return "Checklists"
        case .photos: return "Photos"
        case .triggered: return "Triggers"
        }
    }

    var systemImage: String {
        switch self {
        case .text: return "note.text"
        case .checklist: return "checklist"
        case .photos: return "photo.on.rectangle"
        case .triggered: return "alarm"
        }
    }
}
