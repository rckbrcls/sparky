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
    private let selectedParentID: UUID?
    private let parentSpaceName: String?

    init(environment: AppEnvironment, defaultParent: SpaceModel? = nil) {
        self.environment = environment
        self.selectedParentID = defaultParent?.id
        self.parentSpaceName = defaultParent?.name
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Space name", text: $name)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                        .accessibilityLabel("Space name")

                    if let parentSpaceName {
                        HStack {
                            Label("Parent", systemImage: "folder")
                            Spacer()
                            Text(parentSpaceName)
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                        .accessibilityElement(children: .combine)
                    }

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
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHGrid(rows: iconGridRows, spacing: 16) {
                ForEach(Self.iconOptions, id: \.self) { icon in
                    Button {
                        selectedIcon = icon
                    } label: {
                        Circle()
                            .fill(iconBackground(for: icon))
                            .frame(width: 56, height: 56)
                            .overlay(
                                Image(systemName: icon)
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(iconForeground(for: icon))
                            )
                            .animation(.easeInOut(duration: 0.2), value: selectedIcon)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Select \(icon) icon")
                    .accessibilityAddTraits(icon == selectedIcon ? .isSelected : [])
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .frame(height: 240)
        .listRowInsets(EdgeInsets())
    }

    private var iconGridRows: [GridItem] {
        Array(
            repeating: GridItem(.fixed(56), spacing: 16, alignment: .center),
            count: 3
        )
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
            .padding()
        }
        .listRowInsets(EdgeInsets())
    }

    private var selectedSpaceColor: Color {
        Color(hex: selectedColorHex) ?? .accentColor
    }

    private func iconBackground(for icon: String) -> Color {
        icon == selectedIcon ? selectedSpaceColor : Color(uiColor: .secondarySystemBackground)
    }

    private func iconForeground(for icon: String) -> Color {
        .primary
    }

    private func saveSpace() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Provide a name for the space."
            return
        }

        if let parentID = selectedParentID,
           environment.spaceService.space(id: parentID) == nil {
            errorMessage = "Parent space is unavailable. Refresh and try again."
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
                    audience: .reminders,
                    parentID: selectedParentID
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
        "square.grid.3x3.fill",
        "folder",
        "folder.fill",
        "tray.fill",
        "tray.full.fill",
        "bookmark.fill",
        "bookmark.circle.fill",
        "pin.fill",
        "pin.circle.fill",
        "list.bullet.rectangle",
        "list.bullet.clipboard",
        "alarm",
        "alarm.fill",
        "lightbulb",
        "lightbulb.fill",
        "star.fill",
        "star.circle.fill",
        "checkmark.circle.fill",
        "checkmark.seal.fill",
        "doc.text.fill",
        "doc.on.doc.fill",
        "calendar",
        "calendar.circle.fill",
        "paperplane.fill",
        "paperclip",
        "paperclip.circle.fill",
        "tag.fill",
        "tag.circle.fill",
        "bell.fill",
        "bell.circle.fill",
        "clock.fill",
        "clock.badge.checkmark",
        "bolt.fill",
        "flame.fill",
        "heart.fill",
        "heart.circle.fill",
        "gearshape.fill",
        "hammer.fill",
        "brain.head.profile",
        "graduationcap.fill",
        "music.note.list",
        "book.fill",
        "bookmark.square.fill",
        "camera.fill",
        "video.fill",
        "photo.fill",
        "paintbrush.fill",
        "square.and.pencil",
        "square.and.arrow.up",
        "quote.bubble.fill",
        "bubble.left.and.bubble.right.fill",
        "map.fill",
        "location.fill",
        "globe",
        "moon.stars.fill",
        "sun.max.fill",
        "cloud.fill",
        "leaf.fill"
    ]
}

#Preview {
    let environment = AppEnvironment(persistence: PersistenceController.preview)
    environment.bootstrap()
    return SpaceComposerView(environment: environment)
}
