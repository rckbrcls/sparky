//
//  TerminalInputBar.swift
//  i-cant-miss
//
//  Created by Codex on 13/10/25.
//

import SwiftUI

struct TerminalInputBar: View {
    @ObservedObject var viewModel: TerminalCommandViewModel
    @Binding var isFocused: Bool
    @State private var textViewHeight: CGFloat = 32

    private let minHeight: CGFloat = 32
    private let maxHeight: CGFloat = 100

    var body: some View {
        VStack(spacing: 8) {
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

            HStack(alignment: .bottom, spacing: 8) {
                Image(systemName: "terminal")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemBackground))

                    if viewModel.input.isEmpty {
                        Text("Type reminder with / commands")
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                    }

                    GrowingTextView(
                        text: $viewModel.input,
                        calculatedHeight: $textViewHeight,
                        isFocused: $isFocused,
                        minHeight: minHeight,
                        maxHeight: maxHeight
                    )
                    .frame(height: textViewHeight)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.secondary.opacity(0.2))
                )

                Button(action: submit) {
                    if viewModel.isProcessing {
                        ProgressView()
                    } else {
                        Image(systemName: "paperplane.circle.fill")
                            .font(.body)
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
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 1)
        )
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

#if canImport(UIKit)
extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
#endif

private extension TerminalInputBar {
    func submit() {
        guard !viewModel.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isFocused = false
        viewModel.handleSubmit()
    }
}

struct GrowingTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var calculatedHeight: CGFloat
    @Binding var isFocused: Bool
    let minHeight: CGFloat
    let maxHeight: CGFloat

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
        textView.textContainer.lineFragmentPadding = 0
        textView.isScrollEnabled = false
        textView.keyboardDismissMode = .interactive
        textView.autocapitalizationType = .sentences
        textView.autocorrectionType = .yes
        textView.smartDashesType = .no
        textView.smartQuotesType = .no
        textView.setContentCompressionResistancePriority(.required, for: .vertical)
        context.coordinator.updateHeight(for: textView)
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        context.coordinator.parent = self
        context.coordinator.updateHeight(for: uiView)

        let shouldScroll = calculatedHeight >= maxHeight - 0.5
        if uiView.isScrollEnabled != shouldScroll {
            uiView.isScrollEnabled = shouldScroll
        }

        if isFocused && !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
        } else if !isFocused && uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: GrowingTextView

        init(parent: GrowingTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            updateHeight(for: textView)
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.isFocused = true
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            parent.isFocused = false
        }

        func updateHeight(for textView: UITextView) {
            // Compute one-line height (font line height + top/bottom insets)
            let lineHeight = (textView.font ?? UIFont.preferredFont(forTextStyle: .body)).lineHeight
            let oneLine = lineHeight + textView.textContainerInset.top + textView.textContainerInset.bottom
            let minCap = max(parent.minHeight, oneLine)

            // If width is not laid out yet, default to a single line height
            guard textView.bounds.width > 0 else {
                if abs(self.parent.calculatedHeight - minCap) > 0.5 {
                    DispatchQueue.main.async { [weak self] in
                        self?.parent.calculatedHeight = minCap
                    }
                }
                return
            }

            let fitting = textView.sizeThatFits(CGSize(width: textView.bounds.width, height: .greatestFiniteMagnitude))
            let target = min(parent.maxHeight, max(minCap, fitting.height))
            if abs(self.parent.calculatedHeight - target) > 0.5 {
                DispatchQueue.main.async { [weak self] in
                    self?.parent.calculatedHeight = target
                }
            }
        }
    }
}

#if canImport(UIKit)
import UIKit
#endif

#Preview {
    let environment = AppEnvironment(persistence: PersistenceController.preview)
    environment.bootstrap()
    let viewModel = TerminalCommandViewModel(environment: environment)
    return TerminalInputBar(viewModel: viewModel, isFocused: .constant(false))
}
