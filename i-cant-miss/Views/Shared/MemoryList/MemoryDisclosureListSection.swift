import SwiftUI

struct MemoryDisclosureListSection: View {
    let title: String
    let systemImage: String
    @Binding var isExpanded: Bool
    let memories: [MemoryModel]
    let isMultiSelecting: Bool
    let selectedMemoryIDs: Set<MemoryModel.ID>
    let isDisabled: Bool
    let onSelect: (MemoryModel) -> Void
    let onToggleSelection: ((MemoryModel) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(memories) { memory in
                        MemoryListItemButton(
                            memory: memory,
                            isMultiSelecting: isMultiSelecting,
                            isSelected: selectedMemoryIDs.contains(memory.id),
                            isDisabled: isDisabled,
                            onSelect: onSelect,
                            onToggleSelection: onToggleSelection
                        )
                    }
                }
                .padding(.top)
            } label: {
                Label(title, systemImage: systemImage)
                    .foregroundStyle(.white)
            }
        }
        .padding(.top)
    }
}


