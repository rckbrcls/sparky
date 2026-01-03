//
//  SequentialTriggerEditorScreen.swift
//  i-cant-miss
//
//  Created by Codex on 13/10/25.
//
//

import SwiftUI
import UniformTypeIdentifiers

struct SequentialTriggerEditorScreen: View {
    @ObservedObject var viewModel: MemoryEditorViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var sequenceItems: [SequentialItem] = []
    @State private var showingPicker = false
    @State private var draggedItem: SequentialItem?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sequence Order")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)

                        VStack(spacing: 12) {
                            if sequenceItems.isEmpty {
                                Text("No memories in sequence")
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding()
                            } else {
                                ForEach(sequenceItems) { item in
                                    SequentialItemView(
                                        index: sequenceItems.firstIndex(of: item) ?? 0,
                                        item: item,
                                        onDelete: {
                                            if let index = sequenceItems.firstIndex(of: item) {
                                                sequenceItems.remove(at: index)
                                            }
                                        }
                                    )
                                    .onDrag {
                                        self.draggedItem = item
                                        return NSItemProvider(item: item.id.uuidString as NSString, typeIdentifier: "com.icantmiss.sequentialitem")
                                    }
                                    .onDrop(of: ["com.icantmiss.sequentialitem"], delegate: SequentialDropDelegate(item: item, items: $sequenceItems, draggedItem: $draggedItem))
                                }
                            }

                            Button {
                                showingPicker = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus")
                                        .font(.caption.bold())
                                    Text("Add Memory")
                                        .font(.caption.bold())
                                }
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                                        .foregroundStyle(Color.secondary.opacity(0.4))
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text("Drag to reorder. The sequence will advance in this order.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
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

    fileprivate struct SequentialItem: Identifiable, Equatable {
        let id: UUID
        let title: String
        var isCurrent: Bool
    }

    private func loadExistingConfiguration() {
        var items: [SequentialItem] = []

        // 1. Current Memory
        let currentID = viewModel.editingMemoryID ?? UUID()

        if let seqInfo = viewModel.sequentialTrigger?.sequential {
            let sequenceID = seqInfo.sequenceID

            // Fetch all memories with this sequenceID
            let allMemories = viewModel.environment.memoryService.memories.filter { memory in
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

        // Ensure current is in list if not found
        if !items.contains(where: { $0.isCurrent }) {
            let title = viewModel.title.isEmpty ? "New Memory" : viewModel.title
            let current = SequentialItem(id: currentID, title: title, isCurrent: true)
            items.append(current)
        }

        self.sequenceItems = items
    }

    private func save() async {
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

        // 3. Handle removed items
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
        var triggers = memory.triggers
        let newSeq = MemoryTriggerModel.TriggerSequential(sequenceID: sequenceID, stepIndex: index)

        if let idx = triggers.firstIndex(where: { $0.type == .sequential }) {
             triggers[idx].sequential = newSeq
        } else {
            let t = MemoryTriggerModel(
                id: UUID(),
                type: .sequential,
                weekdayMask: 0,
                isActive: true,
                sequential: newSeq,
                spacedStage: 0,
                ignoreCount: 0
            )
            triggers.append(t)
        }

        let draft = MemoryDraft.from(model: memory, withTriggers: triggers)
        _ = try? await viewModel.environment.memoryService.updateMemory(from: draft)
    }

    private func removeSequentialTrigger(from memory: MemoryModel) async {
        var triggers = memory.triggers
        triggers.removeAll { $0.type == .sequential }
        let draft = MemoryDraft.from(model: memory, withTriggers: triggers)
        _ = try? await viewModel.environment.memoryService.updateMemory(from: draft)
    }
}

fileprivate struct SequentialItemView: View {
    let index: Int
    let item: SequentialTriggerEditorScreen.SequentialItem
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                        .frame(width: 24, alignment: .center)

                    VStack(alignment: .leading, spacing: 2) {
                        if item.isCurrent {
                            Text("Current Memory")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                        Text(item.title)
                            .font(.custom("Vollkorn-Regular", size: 17))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Button {
                        withAnimation {
                            onDelete()
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(.secondarySystemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
        }
    }
}

fileprivate struct SequentialDropDelegate: DropDelegate {
    let item: SequentialTriggerEditorScreen.SequentialItem
    @Binding var items: [SequentialTriggerEditorScreen.SequentialItem]
    @Binding var draggedItem: SequentialTriggerEditorScreen.SequentialItem?

    func dropUpdated(info: DropInfo) -> DropProposal {
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggedItem = draggedItem else { return }
        guard draggedItem.id != item.id else { return }

        if let from = items.firstIndex(of: draggedItem),
           let to = items.firstIndex(of: item) {
            if from != to {
                withAnimation {
                    items.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
                }
            }
        }
    }
}

fileprivate extension MemoryDraft {
    static func from(model: MemoryModel, withTriggers triggers: [MemoryTriggerModel]) -> MemoryDraft {
        MemoryDraft(
            id: model.id,
            title: model.title,
            status: model.status,
            isPinned: model.isPinned,
            dueDate: model.dueDate,
            spaceID: model.space?.id,
            triggers: triggers,
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
