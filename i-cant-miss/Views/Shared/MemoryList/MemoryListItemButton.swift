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
        listButton
            .sheet(isPresented: $isShowingMoreActions) {
                MemoryListMoreActionsSheet(
                    memory: memory,
                    spaces: environment.spaceService.spaces,
                    canEdit: onEdit != nil,
                    onEdit: {
                        guard let onEdit else { return }
                        isShowingMoreActions = false
                        onEdit(memory)
                    },
                    onDelete: {
                        isShowingMoreActions = false
                        Task { await deleteMemory() }
                    },
                    onTogglePin: {
                        Task { await toggleMemoryPin() }
                    },
                    onMoveToSpace: { spaceID in
                        Task { await moveMemory(to: spaceID) }
                    },
                    onUpdateStatus: { status in
                        Task { await setMemoryStatus(status) }
                    },
                    onUpdatePriority: { priority in
                        Task { await setMemoryPriority(priority) }
                    }
                )
                .presentationDetents([.medium])
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
            // Pass context menu callbacks only when not in multi-selecting or disabled mode
            if isMultiSelecting || isDisabled {
                MemoryCardView(memoryID: memory.id, memoryService: environment.memoryService)
                    .overlay(selectionOverlay)
                    .overlay(alignment: .topTrailing) {
                        selectionBadge
                    }
            } else {
                MemoryCardView(
                    memoryID: memory.id,
                    memoryService: environment.memoryService,
                    onTogglePin: { Task { await toggleMemoryPin() } },
                    onToggleCompletion: { Task { await toggleMemoryCompletion() } },
                    onDelete: { Task { await deleteMemory() } },
                    onEdit: onEdit != nil ? { onEdit?(memory) } : nil,
                    onShowMoreActions: { isShowingMoreActions = true }
                )
                .overlay(selectionOverlay)
                .overlay(alignment: .topTrailing) {
                    selectionBadge
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
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

    private func moveMemory(to spaceID: UUID?) async {
        let currentID = memory.space?.id
        guard currentID != spaceID else { return }

        do {
            let targetSpace = spaceID.flatMap { environment.spaceService.space(id: $0) }
            try await environment.memoryService.moveMemory(memory.id, to: targetSpace)
        } catch {
            // Handle error silently for now
        }
    }

    private func setMemoryStatus(_ status: MemoryStatus) async {
        guard status != memory.status else { return }
        do {
            try await environment.memoryService.setStatus(memoryID: memory.id, status: status)
        } catch {
            // Handle error silently for now
        }
    }

    private func setMemoryPriority(_ priority: MemoryPriority?) async {
        if priority == nil, memory.priority == nil {
            return
        }
        if let current = memory.priority, let priority, current == priority {
            return
        }
        do {
            try await environment.memoryService.setPriority(memoryID: memory.id, priority: priority)
        } catch {
            // Handle error silently for now
        }
    }
}
