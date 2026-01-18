//
//  SpaceGridItemView.swift
//  i-cant-miss
//
//  Created by Codex on 09/03/24.
//

import SwiftUI

struct SpaceGridItemView: View {
    let space: SpaceModel
    let count: Int
    let completedCount: Int
    let spaceService: SpaceService?
    let memoryService: MemoryService?
    let mindService: MindService?
    let showOnlyRemaining: Bool

    @State private var showingDeleteConfirmation = false

    init(
        space: SpaceModel,
        count: Int,
        completedCount: Int = 0,
        spaceService: SpaceService? = nil,
        memoryService: MemoryService? = nil,
        mindService: MindService? = nil,
        onEdit: ((SpaceModel) -> Void)? = nil,
        showOnlyRemaining: Bool = false
    ) {
        self.space = space
        self.count = count
        self.completedCount = completedCount
        self.spaceService = spaceService
        self.memoryService = memoryService
        self.mindService = mindService
        self.onEdit = onEdit
        self.showOnlyRemaining = showOnlyRemaining
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let mind = space.mind {
                HStack(spacing: 4) {
                    Image(systemName: mind.iconName ?? "brain.head.profile")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(mind.name)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            HStack {
                Image(systemName: space.iconName ?? "square.grid.2x2")
                    .foregroundStyle(spaceColor)
                    .frame(width: 32, height: 32)
                    .glassEffect(.regular.tint(spaceColor.opacity(0.15)))

                Spacer()

                Text(displayCount)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            
            Text(space.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .lineLimit(2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 60)
        .cardStyle()
        .contextMenu {
            if canEditSpace {
                Button {
                    onEdit?(space)
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }

            if let mindService = mindService, canEditSpace {
                Menu {
                    Button {
                        moveToMind(nil)
                    } label: {
                        HStack {
                            Image(systemName: "brain.head.profile")
                            Text("No Mind")
                            Spacer()
                            if space.mind == nil {
                                Image(systemName: "checkmark")
                            }
                        }
                    }

                    ForEach(mindService.minds.filter { !$0.isDefault }, id: \.id) { mind in
                        Button {
                            moveToMind(mind)
                        } label: {
                            HStack {
                                Image(systemName: mind.iconName ?? "brain.head.profile")
                                Text(mind.name)
                                Spacer()
                                if space.mind?.id == mind.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Label(currentMindLabel, systemImage: "brain.head.profile")
                }
            }

            if canDeleteSpace {
                Button(role: .destructive) {
                    Task { @MainActor in
                        showingDeleteConfirmation = true
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
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

    private var currentMindLabel: String {
        if let mind = space.mind {
            return mind.name
        } else {
            return "None"
        }
    }

    private var displayCount: String {
        if showOnlyRemaining {
            let remaining = count - completedCount
            return "\(remaining)"
        } else {
            return "\(completedCount)/\(count)"
        }
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

    private func moveToMind(_ mind: MindModel?) {
        guard let service = spaceService else { return }
        guard !space.isAllSpaces else { return }

        Task { @MainActor in
            do {
                var updatedSpace = space
                updatedSpace.mind = mind
                _ = try await service.updateSpace(updatedSpace)
                _ = await service.refresh(force: true)
            } catch {
                assertionFailure("Failed to move space to mind: \(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    HStack {
        SpaceGridItemView(
            space: SpaceModel(id: UUID(), name: "Inbox"),
            count: 12
        )
        SpaceGridItemView(
            space: SpaceModel(id: UUID(), name: "Work"),
            count: 5,
            completedCount: 2
        )
    }
    .padding()
}
