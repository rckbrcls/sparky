//
//  TerminalInputBar.swift
//  i-cant-miss
//
//  Created by Codex on 13/10/25.
//

import SwiftUI

struct TerminalInputBar: View {
    @ObservedObject var viewModel: TerminalCommandViewModel

    var body: some View {
        VStack(spacing: 10) {
            if let preview = viewModel.preview {
                TerminalPreviewView(preview: preview)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            if !viewModel.activatedCommands.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.activatedCommands) { command in
                            HStack(spacing: 6) {
                                Text(command.type.commandString)
                                if !command.value.isEmpty {
                                    Text(command.value)
                                        .foregroundStyle(.secondary)
                                }
                                Button {
                                    viewModel.removeCommand(command)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial, in: Capsule())
                        }
                    }
                }
                .transition(.move(edge: .bottom))
            }

            HStack(alignment: .bottom, spacing: 12) {
                Image(systemName: "terminal")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                TextField("Type reminder with / commands", text: $viewModel.input, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...3)
                    .submitLabel(.go)
                    .onSubmit {
                        viewModel.handleSubmit()
                    }
                Button(action: viewModel.handleSubmit) {
                    if viewModel.isProcessing {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                    }
                }
                .buttonStyle(.borderless)
                .disabled(viewModel.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if !viewModel.suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.suggestions) { suggestion in
                            Button {
                                viewModel.applySuggestion(suggestion)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(suggestion.title)
                                        .font(.caption.weight(.medium))
                                    if let subtitle = suggestion.subtitle {
                                        Text(subtitle)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.thinMaterial, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .transition(.move(edge: .bottom))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: -4)
        )
        .padding(.horizontal)
    }
}

private struct TerminalPreviewView: View {
    let preview: TerminalPreview

    var body: some View {
        switch preview {
        case .note(let note):
            VStack(alignment: .leading, spacing: 6) {
                Label("Quick Note", systemImage: "square.and.pencil")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(note.title ?? note.content.prefix(40) + "…")
                    .font(.headline)
                Text(note.content)
                    .font(.subheadline)
                    .lineLimit(2)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.blue.opacity(0.1)))
        case .reminder(let draft):
            VStack(alignment: .leading, spacing: 6) {
                Label("Reminder Preview", systemImage: "bell")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(draft.title)
                    .font(.headline)
                if let notes = draft.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if !draft.triggers.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(draft.triggers, id: \.id) { trigger in
                            Text(trigger.type.label)
                                .font(.caption)
                                .padding(.vertical, 3)
                                .padding(.horizontal, 6)
                                .background(.thinMaterial, in: Capsule())
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.green.opacity(0.1)))
        }
    }
}

#Preview {
    let environment = AppEnvironment(persistence: PersistenceController.preview)
    environment.bootstrap()
    let viewModel = TerminalCommandViewModel(environment: environment)
    return TerminalInputBar(viewModel: viewModel)
}
