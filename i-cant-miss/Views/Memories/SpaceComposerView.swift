//
//  SpaceComposerView.swift
//  i-cant-miss
//
//  Created by Codex on 31/10/25.
//

import SwiftUI
import UIKit

// MARK: - Auto Focus TextField

private struct SpaceAutoFocusTextField: UIViewRepresentable {
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
        var parent: SpaceAutoFocusTextField

        init(_ parent: SpaceAutoFocusTextField) {
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

// MARK: - Space Composer View

struct SpaceComposerView: View {
    let environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var selectedIcon: String = "square.grid.2x2.fill"
    @State private var selectedColorHex: String = Color.PresetColors.all.first?.hex ?? "#6366F1"
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showIconPicker = false
    private let spaceToEdit: SpaceModel?

    init(environment: AppEnvironment, spaceToEdit: SpaceModel? = nil) {
        self.environment = environment
        self.spaceToEdit = spaceToEdit
    }

    private var selectedSpaceColor: Color {
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

                SpaceAutoFocusTextField(
                    text: $name,
                    placeholder: "Space name",
                    font: titleFont,
                    onSubmit: {
                        guard canSave else { return }
                        saveSpace()
                    }
                )
                .frame(height: 30)

                if isSaving {
                    ProgressView()
                        .frame(width: 36, height: 36)
                } else {
                    Button {
                        saveSpace()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(canSave ? .primary : .secondary)
                            .frame(width: 36, height: 36)
                            .glassEffect(.regular)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSave)
                    .accessibilityLabel(spaceToEdit == nil ? "Create" : "Save")
                }
            }
            .padding(20)

            Spacer()
        }
        .presentationDetents([.height(90)])
        .presentationBackground(.regularMaterial)
        .interactiveDismissDisabled(isSaving)
        .sheet(isPresented: $showIconPicker) {
            IconColorPickerSheet(
                selectedIcon: $selectedIcon,
                selectedColorHex: $selectedColorHex
            )
        }
        .onAppear {
            if let spaceToEdit = spaceToEdit {
                name = spaceToEdit.name
                selectedIcon = spaceToEdit.iconName ?? "square.grid.2x2.fill"
                selectedColorHex = spaceToEdit.colorHex ?? Color.PresetColors.all.first?.hex ?? "#6366F1"
            }
        }
    }

    private var iconButton: some View {
        Button {
            showIconPicker = true
        } label: {
            Image(systemName: selectedIcon)
                .foregroundStyle(selectedSpaceColor)
                .frame(width: 36, height: 36)
                .glassEffect(.regular.tint(selectedSpaceColor.opacity(0.15)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Select icon and color")
    }

    private func saveSpace() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Provide a name for the space."
            return
        }

        errorMessage = nil
        isSaving = true

        Task {
            do {
                if let spaceToEdit = spaceToEdit {
                    var updatedSpace = spaceToEdit
                    updatedSpace.name = trimmedName
                    updatedSpace.colorHex = selectedColorHex
                    updatedSpace.iconName = selectedIcon

                    _ = try await environment.spaceService.updateSpace(updatedSpace)
                } else {
                    _ = try await environment.spaceService.createSpace(
                        name: trimmedName,
                        colorHex: selectedColorHex,
                        iconName: selectedIcon,
                        isDefault: false
                    )
                }

                _ = await environment.spaceService.refresh(force: true)

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
    return SpaceComposerView(environment: environment)
}
