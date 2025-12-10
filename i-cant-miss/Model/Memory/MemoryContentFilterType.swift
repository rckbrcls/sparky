//
//  MemoryContentFilterType.swift
//  i-cant-miss
//

import Foundation

enum MemoryContentFilterType: String, CaseIterable, Identifiable {
    case richText
    case checklist
    case photos
    case links
    case audio
    case files

    var id: String { rawValue }

    var label: String {
        switch self {
        case .richText: return "Notes"
        case .checklist: return "Checklists"
        case .photos: return "Photos"
        case .links: return "Links"
        case .audio: return "Audio"
        case .files: return "Files"
        }
    }

    var systemImage: String {
        switch self {
        case .richText: return "text.justify.leading"
        case .checklist: return "checklist"
        case .photos: return "photo.on.rectangle.angled"
        case .links: return "link"
        case .audio: return "waveform"
        case .files: return "doc"
        }
    }
}
