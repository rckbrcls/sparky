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

    let environment: AppEnvironment
    let space: SpaceModel?
    let onExpandToEditor: (SpaceModel?, String) -> Void
    let onQuickCreate: (SpaceModel?, String) -> Void

    @State private var title: String = ""
    @State private var selectedSpaceID: UUID?

    private var availableSpaces: [SpaceModel] {
        environment.spaceService.spaces
    }

    private var selectedSpace: SpaceModel? {
        guard let id = selectedSpaceID else { return nil }
        return availableSpaces.first { $0.id == id }
    }

    private var spaceColor: Color {
        if let hex = selectedSpace?.colorHex,
           let color = Color(hex: hex) {
            return color
        }
        return .gray
    }

    private var titleFont: UIFont {
        guard let font = UIFont(name: "Vollkorn-Regular", size: 20) else {
            return .systemFont(ofSize: 20, weight: .bold)
        }
        let descriptor = font.fontDescriptor.withSymbolicTraits(.traitBold)
        return UIFont(descriptor: descriptor ?? font.fontDescriptor, size: 20)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                spaceIconMenu

                AutoFocusTextField(
                    text: $title,
                    placeholder: "Memory",
                    font: titleFont,
                    onSubmit: {
                        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                        dismiss()
                        onQuickCreate(selectedSpace, title)
                    }
                )
                .frame(height: 30)

                Button {
                    dismiss()
                    onExpandToEditor(selectedSpace, title)
                } label: {
                    Image(systemName: "ellipsis")
                        .rotationEffect(.degrees(90))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(width: 36, height: 36)
                        .glassEffect(.regular)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("More options")
                .contentShape(Rectangle())
            }
            .padding(20)

            Spacer()
        }
        .presentationDetents([.height(90)])
        .presentationBackground(.regularMaterial)
        .onAppear {
            if space?.isAllSpaces == true {
                selectedSpaceID = nil
            } else {
                selectedSpaceID = space?.id
            }
        }
    }

    private var spaceIconMenu: some View {
        Menu {
            Picker("Space", selection: $selectedSpaceID) {
                Label("No Space", systemImage: "square.grid.2x2")
                    .tag(nil as UUID?)

                ForEach(availableSpaces) { space in
                    // Use the space's icon
                    Label(space.name, systemImage: space.iconName ?? "square.grid.2x2")
                        .tag(Optional(space.id))
                }
            }
        } label: {
            Image(systemName: selectedSpace?.iconName ?? "square.grid.2x2")
                .foregroundStyle(spaceColor)
                .frame(width: 36, height: 36)
                .glassEffect(.regular.tint(spaceColor.opacity(0.15)))
        }
    }
}

#Preview {
    QuickMemorySheet(
        environment: {
            let env = AppEnvironment(persistence: PersistenceController.preview)
            env.bootstrap()
            return env
        }(),
        space: nil,
        onExpandToEditor: { _, _ in },
        onQuickCreate: { _, _ in }
    )
}
