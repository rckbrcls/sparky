//
//  TerminalCommandParser.swift
//  i-cant-miss
//
//  Created by Codex on 13/10/25.
//

import Foundation

struct TerminalParseResult {
    var baseText: String
    var commands: [TerminalCommandType: String]
    var activatedCommands: [TerminalActivatedCommand]
    var commandForSuggestions: TerminalCommandType?
    var commandFragment: String?
    var argumentFragment: String?
    var reminderDraft: ReminderDraft?
    var notePreview: TerminalPreview.NotePreview?
    var suggestions: [TerminalSuggestion]
}

@MainActor
struct TerminalCommandParser {
    let environment: AppEnvironment

    func parse(input: String) -> TerminalParseResult {
        let tokens = input.split(omittingEmptySubsequences: false, whereSeparator: \.isWhitespace).map(String.init)
        let endsWithSpace = input.last?.isWhitespace ?? false

        var baseWords: [String] = []
        var commands: [TerminalCommandType: String] = [:]
        var activatedCommands: [TerminalActivatedCommand] = []
        var currentCommand: TerminalCommandType?
        var currentArgs: [String] = []
        var lastRecognizedCommand: TerminalCommandType?
        var argumentFragment: String?
        var commandFragment: String?

        for (index, token) in tokens.enumerated() {
            guard !token.isEmpty else { continue }

            if token.hasPrefix("/") {
                // Before switching commands, store any accumulated args.
                if let currentCommand, !currentArgs.isEmpty {
                    let value = currentArgs.joined(separator: " ").trimmingCharacters(in: .whitespaces)
                    commands[currentCommand] = value
                    activatedCommands.append(TerminalActivatedCommand(type: currentCommand, value: value))
                } else if let currentCommand {
                    commands[currentCommand] = ""
                    activatedCommands.append(TerminalActivatedCommand(type: currentCommand, value: ""))
                }

                currentArgs = []

                let rawName = String(token.dropFirst()).lowercased()
                if let commandType = TerminalCommandType(rawValue: rawName) {
                    currentCommand = commandType
                    lastRecognizedCommand = commandType
                    if index == tokens.count - 1 && !endsWithSpace {
                        // User is still typing this command, show argument suggestions.
                        argumentFragment = ""
                    }
                } else {
                    currentCommand = nil
                    commandFragment = rawName
                }
            } else {
                if var command = currentCommand {
                    // Known command argument.
                    currentArgs.append(token)
                    let isLastToken = index == tokens.count - 1
                    if isLastToken && !endsWithSpace {
                        argumentFragment = currentArgs.joined(separator: " ")
                    }
                    // Store a placeholder activated command for display
                    let value = currentArgs.joined(separator: " ").trimmingCharacters(in: .whitespaces)
                    commands[command] = value
                    // remove previous placeholder for command to avoid duplicates before finalizing
                    activatedCommands.removeAll { $0.type == command }
                    activatedCommands.append(TerminalActivatedCommand(type: command, value: value))
                } else {
                    baseWords.append(token)
                }
            }
        }

        // Finalize last command arguments if not already stored.
        if let currentCommand, !commands.keys.contains(currentCommand) {
            let value = currentArgs.joined(separator: " ").trimmingCharacters(in: .whitespaces)
            commands[currentCommand] = value
            activatedCommands.removeAll { $0.type == currentCommand }
            activatedCommands.append(TerminalActivatedCommand(type: currentCommand, value: value))
        }

        let baseText = baseWords.joined(separator: " ").trimmingCharacters(in: .whitespaces)

        let (preview, notePreview) = buildPreview(baseText: baseText, commands: commands)
        let suggestions = buildSuggestions(commandFragment: commandFragment,
                                           argumentFragment: argumentFragment,
                                           lastCommand: lastRecognizedCommand)

        return TerminalParseResult(
            baseText: baseText,
            commands: commands,
            activatedCommands: activatedCommands,
            commandForSuggestions: lastRecognizedCommand,
            commandFragment: commandFragment,
            argumentFragment: argumentFragment,
            reminderDraft: preview,
            notePreview: notePreview,
            suggestions: suggestions
        )
    }

    private func buildPreview(baseText: String, commands: [TerminalCommandType: String]) -> (ReminderDraft?, TerminalPreview.NotePreview?) {
        if commands.keys.contains(.note) {
            let folderID = environment.folderService.folders.first(where: { $0.name.caseInsensitiveCompare(commands[.folder] ?? "") == .orderedSame })?.id
            let tagIDs = commands[.tag]
                .map { value -> [UUID] in
                    value.split(separator: ",").compactMap { tagName in
                        environment.folderService.tags.first { $0.name.caseInsensitiveCompare(tagName.trimmingCharacters(in: .whitespaces)) == .orderedSame }?.id
                    }
                } ?? []
            let notePreview = TerminalPreview.NotePreview(
                content: baseText,
                title: baseText.components(separatedBy: "\n").first,
                folderID: folderID,
                tagIDs: tagIDs,
                isPinned: commands[.priority]?.contains("!!!") == true
            )
            return (nil, notePreview)
        } else {
            var triggers: [ReminderTriggerDraft] = []
            if let dateArgument = commands[.date], let date = parseDate(from: dateArgument) {
                triggers.append(
                    ReminderTriggerDraft(type: .time,
                                         fireDate: date,
                                         startDate: Date(),
                                         timeZoneIdentifier: TimeZone.current.identifier)
                )
            }
            if let person = commands[.person], !person.isEmpty {
                triggers.append(
                    ReminderTriggerDraft(type: .person,
                                         person: ReminderTriggerModel.TriggerPerson(name: person, contactIdentifier: nil))
                )
            }
            if let location = commands[.location], !location.isEmpty {
                let locationName = location
                triggers.append(
                    ReminderTriggerDraft(type: .location,
                                         location: ReminderTriggerModel.TriggerLocation(latitude: 0,
                                                                                        longitude: 0,
                                                                                        radius: 200,
                                                                                        name: locationName,
                                                                                        event: .onEntry))
                )
            }

            let priority = parsePriority(commands[.priority])
            let draft = ReminderDraft(
                title: baseText.isEmpty ? "Untitled reminder" : baseText,
                notes: commands[.note],
                status: .active,
                priority: priority,
                triggers: triggers.isEmpty ? [] : triggers
            )
            return (draft, nil)
        }
    }

