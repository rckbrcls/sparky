//
//  NoteCardView.swift
//  i-cant-miss
//
//  Created by Codex on 13/10/25.
//

import SwiftUI

struct NoteCardView: View {
    let note: NoteModel

    private var headerColor: Color {
        guard let hex = note.folder?.colorHex,
              let color = Color(hex: hex) else {
            return .accentColor.opacity(0.25)
        }
        return color.opacity(0.25)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(note.title?.isEmpty == false ? note.title! : note.content.prefix(40) + "…")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if let folder = note.folder {
                        Label(folder.name, systemImage: folder.iconName ?? "folder")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if note.isPinned {
                    Image(systemName: "pin.fill")
                        .rotationEffect(.degrees(45))
                        .foregroundStyle(.orange)
                        .font(.caption)
                }
            }

            Text(note.content)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(6)

            if !note.tags.isEmpty {
                FlexibleView(data: note.tags, spacing: 6, alignment: .leading) { tag in
                    Text(tag.name)
                        .font(.caption)
                        .padding(.vertical, 3)
                        .padding(.horizontal, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(hex: tag.colorHex ?? "#d1d5db")?.opacity(0.15) ?? Color.secondary.opacity(0.15))
                        )
                }
            }

            HStack {
                Text("Updated \(note.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.background)
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(headerColor, lineWidth: 1)
                )
        )
    }
}

// MARK: - Flexible layout helper

private struct FlexibleView<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable {
    let data: Data
    let spacing: CGFloat
    let alignment: HorizontalAlignment
    let content: (Data.Element) -> Content

    init(data: Data, spacing: CGFloat, alignment: HorizontalAlignment, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data
        self.spacing = spacing
        self.alignment = alignment
        self.content = content
    }

    var body: some View {
        GeometryReader { geometry in
            generateContent(in: geometry)
        }
        .frame(maxWidth: .infinity, minHeight: 0)
    }

    private func generateContent(in geometry: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero
        let alignment = Alignment(horizontal: self.alignment, vertical: .top)

        return ZStack(alignment: alignment) {
            ForEach(Array(data)) { element in
                content(element)
                    .alignmentGuide(.leading) { dimension in
                        if width + dimension.width > geometry.size.width {
                            width = 0
                            height -= dimension.height + spacing
                        }
                        let result = width
                        width += dimension.width + spacing
                        return result
                    }
                    .alignmentGuide(.top) { dimension in
                        let result = height
                        return result
                    }
            }
        }
    }
}

#Preview {
    let note = NoteModel(
        id: UUID(),
        title: "Design checklist",
        content: """
        • Update color tokens
        • Align typography with design system
        • Prepare launch assets
        """,
        createdAt: Date(),
        updatedAt: Date(),
        isPinned: true,
        folder: FolderModel(id: UUID(), name: "Design", colorHex: "#F472B6", iconName: "paintbrush", isDefault: false, sortOrder: 0),
        tags: [
            TagModel(id: UUID(), name: "UI", colorHex: "#60A5FA"),
            TagModel(id: UUID(), name: "Review", colorHex: "#34D399")
        ]
    )
    NoteCardView(note: note)
        .padding()
        .previewLayout(.sizeThatFits)
}
