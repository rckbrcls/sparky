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
    @State private var selectedIcon: String = SpaceComposerView.iconSections.first?.icons.first ?? "square.grid.2x2"
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

                Section("Color") {
                    colorSelector
                }

                Section("Icon") {
                    iconGrid
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
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
        VStack(alignment: .leading, spacing: 20) {
            ForEach(Self.iconSections) { section in
                VStack(alignment: .leading, spacing: 8) {
                    Text(section.title)
                        .font(.footnote.weight(.semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.bottom, 8)

                    LazyVGrid(columns: iconGridColumns, alignment: .center, spacing: 16) {
                        ForEach(section.icons, id: \.self) { icon in
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
                            .accessibilityLabel("Select \(section.title) icon")
                            .accessibilityAddTraits(icon == selectedIcon ? .isSelected : [])
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.vertical, 16)
        .listRowInsets(EdgeInsets())
    }

    private var iconGridColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(minimum: 44, maximum: 80), spacing: 16, alignment: .center),
            count: 4
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
                _ = try await environment.spaceService.createSpace(
                    name: trimmedName,
                    colorHex: selectedColorHex,
                    iconName: selectedIcon,
                    isDefault: false,
                    parentID: selectedParentID
                )

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

private extension SpaceComposerView {
    struct IconSection: Identifiable {
        let id = UUID()
        let title: String
        let icons: [String]
    }

    static let iconSections: [IconSection] = [
        IconSection(
            title: "Organization",
            icons: [
                "square.grid.2x2.fill",
                "square.grid.3x3.fill",
                "square.grid.4x3.fill",
                "folder.fill",
                "folder.badge.plus",
                "tray.fill",
                "tray.full.fill",
                "archivebox.fill",
                "archivebox.circle.fill",
                "bookmark.fill",
                "bookmark.circle.fill",
                "bookmark.square.fill",
                "pin.fill",
                "pin.circle.fill",
                "paperclip.circle.fill",
                "tag.fill",
                "tag.circle.fill",
                "list.bullet.rectangle.fill",
                "list.bullet.circle.fill"
            ]
        ),
        IconSection(
            title: "Time & Focus",
            icons: [
                "alarm.fill",
                "clock.fill",
                "clock.badge.checkmark",
                "hourglass.circle.fill",
                "calendar.circle.fill",
                "calendar.badge.clock",
                "stopwatch.fill",
            ]
        ),
        IconSection(
            title: "Work & Study",
            icons: [
                "doc.text.fill",
                "doc.on.doc.fill",
                "doc.richtext.fill",
                "doc.append.fill",
                "briefcase.fill",
                "graduationcap.fill",
                "book.fill",
                "text.book.closed.fill",
                "book.closed.fill",
                "lightbulb.fill",
                "square.and.arrow.up.fill",
                "square.and.arrow.down.fill"
            ]
        ),
        IconSection(
            title: "Communication",
            icons: [
                "paperplane.fill",
                "envelope.fill",
                "envelope.circle.fill",
                "envelope.badge.fill",
                "phone.fill",
                "phone.circle.fill",
                "message.fill",
                "message.circle.fill",
                "quote.bubble.fill",
                "bubble.left.fill",
                "bubble.left.and.bubble.right.fill",
                "at.circle.fill",
                "number.circle.fill"
            ]
        ),
        IconSection(
            title: "Alerts & Status",
            icons: [
                "bell.fill",
                "bell.circle.fill",
                "bell.badge.fill",
                "bell.slash.fill",
                "exclamationmark.circle.fill",
                "exclamationmark.triangle.fill",
                "flag.fill",
                "flag.circle.fill",
                "bolt.fill",
                "flame.fill",
                "eye.fill",
                "eye.slash.fill"
            ]
        ),
        IconSection(
            title: "People & Health",
            icons: [
                "person.fill",
                "person.2.fill",
                "person.3.fill",
                "person.crop.circle.fill",
                "person.2.circle.fill",
                "person.crop.square.fill",
                "heart.fill",
                "heart.circle.fill",
                "cross.case.fill",
                "cross.fill",
                "cross.circle.fill",
                "plus.circle.fill",
                "minus.circle.fill"
            ]
        ),
        IconSection(
            title: "Places & Travel",
            icons: [
                "house.fill",
                "building.2.fill",
                "building.2.crop.circle.fill",
                "map.fill",
                "mappin.circle.fill",
                "location.fill",
                "location.circle.fill",
                "location.north.fill",
                "car.fill",
                "car.circle.fill",
                "tram.fill",
                "sailboat.fill"
            ]
        ),
        IconSection(
            title: "Media & Creativity",
            icons: [
                "camera.fill",
                "camera.circle.fill",
                "photo.fill",
                "photo.on.rectangle.fill",
                "photo.stack.fill",
                "video.fill",
                "video.circle.fill",
                "film.fill",
                "mic.fill",
                "mic.circle.fill",
                "music.note.list",
                "pencil.tip.crop.circle.badge.plus"
            ]
        ),
        IconSection(
            title: "Symbols & Emotions",
            icons: [
                "star.fill",
                "star.circle.fill",
                "star.square.fill",
                "hand.thumbsup.fill",
                "hand.thumbsdown.fill",
                "hand.point.right.fill",
                "hand.tap.fill",
                "hand.raised.fill",
                "hand.wave.fill",
                "face.smiling.fill",
                "face.dashed.fill",
                "seal.fill",
                "checkmark.circle.fill",
                "checkmark.seal.fill",
                "xmark.circle.fill",
                "questionmark.circle.fill",
                "info.circle.fill",
                "arrow.up.circle.fill",
                "arrow.down.circle.fill",
                "arrow.left.circle.fill",
                "arrow.right.circle.fill"
            ]
        ),
        IconSection(
            title: "Nature & Environment",
            icons: [
                "leaf.fill",
                "leaf.circle.fill",
                "tree.fill",
                "globe.americas.fill",
                "globe.europe.africa.fill",
                "globe.asia.australia.fill",
                "moon.stars.fill",
                "sun.min.fill",
                "sun.horizon.fill"
            ]
        ),
        IconSection(
            title: "Tools & System",
            icons: [
                "gearshape.fill",
                "gearshape.2.fill",
                "hammer.fill",
                "wrench.and.screwdriver.fill",
                "key.fill",
                "lock.fill",
                "lock.open.fill",
                "lock.shield.fill",
                "trash.fill",
                "trash.circle.fill",
                "icloud.fill",
                "externaldrive.fill",
            ]
        ),
        IconSection(
            title: "Sports & Fitness",
            icons: [
                "sportscourt.fill",
                "basketball.fill",
                "baseball.fill",
                "tennisball.fill",
                "trophy.fill",
                "medal.fill",
                "crown.fill"
            ]
        ),
        IconSection(
            title: "Food & Drink",
            icons: [
                "cup.and.saucer.fill",
                "wineglass.fill",
                "basket.fill",
                "takeoutbag.and.cup.and.straw.fill",
                "birthday.cake.fill"
            ]
        ),
        IconSection(
            title: "Shopping & Commerce",
            icons: [
                "cart.fill",
                "cart.circle.fill",
                "bag.fill",
                "bag.circle.fill",
                "purchased.circle.fill",
                "storefront.fill"
            ]
        ),
        IconSection(
            title: "Technology",
            icons: [
                "tv.fill",
                "battery.100.bolt"
            ]
        ),
        IconSection(
            title: "Entertainment",
            icons: [
                "play.fill",
                "play.circle.fill",
                "pause.fill",
                "pause.circle.fill",
                "stop.fill",
                "stop.circle.fill",
                "forward.fill",
                "backward.fill",
                "theatermasks.fill",
                "party.popper.fill",
                "dice.fill"
            ]
        ),
        IconSection(
            title: "Finance & Money",
            icons: [
                "dollarsign.circle.fill",
                "eurosign.circle.fill",
                "yensign.circle.fill",
                "bitcoinsign.circle.fill",
                "creditcard.fill",
                "wallet.pass.fill",
                "chart.bar.fill",
                "chart.pie.fill",
                "banknote.fill",
                "arrow.up.right.square.fill",
                "arrow.down.right.square.fill"
            ]
        ),
        IconSection(
            title: "Activities & Hobbies",
            icons: [
                "paintbrush.fill",
                "paintpalette.fill",
                "pencil.and.outline",
                "gamecontroller.fill",
                "puzzlepiece.extension.fill",
                "puzzlepiece.fill",
                "balloon.fill",
                "balloon.2.fill",
                "gift.fill",
                "gift.circle.fill"
            ]
        ),
        IconSection(
            title: "Weather & Climate",
            icons: [
                "sun.max.fill",
                "moon.fill",
                "cloud.fill",
                "cloud.sun.fill",
                "cloud.rain.fill",
                "cloud.snow.fill",
                "cloud.bolt.fill",
                "thermometer.sun.fill",
                "drop.fill",
                "umbrella.fill"
            ]
        )
    ]
}

#Preview {
    let environment = AppEnvironment(persistence: PersistenceController.preview)
    environment.bootstrap()
    return SpaceComposerView(environment: environment)
}
