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

    @State private var beforeMemoryIDs: [UUID] = []
    @State private var nextMemoryIDs: [UUID] = []

    @State private var showingPicker = false
    @State private var pickerMode: PickerMode = .before

    // For drag and drop
    @State private var isDragging = false

    private enum PickerMode {
        case before
        case after
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Explanatory Text
                    Text("Choose memories that should happen before or after this one. When you complete the previous memory, this one will become active. When you complete this one, the next one will become active.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                    VStack(spacing: 32) {
                        // Before Section
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "Previous Memories", icon: "arrow.up.circle.fill", color: .orange)

                            VStack(spacing: 12) {
                                // Add Button at Top
                                SequentialAddButton(title: "Add Previous Memory") {
                                    pickerMode = .before
                                    showingPicker = true
                                }

                                if !beforeMemoryIDs.isEmpty {
                                    ForEach(beforeMemoryIDs, id: \.self) { id in
                                        if let memory = viewModel.environment.memoryService.memory(id: id) {
                                            SequentialMemoryCard(memory: memory) {
                                                withAnimation {
                                                    if let index = beforeMemoryIDs.firstIndex(of: id) {
                                                        beforeMemoryIDs.remove(at: index)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    .onMove { from, to in
                                        beforeMemoryIDs.move(fromOffsets: from, toOffset: to)
                                    }
                                }
                            }
                        }

                        // Current Memory Indicator
                        VStack(spacing: 8) {
                            Image(systemName: "arrow.down")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            HStack {
                                Spacer()
                                Text("Current Memory")
                                    .font(.caption.smallCaps())
                                    .fontWeight(.bold)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color(.secondarySystemBackground))
                            )

                            Image(systemName: "arrow.down")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 40)

                        // After Section
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "Next Memories", icon: "arrow.down.circle.fill", color: .blue)

                            VStack(spacing: 12) {
                                if !nextMemoryIDs.isEmpty {
                                    ForEach(nextMemoryIDs, id: \.self) { id in
                                        if let memory = viewModel.environment.memoryService.memory(id: id) {
                                            SequentialMemoryCard(memory: memory) {
                                                withAnimation {
                                                    if let index = nextMemoryIDs.firstIndex(of: id) {
                                                        nextMemoryIDs.remove(at: index)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    .onMove { from, to in
                                        nextMemoryIDs.move(fromOffsets: from, toOffset: to)
                                    }
                                }

                                // Add Button at Bottom
                                SequentialAddButton(title: "Add Next Memory") {
                                    pickerMode = .after
                                    showingPicker = true
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
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
                        save()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingPicker) {
                SequentialMemoryPickerSheet(
                    viewModel: viewModel,
                    excludedMemoryIDs: excludedIDs,
                    onSelect: { memory in
                        withAnimation {
                            switch pickerMode {
                            case .before:
                                beforeMemoryIDs.append(memory.id)
                            case .after:
                                nextMemoryIDs.append(memory.id)
                            }
                        }
                    }
                )
            }
            .onAppear {
                loadExistingConfiguration()
            }
        }
    }

    private var excludedIDs: Set<UUID> {
        var ids = Set(beforeMemoryIDs)
        ids.formUnion(nextMemoryIDs)
        if let currentID = viewModel.editingMemoryID {
            ids.insert(currentID)
        }
        return ids
    }

    private func loadExistingConfiguration() {
        if let existing = viewModel.sequentialTrigger?.sequential {
            self.beforeMemoryIDs = existing.previousMemoryIDs
            self.nextMemoryIDs = existing.nextMemoryIDs
        }
    }

    private func save() {
        viewModel.updateSequentialTrigger(
            previousMemoryIDs: beforeMemoryIDs,
            nextMemoryIDs: nextMemoryIDs
        )
        dismiss()
    }
}

private struct SectionHeader: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
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
