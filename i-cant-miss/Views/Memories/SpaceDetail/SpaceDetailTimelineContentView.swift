import SwiftUI

struct SpaceDetailTimelineContentView: View {
    let sections: [MemoryService.TimelineSection]
    let ungroupedMemories: [MemoryModel]
    let emptyStateTitle: String
    let emptyStateMessage: String
    let isMultiSelecting: Bool
    let selectedMemoryIDs: Set<MemoryModel.ID>
    let isPerformingBulkAction: Bool
    @Binding var isUpcomingExpanded: Bool
    @Binding var isOtherExpanded: Bool
    let sectionExpansionProvider: (MemoryService.TimelineSection.Kind) -> Binding<Bool>
    let isMemorySelected: (MemoryModel) -> Bool
    let onSelectMemory: (MemoryModel) -> Void
    let onToggleSelection: (MemoryModel) -> Void
    let shouldShowEmptyState: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if shouldShowEmptyState {
                VStack(alignment: .leading, spacing: 8) {
                    MemoryEmptyStateCard(
                        systemImage: "tray",
                        title: emptyStateTitle,
                        message: emptyStateMessage
                    )
                    .padding(.top)
                }
                .padding(.top)
            } else {
                ForEach(sections) { section in
                    MemoryDisclosureListSection(
                        title: section.kind.title,
                        systemImage: section.kind.systemImage,
                        isExpanded: sectionExpansionProvider(section.kind),
                        memories: section.memories,
                        isMultiSelecting: isMultiSelecting,
                        selectedMemoryIDs: selectedMemoryIDs,
                        isDisabled: isPerformingBulkAction,
                        onSelect: onSelectMemory,
                        onToggleSelection: onToggleSelection
                    )
                }

                if !ungroupedMemories.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        DisclosureGroup(isExpanded: $isOtherExpanded) {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(ungroupedMemories) { memory in
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
                            .padding(.top)
                        } label: {
                            Label("Other Memories", systemImage: "tray")
                                .foregroundStyle(.white)
                        }
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isOtherExpanded)
                    }
                    .padding(.top)
                }
            }
        }
    }
}
