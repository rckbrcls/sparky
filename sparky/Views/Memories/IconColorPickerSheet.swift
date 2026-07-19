//
//  IconColorPickerSheet.swift
//  sparky
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
                Self.iconMatchesQuery(icon, query: query, sectionTitle: section.title)
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
            .scrollDismissesKeyboard(.interactively)
            .searchable(text: $searchText, prompt: "Search icons")
            .navigationTitle("Icon & Color")
            .inlinePhoneNavigationTitle()
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
        icon == selectedIcon ? selectedColor : Color.Theme.elementBackground
    }

    private func iconForeground(for icon: String) -> Color {
        icon == selectedIcon ? .white : .primary
    }
}

// MARK: - Icon Section & Data

extension IconColorPickerSheet {
    struct IconSection: Identifiable {
        let id = UUID()
        let title: String
        let icons: [String]
    }

    static func iconMatchesQuery(_ icon: String, query: String, sectionTitle: String) -> Bool {
        if icon.lowercased().contains(query) { return true }
        if sectionTitle.lowercased().contains(query) { return true }
        if let tags = iconTags[icon] {
            return tags.contains { $0.contains(query) }
        }
        return false
    }

    // MARK: - Semantic Tags

    static let iconTags: [String: [String]] = [
        // Organization
        "brain.fill": ["mind", "think", "idea", "mental", "thought", "intelligence", "knowledge"],
        "folder.fill": ["folder", "files", "organize", "documents", "project"],
        "archivebox.fill": ["archive", "storage", "save", "backup", "old"],
        "bookmark.fill": ["save", "favorite", "reading", "mark", "later"],
        "pin.fill": ["pin", "important", "stick", "remember", "note"],
        "tag.fill": ["label", "category", "organize", "classify", "group"],
        "list.bullet.rectangle.fill": ["list", "tasks", "todo", "checklist", "items"],
        "tray.fill": ["inbox", "collect", "organize", "receive"],

        // Time & Focus
        "alarm.fill": ["alarm", "wake", "morning", "reminder", "alert"],
        "clock.fill": ["time", "schedule", "routine", "hours", "daily"],
        "hourglass.circle.fill": ["wait", "patience", "deadline", "time", "countdown"],
        "calendar.circle.fill": ["date", "schedule", "plan", "events", "agenda", "month"],
        "stopwatch.fill": ["timer", "speed", "exercise", "track", "interval"],

        // Work & Study
        "doc.text.fill": ["document", "notes", "writing", "text", "file", "report"],
        "briefcase.fill": ["work", "job", "career", "business", "office", "professional"],
        "graduationcap.fill": ["school", "education", "learning", "study", "college", "university"],
        "book.fill": ["reading", "study", "library", "knowledge", "literature"],
        "lightbulb.fill": ["idea", "inspiration", "creativity", "insight", "think", "innovation"],

        // Communication
        "paperplane.fill": ["send", "message", "email", "share", "deliver"],
        "envelope.fill": ["email", "mail", "letter", "correspondence", "inbox"],
        "phone.fill": ["call", "contact", "phone", "talk", "mobile"],
        "message.fill": ["chat", "text", "sms", "conversation", "messaging"],
        "bubble.left.fill": ["speech", "talk", "comment", "discuss", "dialogue"],
        "quote.bubble.fill": ["quote", "speech", "wisdom", "saying", "dialogue"],

        // Alerts & Priority
        "bell.fill": ["notification", "alert", "reminder", "ring", "attention"],
        "exclamationmark.triangle.fill": ["warning", "urgent", "important", "caution", "danger"],
        "flag.fill": ["flag", "mark", "priority", "goal", "milestone", "report"],
        "bolt.fill": ["energy", "power", "fast", "quick", "urgent", "electric"],
        "flame.fill": ["fire", "hot", "trending", "passion", "intense", "motivation"],

        // People & Relationships
        "person.fill": ["person", "self", "individual", "profile", "me", "user"],
        "person.2.fill": ["people", "couple", "together", "team", "group", "friends"],
        "heart.fill": ["love", "health", "favorite", "like", "wellness", "relationship", "care"],
        "cross.case.fill": ["medical", "health", "doctor", "hospital", "emergency", "first aid"],
        "hand.thumbsup.fill": ["like", "approve", "good", "positive", "feedback", "agree"],
        "face.smiling.fill": ["happy", "mood", "emoji", "feeling", "joy", "smile"],

        // Home & Travel
        "house.fill": ["home", "house", "family", "domestic", "living", "residence"],
        "building.2.fill": ["office", "work", "city", "building", "company", "urban"],
        "map.fill": ["map", "travel", "navigate", "explore", "trip", "journey"],
        "mappin.circle.fill": ["location", "place", "destination", "address", "visit"],
        "location.fill": ["location", "gps", "navigate", "here", "current", "position"],
        "car.fill": ["car", "drive", "commute", "transport", "vehicle", "road"],
        "sailboat.fill": ["boat", "sail", "ocean", "sea", "vacation", "nautical"],
        "tram.fill": ["train", "transit", "metro", "subway", "public transport", "commute"],

        // Media & Creativity
        "camera.fill": ["photo", "camera", "picture", "snap", "photography"],
        "photo.fill": ["image", "picture", "gallery", "album", "memories"],
        "video.fill": ["video", "movie", "record", "film", "cinema"],
        "mic.fill": ["audio", "podcast", "voice", "record", "microphone", "speak"],
        "music.note.list": ["music", "songs", "playlist", "audio", "listen"],
        "paintbrush.fill": ["art", "draw", "paint", "design", "creative", "craft"],
        "paintpalette.fill": ["colors", "design", "art", "creative", "palette", "aesthetic"],

        // Nature & Wellness
        "leaf.fill": ["nature", "plant", "eco", "green", "organic", "health", "garden"],
        "tree.fill": ["nature", "forest", "growth", "life", "outdoor", "park"],
        "globe.americas.fill": ["world", "global", "earth", "international", "travel", "planet"],
        "moon.stars.fill": ["night", "sleep", "dream", "rest", "evening", "bedtime"],
        "sun.max.fill": ["sun", "morning", "energy", "bright", "day", "summer"],
        "sun.horizon.fill": ["sunset", "sunrise", "dawn", "dusk", "horizon", "evening"],
        "drop.fill": ["water", "hydration", "rain", "drink", "liquid", "wellness"],

        // Sports & Fitness
        "sportscourt.fill": ["sport", "game", "exercise", "court", "field", "match"],
        "basketball.fill": ["basketball", "sport", "game", "play", "ball"],
        "trophy.fill": ["win", "achievement", "goal", "competition", "prize", "success"],
        "medal.fill": ["award", "achievement", "success", "recognition", "honor"],
        "crown.fill": ["king", "queen", "best", "premium", "royal", "top", "vip"],

        // Food & Drink
        "cup.and.saucer.fill": ["coffee", "tea", "drink", "cafe", "break", "morning"],
        "wineglass.fill": ["wine", "drink", "social", "party", "dinner", "celebration"],
        "basket.fill": ["groceries", "shopping", "market", "food", "produce"],
        "birthday.cake.fill": ["birthday", "celebration", "cake", "party", "anniversary"],

        // Shopping & Finance
        "cart.fill": ["shopping", "buy", "store", "groceries", "purchase", "ecommerce"],
        "bag.fill": ["shopping", "purchase", "fashion", "retail", "store"],
        "storefront.fill": ["store", "shop", "business", "retail", "market"],
        "dollarsign.circle.fill": ["money", "finance", "dollar", "payment", "budget", "salary"],
        "creditcard.fill": ["payment", "card", "bank", "purchase", "credit", "debit"],
        "chart.bar.fill": ["stats", "data", "analytics", "graph", "progress", "metrics"],
        "chart.pie.fill": ["stats", "analytics", "breakdown", "data", "distribution"],
        "banknote.fill": ["cash", "money", "payment", "salary", "income", "expense"],

        // Tools & Technology
        "gearshape.fill": ["settings", "config", "system", "preferences", "setup"],
        "key.fill": ["key", "password", "security", "access", "unlock", "secret"],
        "lock.fill": ["security", "private", "locked", "safe", "protect", "secret"],
        "icloud.fill": ["cloud", "sync", "backup", "storage", "online", "data"],
        "hammer.fill": ["build", "construct", "tool", "repair", "fix", "diy"],
        "wrench.and.screwdriver.fill": ["tools", "repair", "fix", "maintain", "settings"],

        // Entertainment & Hobbies
        "gamecontroller.fill": ["game", "play", "gaming", "entertainment", "console", "fun"],
        "puzzlepiece.fill": ["puzzle", "solve", "think", "challenge", "logic", "brain teaser"],
        "theatermasks.fill": ["theater", "drama", "acting", "arts", "movies", "performance"],
        "party.popper.fill": ["party", "celebration", "fun", "event", "festive"],
        "dice.fill": ["game", "chance", "random", "luck", "board game", "fun"],
        "balloon.fill": ["party", "celebration", "fun", "birthday", "festive"],
        "gift.fill": ["gift", "present", "surprise", "birthday", "giving"],
        "play.fill": ["play", "media", "video", "stream", "watch", "listen"],

        // Symbols
        "star.fill": ["favorite", "rate", "important", "special", "best", "featured"],
        "checkmark.circle.fill": ["done", "complete", "check", "success", "approved", "finished"],
        "umbrella.fill": ["rain", "protection", "weather", "insurance", "safety"],
    ]

