//
//  AppPresentationRoutes.swift
//  sparky
//
//  Shared presentation routes for iPhone ContentView and Mac Desktop shell.
//

import Foundation

struct MemoryEditorRoute: Identifiable {
    enum Mode {
        case create(mind: Mind?, template: MemoryEditorTemplate)
        case preview(memory: Memory)
        case edit(memory: Memory)
    }

    let id = UUID()
    let mode: Mode
    var initialTitle: String = ""
    var startEditing: Bool = false
}

struct MindComposerRequest: Identifiable {
    let id = UUID()
    let mindToEdit: Mind?
}

struct QuickMemoryRequest: Identifiable {
    let id = UUID()
    let mind: Mind?
}

struct FocusSessionRoute: Identifiable {
    let id = UUID()
}
