//
//  MindComposerView.swift
//  sparky
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
        textField.textAlignment = .center
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
    @State private var iconSearchText: String = ""
    private let mindToEdit: Mind?
    private let parentMind: Mind?

    init(environment: AppEnvironment, mindToEdit: Mind? = nil, parentMind: Mind? = nil) {
        self.environment = environment
        self.mindToEdit = mindToEdit
        self.parentMind = parentMind
    }

    private var selectedMindColor: Color {
        Color(hex: selectedColorHex) ?? .accentColor
    }

    private var titleFont: UIFont {
        guard let font = UIFont(name: "Baskerville", size: 20) else {
            return .systemFont(ofSize: 20, weight: .bold)
        }
        let descriptor = font.fontDescriptor.withSymbolicTraits(.traitBold)
        return UIFont(descriptor: descriptor ?? font.fontDescriptor, size: 20)
    }

    private var canSave: Bool {
        !isSaving && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var filteredSections: [IconColorPickerSheet.IconSection] {
        guard !iconSearchText.isEmpty else { return IconColorPickerSheet.iconSections }

        let query = iconSearchText.lowercased()
        return IconColorPickerSheet.iconSections.compactMap { section in
            let matchingIcons = section.icons.filter { icon in
                IconColorPickerSheet.iconMatchesQuery(icon, query: query, sectionTitle: section.title)
            }
            guard !matchingIcons.isEmpty else { return nil }
            return IconColorPickerSheet.IconSection(title: section.title, icons: matchingIcons)
        }
    }

    private var iconGridColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(minimum: 44, maximum: 60), spacing: 12, alignment: .center),
            count: 5
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    previewCircle
                        .frame(maxWidth: .infinity)
                        .padding(.top, 16)

                    MindAutoFocusTextField(
                        text: $name,
                        placeholder: "Mind",
                        font: titleFont,
                        onSubmit: {
                            guard canSave else { return }
                            saveMind()
                        }
                    )
                    .frame(height: 30)
                    .padding(.horizontal, 20)

                    colorSelector

                    iconSearchBar

                    iconGrid
                }
                .padding(.vertical, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.Theme.secondaryBackground.ignoresSafeArea())
            .navigationTitle(mindToEdit != nil ? "Edit Mind" : "New Mind")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveMind()
                    }
                    .disabled(!canSave)
                }
            }
        }
        .interactiveDismissDisabled(isSaving)
        .onAppear {
            if let mindToEdit = mindToEdit {
                name = mindToEdit.name
                selectedIcon = mindToEdit.iconName ?? "brain.head.profile"
                selectedColorHex = mindToEdit.colorHex ?? Color.PresetColors.all.first?.hex ?? "#6366F1"
            }
        }
    }

    // MARK: - Preview Circle

    private var previewCircle: some View {
        Image(systemName: selectedIcon)
            .font(.title)
            .foregroundStyle(.white)
            .frame(width: 60, height: 60)
            .background(selectedMindColor, in: .circle)
            .glassEffect(.regular.tint(selectedMindColor.opacity(0.3)))
    }

    // MARK: - Color Selector

    private var colorSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Color")
                .font(.footnote.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Color.PresetColors.all) { preset in
                        Button {
                            selectedColorHex = preset.hex
                        } label: {
                            Circle()
                                .fill(preset.color)
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Circle()
                                        .strokeBorder(selectedColorHex == preset.hex ? Color.primary : Color.clear, lineWidth: 2)
                                )
                                .overlay {
                                    if selectedColorHex == preset.hex {
                                        Image(systemName: "checkmark")
                                            .font(.body.bold())
                                            .foregroundStyle(.white)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Select \(preset.name) color")
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Icon Search Bar

    private var iconSearchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search icons...", text: $iconSearchText)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()

            if !iconSearchText.isEmpty {
                Button {
                    iconSearchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .glassEffect(in: .capsule)
        .padding(.horizontal, 20)
    }

    // MARK: - Icon Grid

    private var iconGrid: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(filteredSections) { section in
                VStack(alignment: .leading, spacing: 8) {
                    Text(section.title)
                        .font(.footnote.weight(.semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)

                    LazyVGrid(columns: iconGridColumns, alignment: .center, spacing: 12) {
                        ForEach(section.icons, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                            } label: {
                                Circle()
                                    .fill(iconBackground(for: icon))
                                    .frame(width: 48, height: 48)
                                    .overlay(
                                        Image(systemName: icon)
                                            .font(.body.weight(.semibold))
                                            .foregroundStyle(iconForeground(for: icon))
                                    )
                                    .animation(.easeInOut(duration: 0.2), value: selectedIcon)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Select \(icon) icon")
                            .accessibilityAddTraits(icon == selectedIcon ? .isSelected : [])
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }

            if filteredSections.isEmpty {
                ContentUnavailableView.search(text: iconSearchText)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
            }
        }
    }

    // MARK: - Helpers

    private func iconBackground(for icon: String) -> Color {
        icon == selectedIcon ? selectedMindColor : Color.Theme.elementBackground
    }

    private func iconForeground(for icon: String) -> Color {
        icon == selectedIcon ? .white : .primary
    }

    // MARK: - Save

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
                    let updatedMind = mindToEdit
                    updatedMind.name = trimmedName
                    updatedMind.colorHex = selectedColorHex
                    updatedMind.iconName = selectedIcon

                    _ = try await environment.mindService.updateMind(updatedMind)
                } else {
                    _ = try await environment.mindService.createMind(
                        name: trimmedName,
                        colorHex: selectedColorHex,
                        iconName: selectedIcon,
                        isDefault: false,
                        parent: parentMind
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
    let environment = AppEnvironment(dataController: DataController.preview)
    environment.bootstrap()
    return MindComposerView(environment: environment)
}
