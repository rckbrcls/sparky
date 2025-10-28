//
//  SpaceRowView.swift
//  i-cant-miss
//
//  Created by Codex on 09/03/24.
//

import SwiftUI

struct SpaceRowView: View {
    let space: SpaceModel
    let count: Int

    var body: some View {
        HStack(spacing: 12) {
            
            Image(systemName: space.iconName ?? "square.grid.2x2")
                .foregroundStyle(spaceColor)
                .frame(width: 36, height: 36)
                .glassEffect(.regular.tint(spaceColor.opacity(0.15)))

            VStack(alignment: .leading, spacing: 2) {
                Text(space.name)
                    .font(.headline)
                    .foregroundStyle(.primary)

                if let parentID = space.parentID,
                   let parent = parentLookup?(parentID) {
                    Text(parent.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text("\(count)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    /// Optional closure used to render breadcrumb context while the hierarchy is still evolving.
    var parentLookup: ((UUID) -> SpaceModel?)?

    private var spaceColor: Color {
        if let hex = space.colorHex, let color = Color(hex: hex) {
            return color
        }
        return .accentColor
    }
}

#Preview {
    SpaceRowView(
        space: SpaceModel(id: UUID(), name: "Inbox"),
        count: 12
    )
}
