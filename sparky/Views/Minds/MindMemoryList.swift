//
//  MindMemoryList.swift
//  sparky
//

import SwiftUI

struct MindMemoryList: View {
    let memories: [Memory]
    let isMultiSelecting: Bool
    let selectedMemoryIDs: Set<Memory.ID>
    let isPerformingBulkAction: Bool
    let onSelectMemory: (Memory) -> Void
    let onEditMemory: ((Memory) -> Void)?
    let onToggleSelection: (Memory) -> Void

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(memories) { memory in
                MemoryListItemButton(
                    memory: memory,
                    isMultiSelecting: isMultiSelecting,
                    isSelected: selectedMemoryIDs.contains(memory.id),
                    isDisabled: isPerformingBulkAction,
                    onSelect: onSelectMemory,
                    onToggleSelection: onToggleSelection,
                    onEditMemory: onEditMemory
                )
                .padding(.vertical, 8)
                .padding(.horizontal, 20)
            }
        }
    }
}
