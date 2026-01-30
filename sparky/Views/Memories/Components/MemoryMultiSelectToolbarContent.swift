//
//  MemoryMultiSelectToolbarContent.swift
//  sparky
//
//  Created by GPT-5 Codex on 12/11/25.
//

import SwiftUI

struct MemoryMultiSelectToolbarContent: ToolbarContent {
    let availableLobes: [Space]
    let isPerformingBulkAction: Bool
    let canPerformDeletion: Bool
    let isStatusEnabled: Bool
    let isLobeEnabled: Bool
    let onSelectLobe: (Space) -> Void
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
            lobeMenu

            Button(action: onDone) {
                Text("Done")
                    .fontWeight(.semibold)
            }
            .disabled(isPerformingBulkAction)
        }
    }

    private var lobeMenu: some View {
        Menu {
            ForEach(availableLobes, id: \.id) { lobe in
                Button {
                    onSelectLobe(lobe)
                } label: {
                    Label(lobe.name, systemImage: lobe.iconName ?? "folder")
                }
            }
        } label: {
            Label("Lobe", systemImage: "folder")
        }
        .disabled(!isLobeEnabled || isPerformingBulkAction)
        .accessibilityLabel("Move to lobe")
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
