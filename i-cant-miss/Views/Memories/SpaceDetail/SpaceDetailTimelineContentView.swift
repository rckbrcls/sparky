import SwiftUI

struct SpaceDetailTimelineContentView: View {
    let memories: [MemoryModel]
    let pinnedMemories: [MemoryModel]
    let emptyStateTitle: String
    let emptyStateMessage: String
    let isMultiSelecting: Bool
    let selectedMemoryIDs: Set<MemoryModel.ID>
    let isPerformingBulkAction: Bool
    @Binding var isPinnedExpanded: Bool
    let isMemorySelected: (MemoryModel) -> Bool
    let onSelectMemory: (MemoryModel) -> Void
    let onEditMemory: ((MemoryModel) -> Void)?
    let onToggleSelection: (MemoryModel) -> Void
    let shouldShowEmptyState: Bool

    var body: some View {
        Group {
            if shouldShowEmptyState {
                MemoryEmptyStateCard(
                    systemImage: "tray",
                    title: emptyStateTitle,
                    message: emptyStateMessage
                )
                .padding(.top, 16)
                .listRowInsets(.init(top: 24, leading: 20, bottom: 24, trailing: 20))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                if !pinnedMemories.isEmpty {
                    pinnedMemoriesSection
                }

                if !memories.isEmpty {
                    otherMemoriesSection
                }
            }
        }
    }

    @ViewBuilder
    private var pinnedMemoriesSection: some View {
        MemoryDisclosureListSection(
            title: "Pinned Memories",
            systemImage: "pin.fill",
            isExpanded: $isPinnedExpanded,
            memories: pinnedMemories,
            isMultiSelecting: isMultiSelecting,
            selectedMemoryIDs: selectedMemoryIDs,
            isDisabled: isPerformingBulkAction,
            onSelect: onSelectMemory,
            onEdit: onEditMemory,
            onToggleSelection: onToggleSelection
        )
    }

    private var otherMemoriesSection: some View {
        ForEach(memories) { memory in
            MemoryListItemButton(
                memory: memory,
                isMultiSelecting: isMultiSelecting,
                isSelected: isMemorySelected(memory),
                isDisabled: isPerformingBulkAction,
                onSelect: onSelectMemory,
                onToggleSelection: onToggleSelection,
                onEdit: onEditMemory
            )
            .listRowInsets(.init(top: 8, leading: 20, bottom: 8, trailing: 20))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }
}
