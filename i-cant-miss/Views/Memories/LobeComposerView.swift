//
//  LobeComposerView.swift
//  i-cant-miss
//
//  Created by Codex on 31/10/25.
//

import SwiftUI
import UIKit

// MARK: - Auto Focus TextField

private struct LobeAutoFocusTextField: UIViewRepresentable {
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
        textField.autocapitalizationType = .words
        textField.autocorrectionType = .no
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
        var parent: LobeAutoFocusTextField

        init(_ parent: LobeAutoFocusTextField) {
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

// MARK: - Lobe Composer View

struct LobeComposerView: View {
    let environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var selectedIcon: String = "brain.fill"
    @State private var selectedColorHex: String = Color.PresetColors.all.first?.hex ?? "#6366F1"
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showIconPicker = false
    private let lobeToEdit: LobeModel?
    private let mindID: UUID?

    init(environment: AppEnvironment, lobeToEdit: LobeModel? = nil, mindID: UUID? = nil) {
        self.environment = environment
        self.lobeToEdit = lobeToEdit
        self.mindID = mindID
    }

    private var selectedLobeColor: Color {
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

                LobeAutoFocusTextField(
                    text: $name,
                    placeholder: "Lobe name",
                    font: titleFont,
                    onSubmit: {
                        guard canSave else { return }
                        saveLobe()
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
            if let lobeToEdit = lobeToEdit {
                name = lobeToEdit.name
                selectedIcon = lobeToEdit.iconName ?? "brain.fill"
                selectedColorHex = lobeToEdit.colorHex ?? Color.PresetColors.all.first?.hex ?? "#6366F1"
            }
        }
    }

    private var iconButton: some View {
        Button {
            showIconPicker = true
        } label: {
            Image(systemName: selectedIcon)
                .foregroundStyle(selectedLobeColor)
                .frame(width: 36, height: 36)
                .glassEffect(.regular.tint(selectedLobeColor.opacity(0.15)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Select icon and color")
    }

    private func saveLobe() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Provide a name for the lobe."
            return
        }

        errorMessage = nil
        isSaving = true

        Task {
            do {
                if let lobeToEdit = lobeToEdit {
                    var updatedLobe = lobeToEdit
                    updatedLobe.name = trimmedName
                    updatedLobe.colorHex = selectedColorHex
                    updatedLobe.iconName = selectedIcon

                    _ = try await environment.lobeService.updateLobe(updatedLobe)
                } else {
                    _ = try await environment.lobeService.createLobe(
                        name: trimmedName,
                        colorHex: selectedColorHex,
                        iconName: selectedIcon,
                        isDefault: false,
                        mindID: mindID
                    )
                }

                _ = await environment.lobeService.refresh(force: true)

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
    return LobeComposerView(environment: environment)
}
