//
//  SequentialTriggerEditorScreen.swift
//  i-cant-miss
//
//  Created by Codex on 13/10/25.
//

import SwiftUI

struct SequentialTriggerEditorScreen: View {
    @ObservedObject var viewModel: MemoryEditorViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var sequenceItems: [SequentialItem] = []
    @State private var showingPicker = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if sequenceItems.isEmpty {
                        Text("No memories in sequence")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(sequenceItems) { item in
                            HStack {
                                Text("\(sequenceItems.firstIndex(of: item)! + 1)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 24)

                                VStack(alignment: .leading) {
                                    if item.isCurrent {
                                        Text("Current Memory")
                                            .font(.caption)
                                            .foregroundStyle(.blue)
                                    }
                                    Text(item.title)
                                        .font(.headline)
                                }
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .onMove { from, to in
                            sequenceItems.move(fromOffsets: from, toOffset: to)
                        }
                        .onDelete { indexSet in
                            // Prevent deleting "current" memory if desired, or allow removing it from sequence?
                            // For now, let's allow removing others.
                            // If user removes "current", it effectively clears the trigger for current.
                            // But usually we just remove the triggers for others.
                            // Let's block removing current for simplicity, or handle it as "Cancel Sequence"

                            // Check if current is in indexSet
                            let containsCurrent = indexSet.map { sequenceItems[$0] }.contains { $0.isCurrent }
                            if containsCurrent {
                                // Can't delete self from list in this view? Or maybe just allow it?
                                // If deleted, we remove from list.
                            }
                            sequenceItems.remove(atOffsets: indexSet)
                        }
                    }
                } header: {
                    Text("Sequence Order")
                } footer: {
                    Text("Drag to reorder. The sequence will advance in this order.")
                }

                Section {
                    Button {
                        showingPicker = true
                    } label: {
                        Label("Add Memory", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("Sequential Trigger")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        Task {
                            await save()
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
            .sheet(isPresented: $showingPicker) {
                SequentialMemoryPickerSheet(
                    viewModel: viewModel,
                    excludedMemoryIDs: Set(sequenceItems.map(\.id)),
                    onSelect: { memory in
                        let item = SequentialItem(id: memory.id, title: memory.title, isCurrent: false)
                        sequenceItems.append(item)
                    }
                )
            }
            .onAppear {
                loadExistingConfiguration()
            }
        }
    }

    private struct SequentialItem: Identifiable, Equatable {
        let id: UUID
        let title: String
        var isCurrent: Bool
    }

    private func loadExistingConfiguration() {
        var items: [SequentialItem] = []

        // 1. Current Memory
        let currentID = viewModel.editingMemoryID ?? UUID() // Use temp ID if new?
        // Ideally we assume current memory is ALWAYS part of it if we are editing.
        // If we have a sequenceID, fetch others.

        if let seqInfo = viewModel.sequentialTrigger?.sequential {
            let sequenceID = seqInfo.sequenceID

            // Fetch all memories with this sequenceID
            let allMemories = viewModel.environment.memoryService.memories.filter { memory in
                // Active memories only? Or include completed? Sequence might include completed ones.
                // Include all status for editing visibility.
                memory.triggers.contains { t in
                    t.type == .sequential && t.sequential?.sequenceID == sequenceID
                }
            }

            // Map to items
            items = allMemories.map { mem in
                SequentialItem(id: mem.id, title: mem.title, isCurrent: mem.id == viewModel.editingMemoryID)
            }

            // Sort by stepIndex
            items.sort { lhs, rhs in
                let lhsIndex = allMemories.first(where: { $0.id == lhs.id })?.triggers.first(where: { $0.type == .sequential })?.sequential?.stepIndex ?? 0
                let rhsIndex = allMemories.first(where: { $0.id == rhs.id })?.triggers.first(where: { $0.type == .sequential })?.sequential?.stepIndex ?? 0
                return lhsIndex < rhsIndex
            }
        }

        // Ensure current is in list if not found (new sequence or new memory)
        if !items.contains(where: { $0.isCurrent }) {
            // Note: If `viewModel.editingMemoryID` is different from persisted (new memory), we use title from VM
            let title = viewModel.title.isEmpty ? "New Memory" : viewModel.title
            let current = SequentialItem(id: currentID, title: title, isCurrent: true)
            items.append(current)
        }

        self.sequenceItems = items
    }

    private func save() async {
        // 1. Generate new Sequence ID if needed
        // If we already have one, keep it? Or generate new one to be safe/clean?
        // If we keep it, we don't break links to memories NOT in the list (if any exist that were not fetched?)
        // But we fetched all.
        let sequenceID = viewModel.sequentialTrigger?.sequential?.sequenceID ?? UUID()

        // 2. Iterate items and update
        for (index, item) in sequenceItems.enumerated() {
            if item.isCurrent {
                // Update VM
                viewModel.updateSequentialTrigger(sequenceID: sequenceID, stepIndex: index)
            } else {
                // Update other memory
                if let memory = viewModel.environment.memoryService.memory(id: item.id) {
                    await updateMemoryTrigger(memory, sequenceID: sequenceID, index: index)
                }
            }
        }

        // 3. Handle removed items?
        // If an item was in the sequence but removed from list, we should remove its sequential trigger.
        // We can find them by querying the service for correct sequenceID but not in our list.
        let service = viewModel.environment.memoryService
        let staleMemories = service.memories.filter { mem in
            mem.triggers.contains { $0.type == .sequential && $0.sequential?.sequenceID == sequenceID } &&
            !sequenceItems.contains { $0.id == mem.id }
        }

        for mem in staleMemories {
             await removeSequentialTrigger(from: mem)
        }
    }

    private func updateMemoryTrigger(_ memory: MemoryModel, sequenceID: UUID, index: Int) async {
        // Create Draft
        // Existing trigger?
        var triggers = memory.triggers

        let newSeq = MemoryTriggerModel.TriggerSequential(sequenceID: sequenceID, stepIndex: index)

        if let idx = triggers.firstIndex(where: { $0.type == .sequential }) {
             triggers[idx].sequential = newSeq
        } else {
            let t = MemoryTriggerModel(
                id: UUID(),
                type: .sequential,
                weekdayMask: 0,
                isActive: true, // Should be active?
                sequential: newSeq,
                spacedStage: 0,
                ignoreCount: 0
            )
            triggers.append(t)
        }

        // Create minimal draft/update
        // Simplest way is to use MemoryService.updateMemory but we need a full draft.
        // We can replicate changes.
        // Or simpler: MemoryService expose a way to update triggers directly?
        // `MemoryService.mutateMemory` is internal/private helper but we have `updateMemory(from: draft)`.

        // Construct draft
        // Need to convert ALL fields? That's heavy.
        // Let's see if we can use a lighter update or just do the draft.
        // MemoryService has `toggleCompletion` using `mutateMemory`.
        // Maybe we just create a full draft.

        let draft = MemoryDraft.from(model: memory, withTriggers: triggers)
        try? await viewModel.environment.memoryService.updateMemory(from: draft)
    }

    private func removeSequentialTrigger(from memory: MemoryModel) async {
        var triggers = memory.triggers
        triggers.removeAll { $0.type == .sequential }
        let draft = MemoryDraft.from(model: memory, withTriggers: triggers)
        try? await viewModel.environment.memoryService.updateMemory(from: draft)
    }
}

// Helper extension to create Draft from Model easily (if not exists)
// It seems `MemoryDraft` has an init but not a "from model" static manually.
// VM has `draft(from:)`.
// Let's add a helper extension here locally or rely on VM-like mapping.
fileprivate extension MemoryDraft {
    static func from(model: MemoryModel, withTriggers triggers: [MemoryTriggerModel]) -> MemoryDraft {
        MemoryDraft(
            id: model.id,
            title: model.title,
            status: model.status,
            isPinned: model.isPinned,
            dueDate: model.dueDate,
            spaceID: model.space?.id,
            triggers: triggers, // Updated triggers
            note: model.note,
            checkItems: model.checkItems.map { CheckItemDraft(id: $0.id, title: $0.title, detail: $0.detail ?? "", isCompleted: $0.isCompleted, sortOrder: $0.sortOrder, createdAt: $0.createdAt, completedAt: $0.completedAt) },
            photoAttachmentIDs: model.photoAttachmentIDs,
            linkAttachmentIDs: model.linkAttachmentIDs,
            audioAttachmentIDs: model.audioAttachmentIDs,
            fileAttachmentIDs: model.fileAttachmentIDs,
            attachments: model.attachments,
            autoCompleteOnChecklistCompletion: model.autoCompleteOnChecklistCompletion
        )
    }
}

#Preview {
    let persistence = PersistenceController(inMemory: true)
    let environment = AppEnvironment(persistence: persistence)
    let viewModel = MemoryEditorViewModel(
        environment: environment,
        attachmentStore: environment.attachmentStore,
        memory: nil,
        defaultSpace: nil,
        template: .blank
    )

    SequentialTriggerEditorScreen(viewModel: viewModel)
}
