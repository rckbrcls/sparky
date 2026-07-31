//
//  MindPinnedSection.swift
//  sparky
//

import SwiftUI

struct MindPinnedSection: View {
    let memories: [Memory]
    let isMultiSelecting: Bool
    let selectedMemoryIDs: Set<Memory.ID>
    let isPerformingBulkAction: Bool
    let onSelectMemory: (Memory) -> Void
    let onEditMemory: ((Memory) -> Void)?
    let onToggleSelection: (Memory) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "pin.fill")
                    .accessibilityHidden(true)

                Text("Pinned")
                    .fontWeight(.medium)

                Text("\(memories.count)")
                    .monospacedDigit()
            }
            .font(.caption)
            .foregroundStyle(Color.Theme.textSecondary)
            .accessibilityElement(children: .combine)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 16)
            .padding(.bottom, 4)
            .padding(.horizontal, 20)

            MindMemoryList(
                memories: memories,
                isMultiSelecting: isMultiSelecting,
                selectedMemoryIDs: selectedMemoryIDs,
                isPerformingBulkAction: isPerformingBulkAction,
                onSelectMemory: onSelectMemory,
                onEditMemory: onEditMemory,
                onToggleSelection: onToggleSelection
            )
        }
    }
}
