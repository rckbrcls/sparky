//
//  QuickMemorySheet.swift
//  i-cant-miss
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
    @ObservedObject private var lobeService: LobeService

    let environment: AppEnvironment
    let lobe: LobeModel?
    let onExpandToEditor: (LobeModel?, String) -> Void
    let onQuickCreate: (LobeModel?, String, Int?) -> Void // Added Int? for reminder minutes

    @State private var title: String = ""
    @State private var selectedLobeID: UUID?
    @State private var selectedReminderMinutes: Int? = nil // nil means no reminder selected

    init(environment: AppEnvironment, lobe: LobeModel?, onExpandToEditor: @escaping (LobeModel?, String) -> Void, onQuickCreate: @escaping (LobeModel?, String, Int?) -> Void) {
        self.environment = environment
        self.lobeService = environment.lobeService
        self.lobe = lobe
        self.onExpandToEditor = onExpandToEditor
        self.onQuickCreate = onQuickCreate
    }

    private var availableLobes: [LobeModel] {
        lobeService.lobes
    }

    private var selectedLobe: LobeModel? {
        guard let id = selectedLobeID else { return nil }
        return availableLobes.first { $0.id == id }
    }

    private var lobeColor: Color {
        if let hex = selectedLobe?.colorHex,
           let color = Color(hex: hex) {
            return color
        }
        return .gray
    }

    private var titleFont: UIFont {
        if let font = UIFont(name: "Vollkorn-Regular", size: 20) {
            return font
        }
        return .systemFont(ofSize: 20, weight: .regular)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                lobeIconMenu

                AutoFocusTextField(
                    text: $title,
                    placeholder: "Memory",
                    font: titleFont,
                    onSubmit: {
                        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                        dismiss()
                        onQuickCreate(selectedLobe, title, selectedReminderMinutes)
                    }
                )
                .frame(height: 30)

                Button {
                    dismiss()
                    onExpandToEditor(selectedLobe, title)
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
            if lobe?.isAllLobes == true {
                selectedLobeID = nil
            } else {
                selectedLobeID = lobe?.id
            }
        }
    }

    private var lobeIconMenu: some View {
        Menu {
            Picker("Lobe", selection: $selectedLobeID) {
                Label("No Lobe", systemImage: "brain.fill")
                    .tag(nil as UUID?)

                ForEach(availableLobes) { lobe in
                    // Use the lobe's icon
                    Label(lobe.name, systemImage: lobe.iconName ?? "brain.fill")
                        .tag(Optional(lobe.id))
                }
            }
        } label: {
            Image(systemName: selectedLobe?.iconName ?? "brain.fill")
                .foregroundStyle(lobeColor)
                    .frame(width: 36, height: 36)
                    .glassEffect(.regular.tint(lobeColor.opacity(0.15)))
        }
    }

    private var reminderMenu: some View {
        Menu {
            Button {
                selectedReminderMinutes = nil
            } label: {
                Label("No Reminder", systemImage: selectedReminderMinutes == nil ? "checkmark" : "")
            }

            Divider()

            // Quick minute options
            ForEach([5, 10, 15, 30, 60], id: \.self) { minutes in
                Button {
                    selectedReminderMinutes = minutes
                } label: {
                    let isSelected = selectedReminderMinutes == minutes
                    let displayText = "in \(minutes) min"
                    Label(displayText, systemImage: isSelected ? "checkmark" : "")
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(selectedReminderMinutes != nil ? .orange : .secondary)

                if let minutes = selectedReminderMinutes {
                    Text("Remind me in \(minutes) min")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.orange)
                } else {
                    Text("Remind me in")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glassEffect(.regular.tint(selectedReminderMinutes != nil ? Color.orange.opacity(0.15) : Color.primary.opacity(0.05)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Quick reminder")
    }
}

#Preview {
    QuickMemorySheet(
        environment: {
            let env = AppEnvironment(persistence: PersistenceController.preview)
            env.bootstrap()
            return env
        }(),
        lobe: nil,
        onExpandToEditor: { _, _ in },
        onQuickCreate: { _, _, _ in }
    )
}