    // MARK: - Icon Sections

    static let iconSections: [IconSection] = [
        IconSection(
            title: "Organization",
            icons: [
                "brain.fill",
                "folder.fill",
                "archivebox.fill",
                "bookmark.fill",
                "pin.fill",
                "tag.fill",
                "list.bullet.rectangle.fill",
                "tray.fill"
            ]
        ),
        IconSection(
            title: "Time & Focus",
            icons: [
                "alarm.fill",
                "clock.fill",
                "hourglass.circle.fill",
                "calendar.circle.fill",
                "stopwatch.fill"
            ]
        ),
        IconSection(
            title: "Work & Study",
            icons: [
                "doc.text.fill",
                "briefcase.fill",
                "graduationcap.fill",
                "book.fill",
                "lightbulb.fill"
            ]
        ),
        IconSection(
            title: "Communication",
            icons: [
                "paperplane.fill",
                "envelope.fill",
                "phone.fill",
                "message.fill",
                "bubble.left.fill",
                "quote.bubble.fill"
            ]
        ),
        IconSection(
            title: "Alerts & Priority",
            icons: [
                "bell.fill",
                "exclamationmark.triangle.fill",
                "flag.fill",
                "bolt.fill",
                "flame.fill"
            ]
        ),
        IconSection(
            title: "People & Relationships",
            icons: [
                "person.fill",
                "person.2.fill",
                "heart.fill",
                "cross.case.fill",
                "hand.thumbsup.fill",
                "face.smiling.fill"
            ]
        ),
        IconSection(
            title: "Home & Travel",
            icons: [
                "house.fill",
                "building.2.fill",
                "map.fill",
                "mappin.circle.fill",
                "location.fill",
                "car.fill",
                "sailboat.fill",
                "tram.fill"
            ]
        ),
        IconSection(
            title: "Media & Creativity",
            icons: [
                "camera.fill",
                "photo.fill",
                "video.fill",
                "mic.fill",
                "music.note.list",
                "paintbrush.fill",
                "paintpalette.fill"
            ]
        ),
        IconSection(
            title: "Nature & Wellness",
            icons: [
                "leaf.fill",
                "tree.fill",
                "globe.americas.fill",
                "moon.stars.fill",
                "sun.max.fill",
                "sun.horizon.fill",
                "drop.fill"
            ]
        ),
        IconSection(
            title: "Sports & Fitness",
            icons: [
                "sportscourt.fill",
                "basketball.fill",
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
                "birthday.cake.fill"
            ]
        ),
        IconSection(
            title: "Shopping & Finance",
            icons: [
                "cart.fill",
                "bag.fill",
                "storefront.fill",
                "dollarsign.circle.fill",
                "creditcard.fill",
                "chart.bar.fill",
                "chart.pie.fill",
                "banknote.fill"
            ]
        ),
        IconSection(
            title: "Tools & Technology",
            icons: [
                "gearshape.fill",
                "key.fill",
                "lock.fill",
                "icloud.fill",
                "hammer.fill",
                "wrench.and.screwdriver.fill"
            ]
        ),
        IconSection(
            title: "Entertainment & Hobbies",
            icons: [
                "gamecontroller.fill",
                "puzzlepiece.fill",
                "theatermasks.fill",
                "party.popper.fill",
                "dice.fill",
                "balloon.fill",
                "gift.fill",
                "play.fill"
            ]
        ),
        IconSection(
            title: "Symbols",
            icons: [
                "star.fill",
                "checkmark.circle.fill",
                "umbrella.fill"
            ]
        )
    ]
}

#Preview {
    @Previewable @State var icon = "brain.fill"
    @Previewable @State var colorHex = Color.PresetColors.all.first?.hex ?? "#6366F1"

    IconColorPickerSheet(selectedIcon: $icon, selectedColorHex: $colorHex)
}
