import SwiftUI

struct MemoryListItemButton: View {
    let memory: MemoryModel
    let isMultiSelecting: Bool
    let isSelected: Bool
    let isDisabled: Bool
    let onSelect: (MemoryModel) -> Void
    let onToggleSelection: ((MemoryModel) -> Void)?
    let onEdit: ((MemoryModel) -> Void)?

    @EnvironmentObject private var environment: AppEnvironment
    @State private var isShowingMoreActions = false

    var body: some View {
        if isMultiSelecting || isDisabled {
            listButton
        } else {
            listButton
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    trailingSwipeActions()
                }
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    leadingSwipeActions()
                }
                .sheet(isPresented: $isShowingMoreActions) {
                    MemoryListMoreActionsSheet(
                        canEdit: onEdit != nil,
                        onEdit: {
                            guard let onEdit else { return }
                            isShowingMoreActions = false
                            onEdit(memory)
                        },
                        onDelete: {
                            isShowingMoreActions = false
                            Task { await deleteMemory() }
                        }
                    )
                    .presentationDetents([.height(200)])
                }
        }
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

    private var listButton: some View {
        Button {
            if isMultiSelecting, let toggleSelection = onToggleSelection {
                toggleSelection(memory)
            } else {
                onSelect(memory)
            }
        } label: {
            MemoryCardView(memoryID: memory.id, memoryService: environment.memoryService)
                .overlay(selectionOverlay)
                .overlay(alignment: .topTrailing) {
                    selectionBadge
                }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }

    @ViewBuilder
    private func trailingSwipeActions() -> some View {
        // Completed action first (for fullSwipe)
        Button {
            Task { await toggleMemoryCompletion() }
        } label: {
            Label(memory.status == .completed ? "Mark Active" : "Mark Completed",
                  systemImage: memory.status == .completed ? "arrow.uturn.backward.circle" : "checkmark.circle")
        }
        .tint(.green)

        Button {
            isShowingMoreActions = true
        } label: {
            Label("More", systemImage: "ellipsis")
        }
        .tint(.gray)
    }

    @ViewBuilder
    private func leadingSwipeActions() -> some View {
        Button {
            Task { await toggleMemoryPin() }
        } label: {
            Label(memory.isPinned ? "Unpin" : "Pin",
                  systemImage: memory.isPinned ? "pin.fill" : "pin")
        }
        .tint(.yellow)
    }

    private func toggleMemoryCompletion() async {
        do {
            try await environment.memoryService.toggleCompletion(memoryID: memory.id)
        } catch {
            // Handle error silently for now
        }
    }

    private func toggleMemoryPin() async {
        do {
            try await environment.memoryService.togglePin(memoryID: memory.id)
        } catch {
            // Handle error silently for now
        }
    }

    private func deleteMemory() async {
        do {
            try await environment.memoryService.deleteMemory(id: memory.id)
        } catch {
            // Handle error silently for now
        }
    }
}
