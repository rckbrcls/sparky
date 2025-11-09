import SwiftUI

struct MemoryListItemButton: View {
    let memory: MemoryModel
    let isMultiSelecting: Bool
    let isSelected: Bool
    let isDisabled: Bool
    let onSelect: (MemoryModel) -> Void
    let onToggleSelection: ((MemoryModel) -> Void)?

    var body: some View {
        Button {
            if isMultiSelecting, let toggleSelection = onToggleSelection {
                toggleSelection(memory)
            } else {
                onSelect(memory)
            }
        } label: {
            MemoryCardView(memory: memory)
                .overlay(selectionOverlay)
                .overlay(alignment: .topTrailing) {
                    selectionBadge
                }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }

    @ViewBuilder
    private var selectionOverlay: some View {
        if isMultiSelecting {
            ZStack {
                if !isSelected {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.black.opacity(0.05))
                }
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(isSelected ? Color.accent : Color.secondary.opacity(0.3), lineWidth: isSelected ? 3 : 1)
                    .animation(.easeInOut(duration: 0.2), value: isSelected)
            }
        }
    }

    @ViewBuilder
    private var selectionBadge: some View {
        if isMultiSelecting {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title2.weight(.medium))
                .foregroundStyle(isSelected ? Color.accent : Color.secondary)
                .padding(16)
                .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
    }
}

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

struct MemoryEmptyStateCard: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.top, 8)
        .glassEffect(in: .rect(cornerRadius: 16.0))
    }
}
