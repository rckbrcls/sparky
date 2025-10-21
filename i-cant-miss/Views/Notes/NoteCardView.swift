//
//  NoteCardView.swift
//  i-cant-miss
//
//  Created by Codex on 13/10/25.
//

import SwiftUI

struct NoteCardView: View {
    let note: NoteModel

    private var folderColor: Color {
        guard let hex = note.folder?.colorHex,
              let color = Color(hex: hex) else {
            return .blue
        }
        return color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(note.title?.isEmpty == false ? note.title! : note.content.prefix(40) + "…")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
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
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack {
                if let folder = note.folder {
                    HStack(spacing: 4) {
                        Image(systemName: folder.iconName ?? "folder.fill")
                        Text(folder.name)
                    }
                    .font(.caption.weight(.medium))
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(.thinMaterial, in: Capsule())
                    .foregroundStyle(folderColor)
                }

                Spacer()

                Label(note.updatedAt.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
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

#Preview(traits: .sizeThatFitsLayout) {
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
        folder: FolderModel(
            id: UUID(),
            name: "Design",
            colorHex: "#F472B6",
            iconName: "paintbrush",
            audience: .notes,
            isDefault: false,
            sortOrder: 0
        ),
        tags: [
            TagModel(id: UUID(), name: "UI", colorHex: "#60A5FA"),
            TagModel(id: UUID(), name: "Review", colorHex: "#34D399")
        ]
    )
    NoteCardView(note: note)
        .padding()
}
