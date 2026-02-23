//
//  QuickMemorySheet.swift
//  sparky
//
//  Created by Codex on 10/12/24.
//

import SwiftUI
import UIKit

// MARK: - Auto Focus TextField

private struct AutoFocusTextField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let font: UIFont
    let onSubmit: () -> Void

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.placeholder = placeholder
        textField.font = font
        textField.delegate = context.coordinator
        textField.returnKeyType = .done
        textField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        // Focus immediately
        DispatchQueue.main.async {
            textField.becomeFirstResponder()
        }

        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: AutoFocusTextField

        init(_ parent: AutoFocusTextField) {
            self.parent = parent
        }

        func textFieldDidChangeSelection(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            parent.onSubmit()
            return true
        }
    }
}

// MARK: - Quick Memory Sheet

struct QuickMemorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var mindService: MindService

    @AppStorage("quickMemory.lastReminderMinutes") private var lastReminderMinutes: Int = -1

    let environment: AppEnvironment
    let mind: Mind?
    let onExpandToEditor: (Mind?, String) -> Void
    let onQuickCreate: (Mind?, String, Int?) -> Void // Added Int? for reminder minutes

    @State private var title: String = ""
    @State private var selectedMindID: UUID?
    @State private var selectedReminderMinutes: Int? = nil // nil means no reminder selected

    init(environment: AppEnvironment, mind: Mind?, onExpandToEditor: @escaping (Mind?, String) -> Void, onQuickCreate: @escaping (Mind?, String, Int?) -> Void) {
        self.environment = environment
        self.mindService = environment.mindService
        self.mind = mind
        self.onExpandToEditor = onExpandToEditor
        self.onQuickCreate = onQuickCreate
    }

    private var availableMinds: [Mind] {
        mindService.minds
    }

    private var selectedMind: Mind? {
        guard let id = selectedMindID else { return nil }
        return availableMinds.first { $0.id == id }
    }

    private var mindColor: Color {
        if let hex = selectedMind?.colorHex,
           let color = Color(hex: hex) {
            return color
        }
        return .gray
    }

    private var titleFont: UIFont {
        if let font = UIFont(name: "Baskerville", size: 20) {
            return font
        }
        return .systemFont(ofSize: 20, weight: .regular)
    }

    private func setReminderSelection(_ minutes: Int?) {
        selectedReminderMinutes = minutes
        lastReminderMinutes = minutes ?? -1
    }

    private func loadPersistedReminderSelection() {
        selectedReminderMinutes = lastReminderMinutes > 0 ? lastReminderMinutes : nil
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                mindIconMenu

                AutoFocusTextField(
                    text: $title,
                    placeholder: "Memory",
                    font: titleFont,
                    onSubmit: {
                        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                        dismiss()
                        onQuickCreate(selectedMind, title, selectedReminderMinutes)
                    }
                )
                .frame(height: 30)

                Button {
                    dismiss()
                    onExpandToEditor(selectedMind, title)
                } label: {
                    Image(systemName: "ellipsis")
                        .rotationEffect(.degrees(90))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(width: 36, height: 36)
                        .glassEffect(.regular.tint(Color.primary.opacity(0.1)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("More options")
                .contentShape(Rectangle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            // Reminder row
            HStack(spacing: 8) {
                reminderMenu
                Spacer()
            }
            .padding(.horizontal, 20)
            Spacer()
        }
        .presentationDetents([.height(110)])
        .presentationBackground(.clear)
        .onAppear {
            if mind?.isAllMinds == true || mind?.isLimbo == true {
                selectedMindID = nil
            } else {
                selectedMindID = mind?.id
            }
            loadPersistedReminderSelection()
        }
    }

    private var mindIconMenu: some View {
        Menu {
            Picker("Mind", selection: $selectedMindID) {
                Label("No Mind", systemImage: "brain.head.profile")
                    .tag(nil as UUID?)

                ForEach(availableMinds) { mind in
                    Label(mind.name, systemImage: mind.iconName ?? "brain.head.profile")
                        .tag(Optional(mind.id))
                }
            }
        } label: {
            Image(systemName: selectedMind?.iconName ?? "brain.head.profile")
                .foregroundStyle(mindColor)
                    .frame(width: 36, height: 36)
                    .glassEffect(.regular.tint(mindColor.opacity(0.15)))
        }
    }

    private var reminderMenu: some View {
        Menu {
            Button {
                setReminderSelection(nil)
            } label: {
                if selectedReminderMinutes == nil {
                    Label("No Reminder", systemImage: "checkmark")
                } else {
                    Text("No Reminder")
                }
            }

            Divider()

            // Quick minute options
            ForEach([5, 10, 15, 30, 60], id: \.self) { minutes in
                Button {
                    setReminderSelection(minutes)
                } label: {
                    let isSelected = selectedReminderMinutes == minutes
                    let displayText = "in \(minutes) min"
                    if isSelected {
                        Label(displayText, systemImage: "checkmark")
                    } else {
                        Text(displayText)
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(selectedReminderMinutes != nil ? Color.Theme.warning : .secondary)

                if let minutes = selectedReminderMinutes {
                    Text("Remind me in \(minutes) min")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.Theme.warning)
                } else {
                    Text("Remind me in")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glassEffect(.regular.tint(selectedReminderMinutes != nil ? Color.Theme.warning.opacity(0.15) : Color.primary.opacity(0.05)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Quick reminder")
    }
}

#Preview {
    QuickMemorySheet(
        environment: {
            let env = AppEnvironment(dataController: DataController.preview)
            env.bootstrap()
            return env
        }(),
        mind: nil,
        onExpandToEditor: { _, _ in },
        onQuickCreate: { _, _, _ in }
    )
}
