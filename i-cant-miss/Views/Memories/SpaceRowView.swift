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
    let completedCount: Int
    let spaceService: SpaceService?
    let memoryService: MemoryService?

    @State private var showingDeleteConfirmation = false

    init(
        space: SpaceModel,
        count: Int,
        completedCount: Int = 0,
        spaceService: SpaceService? = nil,
        memoryService: MemoryService? = nil,
        onEdit: ((SpaceModel) -> Void)? = nil
    ) {
        self.space = space
        self.count = count
        self.completedCount = completedCount
        self.spaceService = spaceService
        self.memoryService = memoryService
        self.onEdit = onEdit
    }

    var body: some View {
        HStack(spacing: 12) {

            Image(systemName: space.iconName ?? "square.grid.2x2")
                .foregroundStyle(spaceColor)
                .frame(width: 32, height: 32)
                .glassEffect(.regular.tint(spaceColor.opacity(0.15)))

            VStack(alignment: .leading, spacing: 2) {
                Text(space.name)
                .font(.headline)
                .foregroundStyle(.primary)
            }

            Spacer()

            Text("\(completedCount) / \(count)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .cardStyle()
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if canDeleteSpace {
                Button {
                    Task { @MainActor in
                        showingDeleteConfirmation = true
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .tint(.red)
            }

            if canEditSpace {
                Button {
                    onEdit?(space)
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .tint(.blue)
            }
        }
        .alert("Delete Space", isPresented: $showingDeleteConfirmation) {
            Button("Delete Space Only", role: .destructive) {
                deleteSpace(deleteMemories: false)
            }
            if count > 0 {
                Button("Delete Space and Memories", role: .destructive) {
                    deleteSpace(deleteMemories: true)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if count > 0 {
                Text("This space contains \(count) memory\(count == 1 ? "" : "ies"). Do you want to delete the space only (memories will be moved to \"No Space\") or delete the space and all its memories?")
            } else {
                Text("Are you sure you want to delete this space?")
            }
        }
    }

    /// Optional closure called when user taps edit swipe action
    var onEdit: ((SpaceModel) -> Void)?

    private var spaceColor: Color {
        if let hex = space.colorHex, let color = Color(hex: hex) {
            return color
        }
        return .gray
    }

    private var canEditSpace: Bool {
        guard !space.isAllSpaces else { return false }
        return true
    }

    private var canDeleteSpace: Bool {
        guard spaceService != nil else { return false }
        guard !space.isAllSpaces else { return false }
        return !space.isDefault
    }

    private func deleteSpace(deleteMemories: Bool) {
        guard let service = spaceService else { return }
        guard !space.isAllSpaces,
              !space.isDefault else { return }

        Task { @MainActor in
            do {
                try await service.deleteSpace(space, deleteMemories: deleteMemories, memoryService: memoryService)
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