    private func buildSuggestions(commandFragment: String?,
                                  argumentFragment: String?,
                                  lastCommand: TerminalCommandType?) -> [TerminalSuggestion] {
        if let fragment = commandFragment, !fragment.isEmpty {
            return TerminalCommandType.allCases
                .filter { $0.rawValue.hasPrefix(fragment) }
                .map { type in
                    TerminalSuggestion(title: type.commandString,
                                       subtitle: type.placeholder,
                                       commandType: type,
                                       replacement: type.commandString + " ")
                }
        }

        guard let command = lastCommand else { return [] }

        switch command {
        case .folder:
            return folderSuggestions(matching: argumentFragment)
        case .tag:
            return tagSuggestions(matching: argumentFragment)
        case .priority:
            return prioritySuggestions(matching: argumentFragment)
        case .person:
            return personSuggestions(matching: argumentFragment)
        case .location:
            return locationSuggestions(matching: argumentFragment)
        case .date, .note:
            return []
        }
    }

    private func folderSuggestions(matching fragment: String?) -> [TerminalSuggestion] {
        let query = fragment?.lowercased() ?? ""
        return environment.folderService.folders
            .filter { query.isEmpty || $0.name.lowercased().contains(query) }
            .map { folder in
                TerminalSuggestion(title: folder.name,
                                   subtitle: "Folder",
                                   commandType: .folder,
                                   replacement: folder.name + " ")
            }
    }

    private func tagSuggestions(matching fragment: String?) -> [TerminalSuggestion] {
        let query = fragment?.lowercased() ?? ""
        return environment.folderService.tags
            .filter { query.isEmpty || $0.name.lowercased().contains(query) }
            .map { tag in
                TerminalSuggestion(title: tag.name,
                                   subtitle: "Tag",
                                   commandType: .tag,
                                   replacement: tag.name + " ")
            }
    }

    private func prioritySuggestions(matching fragment: String?) -> [TerminalSuggestion] {
        let options: [(String, ReminderPriority)] = [
            ("High !!!", .high),
            ("Medium !!", .medium),
            ("Low !", .low)
        ]
        let query = fragment?.lowercased() ?? ""
        return options
            .filter { query.isEmpty || $0.0.lowercased().contains(query) }
            .map { option in
                TerminalSuggestion(title: option.0,
                                   subtitle: "Set priority",
                                   commandType: .priority,
                                   replacement: option.1.replacementString + " ")
            }
    }

    private func personSuggestions(matching fragment: String?) -> [TerminalSuggestion] {
        let query = fragment?.lowercased() ?? ""
        let names = environment.reminderService.reminders
            .flatMap { $0.triggers.compactMap(\.person?.name) }
            .uniqued()
            .filter { query.isEmpty || $0.lowercased().contains(query) }
        return names.map { name in
            TerminalSuggestion(title: name,
                               subtitle: "Recent person",
                               commandType: .person,
                               replacement: name + " ")
        }
    }

    private func locationSuggestions(matching fragment: String?) -> [TerminalSuggestion] {
        let query = fragment?.lowercased() ?? ""
        let names = environment.reminderService.reminders
            .flatMap { $0.triggers.compactMap(\.location?.name) }
            .uniqued()
            .filter { query.isEmpty || $0.lowercased().contains(query) }
        return names.map { name in
            TerminalSuggestion(title: name,
                               subtitle: "Recent location",
                               commandType: .location,
                               replacement: name + " ")
        }
    }

    private func parseDate(from string: String) -> Date? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        let range = NSRange(location: 0, length: string.utf16.count)
        guard let match = detector?.firstMatch(in: string, options: [], range: range),
              let date = match.date else {
            return nil
        }
        return date
    }

    private func parsePriority(_ string: String?) -> ReminderPriority {
        guard let string = string?.lowercased() else { return .medium }
        if string.contains("!!!") || string.contains("high") || string == "3" {
            return .high
        }
        if string.contains("!!") || string.contains("medium") || string == "2" {
            return .medium
        }
        if string.contains("!") || string.contains("low") || string == "1" {
            return .low
        }
        return .medium
    }
}

private extension ReminderPriority {
    var replacementString: String {
        switch self {
        case .low: return "!"
        case .medium: return "!!"
        case .high: return "!!!"
        }
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
