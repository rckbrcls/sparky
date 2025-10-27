//
//  MemoryTimelineView.swift
//  i-cant-miss
//
//  Created by Codex on 09/03/24.
//

import SwiftUI

struct MemoryTimelineView: View {
    @ObservedObject var memoryService: MemoryService
    let onSelectMemory: (MemoryModel) -> Void

    var body: some View {
        NavigationStack {
            ScrollView{
                VStack(alignment: .leading, spacing: 16) {
                    timelineSections
                    inboxSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 70) 
            }
            .navigationTitle("Timeline")
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
                                MemoryCardView(memory: memory)
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Label(section.kind.title, systemImage: section.kind.systemImage)
                            .padding(.top, 16)
                        Divider()
                    }

                }
            }
        }
    }

    private var inboxSection: some View {
        Section  {
            let memories = memoryService.inboxMemories()
            if memories.isEmpty {
                Label("All caught up", systemImage: "checkmark.seal")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(memories, id: \.self) { memory in
                    Button {
                        onSelectMemory(memory)
                    } label: {
                        MemoryCardView(memory: memory)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        header: {
            Label("Inbox", systemImage: "tray.fill")
                .padding(.top, 16)
            Divider()
        }
    }
}

#Preview {
    let environment = AppEnvironment(persistence: PersistenceController.preview)
    environment.bootstrap()
    return MemoryTimelineView(
        memoryService: environment.memoryService,
        onSelectMemory: { _ in }
    )
}
