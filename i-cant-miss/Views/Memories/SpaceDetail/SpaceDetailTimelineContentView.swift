import SwiftUI

struct SpaceDetailTimelineContentView: View {
    let sections: [MemoryService.TimelineSection]
    let ungroupedMemories: [MemoryModel]
    let emptyStateTitle: String
    let emptyStateMessage: String
    let isMultiSelecting: Bool
    let selectedMemoryIDs: Set<MemoryModel.ID>
    let isPerformingBulkAction: Bool
    @Binding var isOtherExpanded: Bool
    let sectionExpansionProvider: (MemoryService.TimelineSection.Kind) -> Binding<Bool>
    let isMemorySelected: (MemoryModel) -> Bool
    let onSelectMemory: (MemoryModel) -> Void
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
                    otherMemoriesSection
                }
            }
        }
    }

    private var otherMemoriesSection: some View {
        Section {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isOtherExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Label("Other Memories", systemImage: "tray")
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: isOtherExpanded ? "chevron.down" : "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .listRowInsets(.init(top: 24, leading: 20, bottom: isOtherExpanded && !ungroupedMemories.isEmpty ? 0 : 8, trailing: 20))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            if isOtherExpanded {
                ForEach(ungroupedMemories) { memory in
                    MemoryListItemButton(
                        memory: memory,
                        isMultiSelecting: isMultiSelecting,
                        isSelected: isMemorySelected(memory),
                        isDisabled: isPerformingBulkAction,
                        onSelect: onSelectMemory,
                        onToggleSelection: onToggleSelection
                    )
                    .listRowInsets(.init(top: 8, leading: 20, bottom: 8, trailing: 20))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
        }
        .listSectionSeparator(.hidden)
    }
}
