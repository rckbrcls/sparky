import SwiftUI

struct FocusTriggerEditorScreen: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: MemoryEditorViewModel
    private let showsCloseButton: Bool
    @State private var focusName: String
    @State private var selectedFocusIdentifier: String?

    private var existingTrigger: MemoryTriggerDraft? {
        viewModel.triggers.first(where: { $0.type == .focus })
    }

    // Lista de modos de foco comuns
    private let commonFocusModes: [(identifier: String?, name: String)] = [
        (nil, "Any Focus Mode"),
        ("com.apple.focus.personal", "Personal"),
        ("com.apple.focus.work", "Work"),
        ("com.apple.focus.sleep", "Sleep"),
        ("com.apple.focus.driving", "Driving"),
        ("com.apple.focus.fitness", "Fitness"),
        ("com.apple.focus.gaming", "Gaming"),
        ("com.apple.focus.reading", "Reading")
    ]

    init(viewModel: MemoryEditorViewModel, showsCloseButton: Bool = true) {
        self.viewModel = viewModel
        self.showsCloseButton = showsCloseButton
        let trigger = viewModel.triggers.first(where: { $0.type == .focus })
        _focusName = State(initialValue: trigger?.focus?.focusName ?? "")
        _selectedFocusIdentifier = State(initialValue: trigger?.focus?.focusIdentifier)
    }

    var body: some View {
        Form {
            Section("Focus Mode") {
                if #available(iOS 15.0, *) {
                    Picker("Focus Mode", selection: $selectedFocusIdentifier) {
                        ForEach(commonFocusModes, id: \.identifier) { mode in
                            Text(mode.name).tag(mode.identifier as String?)
                        }
                    }

                    if let selected = selectedFocusIdentifier,
                       let mode = commonFocusModes.first(where: { $0.identifier == selected }) {
                        TextField("Custom Name", text: $focusName)
                            .placeholder(when: focusName.isEmpty) {
                                Text(mode.name)
                            }
                    } else {
                        TextField("Focus Mode Name", text: $focusName)
                    }
                } else {
                    TextField("Focus Mode Name", text: $focusName)
                        .disabled(true)
                    Text("Focus triggers require iOS 15 or later.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Text("Get reminded when you activate a specific focus mode.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle(existingTrigger == nil ? "Add Focus Trigger" : "Edit Focus Trigger")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsCloseButton {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: dismiss.callAsFunction) {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close")
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(role: .confirm, action: commitChanges) {
                    Image(systemName: confirmationIconName)
                }
                .accessibilityLabel(confirmationAccessibilityLabel)
                .disabled(focusName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if existingTrigger != nil {
                    Button(role: .destructive, action: removeTrigger) {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Remove focus trigger")
                }
            }
        }
    }

    private func commitChanges() {
        let trimmedName = focusName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        // Se nenhum modo específico foi selecionado, usar o nome digitado
        let finalIdentifier = selectedFocusIdentifier
        let finalName = trimmedName.isEmpty ? (commonFocusModes.first(where: { $0.identifier == selectedFocusIdentifier })?.name ?? "Focus") : trimmedName

        if let trigger = existingTrigger {
            var updated = trigger
            updated.focus = .init(
                focusIdentifier: finalIdentifier,
                focusName: finalName
            )
            viewModel.updateTrigger(id: trigger.id, with: updated)
        } else {
            viewModel.addFocusTrigger(
                focusIdentifier: finalIdentifier,
                focusName: finalName
            )
        }
        dismiss()
    }

    private var confirmationIconName: String { "checkmark" }

    private var confirmationAccessibilityLabel: String {
        existingTrigger == nil ? "Add" : "Save"
    }

    private func removeTrigger() {
        guard let trigger = existingTrigger else { return }
        viewModel.removeTrigger(id: trigger.id)
        dismiss()
    }
}

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}
