//
//  MemoryMultiSelectToolbarContent.swift
//  sparky
//
//  Created by GPT-5 Codex on 12/11/25.
//

import SwiftUI

struct MemoryMultiSelectToolbarContent: ToolbarContent {
    let availableMinds: [Mind]
    let isPerformingBulkAction: Bool
    let canPerformDeletion: Bool
    let isStatusEnabled: Bool
    let isMindEnabled: Bool
    let onSelectMind: (Mind) -> Void
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
            mindMenu

            Button(action: onDone) {
                Text("Done")
                    .fontWeight(.semibold)
            }
            .disabled(isPerformingBulkAction)
        }
    }

    private var mindMenu: some View {
        Menu {
            ForEach(availableMinds, id: \.id) { mind in
                Button {
                    onSelectMind(mind)
                } label: {
                    Label(mind.name, systemImage: mind.iconName ?? "brain.head.profile")
                }
            }
        } label: {
            Label("Mind", systemImage: "brain.head.profile")
        }
        .disabled(!isMindEnabled || isPerformingBulkAction)
        .accessibilityLabel("Move to mind")
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
