import SwiftUI

struct SpaceDetailInboxSectionView: View {
    let inboxMemories: [MemoryModel]
    let isMultiSelecting: Bool
    let selectedMemoryIDs: Set<MemoryModel.ID>
    let isPerformingBulkAction: Bool
    @Binding var isInboxExpanded: Bool
    let onSelectMemory: (MemoryModel) -> Void
    let onToggleSelection: (MemoryModel) -> Void

    var body: some View {
        Group {
            if inboxMemories.isEmpty {
                EmptyView()
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    DisclosureGroup(isExpanded: $isInboxExpanded) {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(inboxMemories) { memory in
                                MemoryListItemButton(
                                    memory: memory,
                                    isMultiSelecting: isMultiSelecting,
                                    isSelected: selectedMemoryIDs.contains(memory.id),
                                    isDisabled: isPerformingBulkAction,
                                    onSelect: onSelectMemory,
                                    onToggleSelection: onToggleSelection
                                )
                            }
                        }
                        .padding(.top)
                    } label: {
                        Label("Inbox", systemImage: "tray.fill")
                            .foregroundStyle(.white)
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isInboxExpanded)
                }
            }
        }
    }
}
