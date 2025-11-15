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
    let spaceService: SpaceService?

    init(
        space: SpaceModel,
        count: Int,
        spaceService: SpaceService? = nil,
        parentLookup: ((UUID) -> SpaceModel?)? = nil
    ) {
        self.space = space
        self.count = count
        self.spaceService = spaceService
        self.parentLookup = parentLookup
    }

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
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if canDeleteSpace {
                Button(role: .destructive) {
                    deleteSpace()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    /// Optional closure used to render breadcrumb context while the hierarchy is still evolving.
    var parentLookup: ((UUID) -> SpaceModel?)?

    private var spaceColor: Color {
        if let hex = space.colorHex, let color = Color(hex: hex) {
            return color
        }
        return .accentColor
    }

    private var canDeleteSpace: Bool {
        guard spaceService != nil else { return false }
        guard !space.isAllSpaces else { return false }
        return !space.isDefault
    }

    private func deleteSpace() {
        guard let service = spaceService else { return }
        guard !space.isAllSpaces,
              !space.isDefault else { return }

        Task { @MainActor in
            do {
                try await service.deleteSpace(space)
            } catch {
                assertionFailure("Failed to delete space: \(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    SpaceRowView(
        space: SpaceModel(id: UUID(), name: "Inbox"),
        count: 12
    )
}
