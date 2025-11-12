import SwiftUI

struct SpaceDetailSearchResultsView: View {
    let memories: [MemoryModel]
    let isMultiSelecting: Bool
    let isPerformingBulkAction: Bool
    let isMemorySelected: (MemoryModel) -> Bool
    let onSelectMemory: (MemoryModel) -> Void
    let onToggleSelection: (MemoryModel) -> Void

    var body: some View {
        if memories.isEmpty {
            MemoryEmptyStateCard(
                systemImage: "magnifyingglass",
                title: "No memories match your search",
                message: "Try different keywords or reset filters to discover more memories."
            )
            .padding(.top, 16)
            .listRowInsets(.init(top: 24, leading: 20, bottom: 24, trailing: 20))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
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
                .listRowInsets(.init(top: 6, leading: 20, bottom: 6, trailing: 20))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
    }
}
