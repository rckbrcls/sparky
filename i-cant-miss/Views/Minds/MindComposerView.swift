//
//  MindComposerView.swift
//  i-cant-miss
//

import SwiftUI

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct MindAutoFocusTextField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let font: UIFont
    let onSubmit: () -> Void

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.font = font
        textField.placeholder = placeholder
        textField.borderStyle = .none
        textField.autocorrectionType = .no
        textField.delegate = context.coordinator
        textField.returnKeyType = .done
        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        uiView.text = text
        if !context.coordinator.hasBecomeFirstResponder {
            DispatchQueue.main.async {
                uiView.becomeFirstResponder()
                context.coordinator.hasBecomeFirstResponder = true
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        let parent: MindAutoFocusTextField
        var hasBecomeFirstResponder = false

        init(parent: MindAutoFocusTextField) {
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

// MARK: - Mind Composer View

struct MindComposerView: View {
    let environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var selectedIcon: String = "brain.head.profile"
    @State private var selectedColorHex: String = Color.PresetColors.all.first?.hex ?? "#6366F1"
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showIconPicker = false
    private let mindToEdit: MindModel?

    init(environment: AppEnvironment, mindToEdit: MindModel? = nil) {
        self.environment = environment
        self.mindToEdit = mindToEdit
    }

    private var selectedMindColor: Color {
        Color(hex: selectedColorHex) ?? .accentColor
    }

    private var titleFont: UIFont {
        guard let font = UIFont(name: "Vollkorn-Regular", size: 20) else {
            return .systemFont(ofSize: 20, weight: .bold)
        }
        let descriptor = font.fontDescriptor.withSymbolicTraits(.traitBold)
        return UIFont(descriptor: descriptor ?? font.fontDescriptor, size: 20)
    }

    private var canSave: Bool {
        !isSaving && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                iconButton

                MindAutoFocusTextField(
                    text: $name,
                    placeholder: "Mind name",
                    font: titleFont,
                    onSubmit: {
                        guard canSave else { return }
                        saveMind()
                    }
                )
                .frame(height: 30)
            }
            .padding(20)

            Spacer()
        }
        .presentationDetents([.height(90)])
        .presentationBackground(.clear)
        .interactiveDismissDisabled(isSaving)
        .sheet(isPresented: $showIconPicker) {
            IconColorPickerSheet(
                selectedIcon: $selectedIcon,
                selectedColorHex: $selectedColorHex
            )
        }
        .onAppear {
            if let mindToEdit = mindToEdit {
                name = mindToEdit.name
                selectedIcon = mindToEdit.iconName ?? "brain.head.profile"
                selectedColorHex = mindToEdit.colorHex ?? Color.PresetColors.all.first?.hex ?? "#6366F1"
            }
        }
    }

    private var iconButton: some View {
        Button {
            showIconPicker = true
        } label: {
            Image(systemName: selectedIcon)
                .foregroundStyle(selectedMindColor)
                .frame(width: 36, height: 36)
                .glassEffect(.regular.tint(selectedMindColor.opacity(0.15)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Select icon and color")
    }

    private func saveMind() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Provide a name for the mind."
            return
        }

        errorMessage = nil
        isSaving = true

        Task {
            do {
                if let mindToEdit = mindToEdit {
                    var updatedMind = mindToEdit
                    updatedMind.name = trimmedName
                    updatedMind.colorHex = selectedColorHex
                    updatedMind.iconName = selectedIcon

                    _ = try await environment.mindService.updateMind(updatedMind)
                } else {
                    _ = try await environment.mindService.createMind(
                        name: trimmedName,
                        colorHex: selectedColorHex,
                        iconName: selectedIcon,
                        isDefault: false
                    )
                }

                _ = await environment.mindService.refresh(force: true)

                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    let environment = AppEnvironment(persistence: PersistenceController.preview)
    environment.bootstrap()
    return MindComposerView(environment: environment)
}
