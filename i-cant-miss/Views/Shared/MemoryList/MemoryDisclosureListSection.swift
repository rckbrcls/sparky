import SwiftUI

struct MemoryDisclosureListSection: View {
    let title: String
    let systemImage: String
    @Binding var isExpanded: Bool
    let memories: [Memory]
    let isMultiSelecting: Bool
    let selectedMemoryIDs: Set<Memory.ID>
    let isDisabled: Bool
    let onSelect: (Memory) -> Void
    let onEditMemory: ((Memory) -> Void)?
    let onToggleSelection: ((Memory) -> Void)?

    @ViewBuilder
    var body: some View {
        if !memories.isEmpty {
            Section {
                headerRow

                if isExpanded {
                    ForEach(memories) { memory in
                        MemoryListItemButton(
                            memory: memory,
                            isMultiSelecting: isMultiSelecting,
                            isSelected: selectedMemoryIDs.contains(memory.id),
                            isDisabled: isDisabled,
                            onSelect: onSelect,
                            onToggleSelection: onToggleSelection,
                            onEditMemory: onEditMemory,
                        )
                        .listRowInsets(.init(top: 8, leading: 20, bottom: 8, trailing: 20))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }
            }
            .listSectionSeparator(.hidden)
            .background(Color.clear)
        }
    }

    private var headerRow: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 12) {
                Label(title, systemImage: systemImage)
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .listRowInsets(.init(top: 24, leading: 20, bottom: isExpanded && !memories.isEmpty ? 0 : 8, trailing: 20))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .disabled(memories.isEmpty)
    }
}
