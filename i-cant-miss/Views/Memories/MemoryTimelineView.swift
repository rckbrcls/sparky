//
//  MemoryTimelineView.swift
//  i-cant-miss
//
//  Created by Codex on 09/03/24.
//

import SwiftUI

struct MemoryTimelineView: View {
    @ObservedObject var memoryService: MemoryService
    let onCreateMemory: () -> Void
    let onSelectMemory: (MemoryModel) -> Void

    var body: some View {
        NavigationStack {
            List {
                timelineSections
                inboxSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Timeline")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: onCreateMemory) {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Create Memory")
                }
            }
            .refreshable {
                await memoryService.refresh(force: true)
            }
        }
    }

    private var timelineSections: some View {
        let sections = memoryService.timelineSections()

        return Group {
            if sections.isEmpty {
                Section("Upcoming") {
                    Label("No memories with active triggers", systemImage: "tray")
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(sections) { section in
                    Section {
                        ForEach(section.memories) { memory in
                            Button {
                                onSelectMemory(memory)
                            } label: {
                                MemoryRowView(memory: memory)
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Label(section.kind.title, systemImage: section.kind.systemImage)
                    }
                }
            }
        }
    }

    private var inboxSection: some View {
        Section("Inbox") {
            let memories = memoryService.inboxMemories()
            if memories.isEmpty {
                Label("All caught up", systemImage: "checkmark.seal")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(memories) { memory in
                    Button {
                        onSelectMemory(memory)
                    } label: {
                        MemoryRowView(memory: memory)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

#Preview {
    let environment = AppEnvironment(persistence: PersistenceController.preview)
    environment.bootstrap()
    return MemoryTimelineView(
        memoryService: environment.memoryService,
        onCreateMemory: {},
        onSelectMemory: { _ in }
    )
}
