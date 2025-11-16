import SwiftUI

struct SpaceDetailInboxSectionView: View {
    let inboxMemories: [MemoryModel]
    let isMultiSelecting: Bool
    let selectedMemoryIDs: Set<MemoryModel.ID>
    let isPerformingBulkAction: Bool
    @Binding var isInboxExpanded: Bool
    let onSelectMemory: (MemoryModel) -> Void
    let onEditMemory: ((MemoryModel) -> Void)?
    let onToggleSelection: (MemoryModel) -> Void

    var body: some View {
        if inboxMemories.isEmpty {
            EmptyView()
        } else {
            Section {
                headerRow

                if isInboxExpanded {
                    ForEach(inboxMemories) { memory in
                        MemoryListItemButton(
                            memory: memory,
                            isMultiSelecting: isMultiSelecting,
                            isSelected: selectedMemoryIDs.contains(memory.id),
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
            .listSectionSeparator(.hidden)
        }
    }

    private var headerRow: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isInboxExpanded.toggle()
            }
        } label: {
            HStack(spacing: 12) {
                Label("Inbox", systemImage: "tray.fill")
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: isInboxExpanded ? "chevron.down" : "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .listRowInsets(.init(top: 24, leading: 20, bottom: isInboxExpanded && !inboxMemories.isEmpty ? 0 : 8, trailing: 20))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .disabled(inboxMemories.isEmpty)
    }
}
