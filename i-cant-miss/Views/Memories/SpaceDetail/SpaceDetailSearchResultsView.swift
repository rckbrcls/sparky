import SwiftUI

struct SpaceDetailSearchResultsView: View {
    let memories: [MemoryModel]
    let isMultiSelecting: Bool
    let isPerformingBulkAction: Bool
    let isMemorySelected: (MemoryModel) -> Bool
    let onSelectMemory: (MemoryModel) -> Void
    let onToggleSelection: (MemoryModel) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if memories.isEmpty {
                MemoryEmptyStateCard(
                    systemImage: "magnifyingglass",
                    title: "No memories match your search",
                    message: "Try different keywords or reset filters to discover more memories."
                )
            } else {
                ForEach(memories) { memory in
                    MemoryListItemButton(
                        memory: memory,
                        isMultiSelecting: isMultiSelecting,
                        isSelected: isMemorySelected(memory),
                        isDisabled: isPerformingBulkAction,
                        onSelect: onSelectMemory,
                        onToggleSelection: onToggleSelection
                    )
                }
            }
        }
    }
}
