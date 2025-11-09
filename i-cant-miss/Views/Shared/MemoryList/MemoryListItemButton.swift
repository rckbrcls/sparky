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


