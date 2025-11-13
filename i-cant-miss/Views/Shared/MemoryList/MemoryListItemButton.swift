import SwiftUI

struct MemoryListItemButton: View {
    let memory: MemoryModel
    let isMultiSelecting: Bool
    let isSelected: Bool
    let isDisabled: Bool
    let onSelect: (MemoryModel) -> Void
    let onToggleSelection: ((MemoryModel) -> Void)?

    @EnvironmentObject private var environment: AppEnvironment

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
    private func trailingSwipeActions() -> some View {
        switch memory.metadata.origin {
        case .reminder(let id):
            Button {
                Task { await toggleReminderCompletion(id: id) }
            } label: {
                Label(memory.status == .completed ? "Mark Active" : "Mark Completed",
                      systemImage: memory.status == .completed ? "arrow.uturn.backward.circle" : "checkmark.circle")
            }
            .tint(.green)

            Button(role: .destructive) {
                Task { await deleteReminder(id: id) }
            } label: {
                Label("Delete", systemImage: "trash")
            }

        case .note(let id):
            Button {
                Task { await toggleNotePin(id: id) }
            } label: {
                Label(memory.isPinned ? "Unpin" : "Pin", systemImage: "pin")
            }
            .tint(.yellow)

            Button(role: .destructive) {
                Task { await deleteNote(id: id) }
            } label: {
                Label("Delete", systemImage: "trash")
            }

        case .todoList(let id):
            Button {
                Task { await toggleTodoPin(id: id) }
            } label: {
                Label(memory.isPinned ? "Unpin" : "Pin", systemImage: "pin")
            }
            .tint(.yellow)

            Button(role: .destructive) {
                Task { await deleteTodoList(id: id) }
            } label: {
                Label("Delete", systemImage: "trash")
            }

        case .none:
            EmptyView()
        }
    }

    @ViewBuilder
    private func leadingSwipeActions() -> some View {
        if case .reminder(let id) = memory.metadata.origin {
            Button {
                Task { await snoozeReminder(id: id, by: 15 * 60) }
            } label: {
                Label("Snooze 15 min", systemImage: "zzz")
            }
            .tint(.orange)

            Button {
                Task { await snoozeReminder(id: id, by: 60 * 60) }
            } label: {
                Label("Snooze 1 hour", systemImage: "zzz")
            }
            .tint(.orange)
        } else {
            EmptyView()
        }
    }

    private func refreshAll() async {
        _ = await environment.memoryService.refresh(force: true)
    }

    private func toggleReminderCompletion(id: UUID) async {
        do {
            if memory.status == .completed {
                _ = try await environment.reminderService.restoreReminder(id: id)
            } else {
                _ = try await environment.reminderService.completeReminder(id: id)
            }
            await refreshAll()
        } catch {
            // Handle error silently for now
        }
    }

    private func snoozeReminder(id: UUID, by interval: TimeInterval) async {
        do {
            _ = try await environment.reminderService.snoozeReminder(id: id, by: interval)
            await refreshAll()
        } catch {
            // Handle error silently for now
        }
    }

    private func deleteReminder(id: UUID) async {
        do {
            try await environment.reminderService.deleteReminder(id: id)
            await refreshAll()
        } catch {
            // Handle error silently for now
        }
    }

    private func toggleNotePin(id: UUID) async {
        do {
            _ = try await environment.noteService.togglePin(noteID: id)
            await refreshAll()
        } catch {
            // Handle error silently for now
        }
    }

    private func deleteNote(id: UUID) async {
        do {
            try await environment.noteService.deleteNote(id: id)
            await refreshAll()
        } catch {
            // Handle error silently for now
        }
    }

    private func toggleTodoPin(id: UUID) async {
        do {
            _ = try await environment.todoService.togglePin(listID: id)
            await refreshAll()
        } catch {
            // Handle error silently for now
        }
    }

    private func deleteTodoList(id: UUID) async {
        do {
            try await environment.todoService.deleteList(id: id)
            await refreshAll()
        } catch {
            // Handle error silently for now
        }
    }
}
