import SwiftUI

struct MemoryListItemButton: View {
    let memory: Memory
    let isMultiSelecting: Bool
    let isSelected: Bool
    let isDisabled: Bool
    let onSelect: (Memory) -> Void
    let onToggleSelection: ((Memory) -> Void)?
    let onEditMemory: ((Memory) -> Void)?
    /// Optional date context for date-aware completion (used in CalendarDayView)
    var displayDate: Date?
    /// Optional specific occurrence date for intra-day recurring memories (e.g. hourly)
    var occurrenceDate: Date?

    @EnvironmentObject private var environment: AppEnvironment
    @State private var showRecurringCompletionAlert = false
    #if os(macOS)
    @State private var editorRoute: MemoryEditorRoute?
    #endif

    var body: some View {
        listButton
            .memoryListEditorPopover(item: memoryEditorRouteBinding)
    }

    @ViewBuilder
    private var selectionOverlay: some View {
        if isMultiSelecting {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
                .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
    }

    private var listButton: some View {
        Button {
            if isMultiSelecting, let toggleSelection = onToggleSelection {
                toggleSelection(memory)
            } else {
                presentMemory()
            }
        } label: {
            // Pass context menu callbacks only when not in multi-selecting or disabled mode
            if isMultiSelecting || isDisabled {
                MemoryCardView(memoryID: memory.id, memoryService: environment.memoryService, displayDate: displayDate, occurrenceDate: occurrenceDate)
                    .overlay(Color.white.opacity(0.001))
                    .overlay(selectionOverlay)
            } else {
                MemoryCardView(
                    memoryID: memory.id,
                    memoryService: environment.memoryService,
                    displayDate: displayDate,
                    occurrenceDate: occurrenceDate,
                    onTogglePin: { Task { await toggleMemoryPin() } },
                    onToggleCompletion: { Task { await toggleMemoryCompletion() } },
                    onDelete: { Task { await deleteMemory() } },
                    onMoveToMind: { mindID in Task { await moveMemory(to: mindID) } },
                    onUpdateStatus: { status in Task { await setMemoryStatus(status) } },
                    onEdit: onEditMemory != nil ? { presentMemoryForEditing() } : nil
                )
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .alert("End Recurrence?", isPresented: $showRecurringCompletionAlert) {
            Button("Complete", role: .destructive) {
                Task { try? await environment.memoryService.toggleCompletion(memoryID: memory.id) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This memory repeats. Completing it will end the recurrence and remove future triggers.")
        }
    }

    private var memoryEditorRouteBinding: Binding<MemoryEditorRoute?> {
        #if os(macOS)
        $editorRoute
        #else
        .constant(nil)
        #endif
    }

    private func presentMemory() {
        #if os(macOS)
        editorRoute = MemoryEditorRoute(mode: .preview(memory: memory))
        #else
        onSelect(memory)
        #endif
    }

    private func presentMemoryForEditing() {
        #if os(macOS)
        editorRoute = MemoryEditorRoute(
            mode: .edit(memory: memory),
            startEditing: true
        )
        #else
        onEditMemory?(memory)
        #endif
    }

    private func toggleMemoryCompletion() async {
        do {
            // Use exact occurrence time for intra-day recurring memories
            if let date = occurrenceDate, memory.hasIntraDayRecurrence {
                try await environment.memoryService.toggleCompletionForDate(memoryID: memory.id, date: date)
            } else if let date = displayDate, memory.hasRecurringTriggers {
                try await environment.memoryService.toggleCompletionForDate(memoryID: memory.id, date: date)
            } else if displayDate == nil && memory.hasRecurringTriggers && !memory.isCompleted {
                // Show confirmation before globally completing a recurring memory
                showRecurringCompletionAlert = true
            } else {
                try await environment.memoryService.toggleCompletion(memoryID: memory.id)
            }
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

    private func moveMemory(to mindID: UUID?) async {
        let currentID = memory.mind?.id
        guard currentID != mindID else { return }

        do {
            let targetMind = mindID.flatMap { environment.mindService.mind(id: $0) }
            try await environment.memoryService.moveMemory(memory.id, to: targetMind)
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
}

private extension View {
    @ViewBuilder
    func memoryListEditorPopover(
        item: Binding<MemoryEditorRoute?>
    ) -> some View {
        #if os(macOS)
        desktopMemoryEditorPopover(item: item)
        #else
        self
        #endif
    }
}
