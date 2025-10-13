//
//  TerminalCommandViewModel.swift
//  i-cant-miss
//
//  Created by Codex on 13/10/25.
//

import Foundation
import Combine

@MainActor
final class TerminalCommandViewModel: ObservableObject {
    @Published var input: String = "" {
        didSet { parseInput() }
    }
    @Published private(set) var activatedCommands: [TerminalActivatedCommand] = []
    @Published private(set) var suggestions: [TerminalSuggestion] = []
    @Published private(set) var preview: TerminalPreview?
    @Published private(set) var isProcessing = false
    @Published private(set) var baseText: String = ""

    private let environment: AppEnvironment
    private var parser: TerminalCommandParser
    private var lastResult: TerminalParseResult?

    init(environment: AppEnvironment) {
        self.environment = environment
        self.parser = TerminalCommandParser(environment: environment)
    }

    func handleSubmit() {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        Task {
            isProcessing = true
            defer { isProcessing = false }

            switch preview {
            case .note(let notePreview):
                guard !notePreview.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                _ = try? await environment.noteService.createNote(title: notePreview.title,
                                                                   content: notePreview.content,
                                                                   folderID: notePreview.folderID,
                                                                   tagIDs: notePreview.tagIDs,
                                                                   isPinned: notePreview.isPinned)
                await environment.noteService.refresh(force: true)
            case .reminder(let draft):
                guard !draft.triggers.isEmpty else { return }
                _ = try? await environment.reminderService.createReminder(from: draft)
                await environment.reminderService.refresh(force: true)
            case .none:
                return
            }

            clear()
        }
    }

    func applySuggestion(_ suggestion: TerminalSuggestion) {
        guard let result = lastResult else { return }
        if let fragment = result.commandFragment, !fragment.isEmpty {
            replaceLastOccurrence(of: "/\(fragment)", with: suggestion.replacement)
        } else if let argument = result.argumentFragment, !argument.isEmpty {
            replaceLastOccurrence(of: argument, with: suggestion.replacement)
        } else {
            input += (input.hasSuffix(" ") || input.isEmpty ? "" : " ") + suggestion.replacement
        }
    }

    func removeCommand(_ command: TerminalActivatedCommand) {
        guard var result = lastResult else { return }
        result.commands.removeValue(forKey: command.type)
        let remaining = result.activatedCommands.filter { $0.type != command.type }
        let rebuilt = composeInput(baseText: result.baseText, commands: remaining)
        lastResult = nil
        input = rebuilt
    }

    func clear() {
        input = ""
        activatedCommands = []
        suggestions = []
        preview = nil
        baseText = ""
    }

    private func parseInput() {
        let result = parser.parse(input: input)
        lastResult = result
        baseText = result.baseText
        activatedCommands = result.activatedCommands
        suggestions = result.suggestions
        if let notePreview = result.notePreview {
            preview = .note(notePreview)
        } else if let reminderDraft = result.reminderDraft, !reminderDraft.triggers.isEmpty {
            preview = .reminder(reminderDraft)
        } else {
            preview = nil
        }
    }

    private func composeInput(baseText: String, commands: [TerminalActivatedCommand]) -> String {
        var components: [String] = []
        if !baseText.isEmpty {
            components.append(baseText)
        }
        for command in commands {
            let value = command.value.trimmingCharacters(in: .whitespaces)
            if value.isEmpty {
                components.append(command.type.commandString)
            } else {
                components.append("\(command.type.commandString) \(value)")
            }
        }
        return components.joined(separator: " ")
    }

    private func replaceLastOccurrence(of target: String, with replacement: String) {
        guard let range = input.range(of: target, options: .backwards) else {
            input += replacement
            return
        }
        input.replaceSubrange(range, with: replacement)
    }
}
