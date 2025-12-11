//
//  MemoryMultiSelectToolbarContent.swift
//  i-cant-miss
//
//  Created by GPT-5 Codex on 12/11/25.
//

import SwiftUI

struct MemoryMultiSelectToolbarContent: ToolbarContent {
    let availableSpaces: [SpaceModel]
    let isPerformingBulkAction: Bool
    let canPerformDeletion: Bool
    let isStatusEnabled: Bool
    let isSpaceEnabled: Bool
    let onSelectSpace: (SpaceModel) -> Void
    let onSelectStatus: (MemoryStatus) -> Void
    let onDelete: () -> Void
    let onDone: () -> Void

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .disabled(!canPerformDeletion || isPerformingBulkAction)
            .accessibilityLabel("Delete selected memories")

            statusMenu
            spaceMenu

            Button(action: onDone) {
                Text("Done")
                    .fontWeight(.semibold)
            }
            .disabled(isPerformingBulkAction)
        }
    }

    private var spaceMenu: some View {
        Menu {
            ForEach(availableSpaces, id: \.id) { space in
                Button {
                    onSelectSpace(space)
                } label: {
                    Label(space.name, systemImage: space.iconName ?? "folder")
                }
            }
        } label: {
            Label("Space", systemImage: "folder")
        }
        .disabled(!isSpaceEnabled || isPerformingBulkAction)
        .accessibilityLabel("Move to space")
    }

    private var statusMenu: some View {
        Menu {
            ForEach(MemoryStatus.allCases) { status in
                Button {
                    onSelectStatus(status)
                } label: {
                    Label(title(for: status), systemImage: systemImage(for: status))
                }
            }
        } label: {
            Label("Status", systemImage: "circle.circle")
        }
        .disabled(!isStatusEnabled || isPerformingBulkAction)
        .accessibilityLabel("Change status")
    }

    private func title(for status: MemoryStatus) -> String {
        switch status {
        case .active: return "Active"
        case .completed: return "Completed"
        }
    }

    private func systemImage(for status: MemoryStatus) -> String {
        switch status {
        case .active: return "play.circle"
        case .completed: return "checkmark.circle"
        }
    }
}
