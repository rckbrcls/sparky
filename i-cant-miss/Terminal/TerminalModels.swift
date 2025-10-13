//
//  TerminalModels.swift
//  i-cant-miss
//
//  Created by Codex on 13/10/25.
//

import Foundation

enum TerminalCommandType: String, CaseIterable, Identifiable {
    case date
    case note
    case folder
    case tag
    case priority
    case person
    case location

    var id: String { rawValue }

    var commandString: String { "/\(rawValue)" }

    var placeholder: String {
        switch self {
        case .date:
            return "/date 14:30 tomorrow"
        case .note:
            return "/note"
        case .folder:
            return "/folder Personal"
        case .tag:
            return "/tag urgent"
        case .priority:
            return "/priority high"
        case .person:
            return "/person Maya"
        case .location:
            return "/location Office"
        }
    }

    var label: String {
        switch self {
        case .date: return "Date"
        case .note: return "Quick Note"
        case .folder: return "Folder"
        case .tag: return "Tag"
        case .priority: return "Priority"
        case .person: return "Person"
        case .location: return "Location"
        }
    }
}

struct TerminalActivatedCommand: Identifiable, Hashable {
    let id = UUID()
    let type: TerminalCommandType
    let value: String
}

struct TerminalSuggestion: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String?
    let commandType: TerminalCommandType
    let replacement: String
}

enum TerminalPreview {
    case reminder(ReminderDraft)
    case note(NotePreview)

    struct NotePreview {
        var content: String
        var title: String?
        var folderID: UUID?
        var tagIDs: [UUID]
        var isPinned: Bool
    }
}
