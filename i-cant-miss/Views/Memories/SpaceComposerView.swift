//
//  SpaceComposerView.swift
//  i-cant-miss
//
//  Created by Codex on 31/10/25.
//

import SwiftUI

struct SpaceComposerView: View {
    let environment: AppEnvironment

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var selectedIcon: String = SpaceComposerView.iconOptions.first ?? "square.grid.2x2"
    @State private var selectedColorHex: String = Color.PresetColors.all.first?.hex ?? "#6366F1"
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Space name", text: $name)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                        .accessibilityLabel("Space name")

                    if isSaving {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Section("Icon") {
                    iconGrid
                }

                Section("Color") {
                    colorSelector
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("Space")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) {
                        dismiss()
                    } label: {
                        Label("Cancel", systemImage: "xmark")
                    }
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm){
                        saveSpace()
                    } label: {
                        Label("Create", systemImage: "checkmark")
                    }
                    .disabled(isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .interactiveDismissDisabled(isSaving)
        }
    }

    private var iconGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
            ForEach(Self.iconOptions, id: \.self) { icon in
                Button {
                    selectedIcon = icon
                } label: {
                    Image(systemName: icon)
                        .font(.title2)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding()
                        .foregroundStyle(iconForeground(for: icon))
                        .glassEffect(iconGlass(for: icon))
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .accessibilityLabel("Select \(icon) icon")
                .accessibilityAddTraits(icon == selectedIcon ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }

    private var colorSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Color.PresetColors.all) { preset in
                    Button {
                        selectedColorHex = preset.hex
                    } label: {
                        Circle()
                            .frame(width: 60, height: 60)
                            .overlay(
                                Circle()
                                    .strokeBorder(selectedColorHex == preset.hex ? Color.primary : Color.clear, lineWidth: 2)
                            )
                            .tint(preset.color)
                            .glassEffect()
                            .overlay {
                                if selectedColorHex == preset.hex {
                                    Image(systemName: "checkmark")
                                        .font(.title2.bold())
                                        .foregroundStyle(.white)
                                }
                            }
                    }
                    .accessibilityLabel("Select \(preset.name) color")
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func iconBackground(for icon: String) -> Color {
        if icon == selectedIcon {
            return Color(uiColor: .secondarySystemBackground)
        }
        return Color(uiColor: .systemBackground)
    }

    private func iconForeground(for icon: String) -> Color {
        icon == selectedIcon ? .primary : .accentColor
    }
    
    private func iconGlass(for icon: String) -> Glass {
        icon == selectedIcon ? .regular.tint(.accentColor).interactive() : .regular.interactive()
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
                _ = try await environment.folderService.createFolder(
                    name: trimmedName,
                    colorHex: selectedColorHex,
                    iconName: selectedIcon,
                    isDefault: false,
                    audience: .reminders
                )

                async let refreshFolders = environment.folderService.refreshFolders(force: true)
                async let refreshSpaces = environment.spaceService.refresh(force: true)
                _ = await (refreshFolders, refreshSpaces)

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

private extension SpaceComposerView {
    static let iconOptions: [String] = [
        "square.grid.2x2",
        "folder",
        "tray.fill",
        "bookmark.fill",
        "pin.fill",
        "list.bullet.rectangle",
        "alarm",
        "lightbulb",
        "star.fill",
        "checkmark.circle.fill",
        "doc.text.fill",
        "calendar"
    ]
}

#Preview {
    let environment = AppEnvironment(persistence: PersistenceController.preview)
    environment.bootstrap()
    return SpaceComposerView(environment: environment)
}
