//
//  SpaceDetailView.swift
//  i-cant-miss
//
//  Created by Codex on 09/03/24.
//

import SwiftUI

struct SpaceDetailView: View {
    let space: SpaceModel

    @ObservedObject var spaceService: SpaceService
    @ObservedObject var memoryService: MemoryService

    let onCreateMemory: (SpaceModel?) -> Void
    let onSelectMemory: (MemoryModel) -> Void

    @State private var statusFilter: StatusFilter = .active

    private enum StatusFilter: String, CaseIterable, Identifiable {
        case active = "Active"
        case completed = "Completed"
        case archived = "Archived"
        case all = "All"

        var id: String { rawValue }
    }

    var body: some View {
        List {
            if !childSpaces.isEmpty {
                Section("Subspaces") {
                    ForEach(childSpaces) { child in
                        NavigationLink(value: child) {
                            SpaceRowView(
                                space: child,
                                count: memoryCount(for: child),
                                parentLookup: spaceService.space(id:)
                            )
                        }
                    }
                }
            }

            Section {
                Picker("Status Filter", selection: $statusFilter) {
                    ForEach(StatusFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Memories") {
                if filteredMemories.isEmpty {
                    Label("No memories in this space", systemImage: "tray")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filteredMemories) { memory in
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
        .navigationTitle(space.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    onCreateMemory(space)
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Create Memory")
            }
        }
        .refreshable {
            await refresh()
        }
    }

    private var childSpaces: [SpaceModel] {
        spaceService.children(of: space)
    }

    private var filteredMemories: [MemoryModel] {
        let statuses: Set<MemoryStatus>
        let includeArchived: Bool

        switch statusFilter {
        case .active:
            statuses = [.active]
            includeArchived = false
        case .completed:
            statuses = [.completed]
            includeArchived = false
        case .archived:
            statuses = [.archived]
            includeArchived = true
        case .all:
            statuses = []
            includeArchived = true
        }

        return memoryService.memories(
            in: space,
            includeDescendants: false,
            statuses: statuses,
            includeCompleted: statusFilter != .active,
            includeArchived: includeArchived,
            sort: .updatedAtDescending
        )
    }

    private func memoryCount(for space: SpaceModel) -> Int {
        let ids = spaceService.descendantIDs(of: space)
        return memoryService.memories.filter { ids.contains($0.space.id) }.count
    }

    private func refresh() async {
        async let spaces = spaceService.refresh(force: true)
        async let memories = memoryService.refresh(force: true)
        _ = await (spaces, memories)
    }
}
