//
//  IconColorPickerSheet.swift
//  i-cant-miss
//
//  Created by Codex on 10/12/24.
//

import SwiftUI

struct IconColorPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedIcon: String
    @Binding var selectedColorHex: String

    @State private var searchText: String = ""

    private var selectedColor: Color {
        Color(hex: selectedColorHex) ?? .accentColor
    }

    private var filteredSections: [IconSection] {
        guard !searchText.isEmpty else { return Self.iconSections }

        let query = searchText.lowercased()
        return Self.iconSections.compactMap { section in
            let matchingIcons = section.icons.filter { icon in
                icon.lowercased().contains(query) ||
                section.title.lowercased().contains(query)
            }
            guard !matchingIcons.isEmpty else { return nil }
            return IconSection(title: section.title, icons: matchingIcons)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    colorSelector

                    iconGrid
                }
                .padding(.vertical, 16)
            }
            .searchable(text: $searchText, prompt: "Search icons")
            .navigationTitle("Icon & Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

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
                ContentUnavailableView.search(text: searchText)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
            }
        }
    }

    private var iconGridColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(minimum: 44, maximum: 60), spacing: 12, alignment: .center),
            count: 5
        )
    }

    private func iconBackground(for icon: String) -> Color {
        icon == selectedIcon ? selectedColor : Color(uiColor: .tertiarySystemBackground)
    }

    private func iconForeground(for icon: String) -> Color {
        icon == selectedIcon ? .white : .primary
    }
}

// MARK: - Icon Section

private extension IconColorPickerSheet {
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
    @Previewable @State var icon = "square.grid.2x2.fill"
    @Previewable @State var colorHex = Color.PresetColors.all.first?.hex ?? "#6366F1"

    IconColorPickerSheet(selectedIcon: $icon, selectedColorHex: $colorHex)
}
