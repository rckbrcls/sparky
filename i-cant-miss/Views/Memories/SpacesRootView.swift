//
//  SpacesRootView.swift
//  i-cant-miss
//
//  Created by Codex on 09/03/24.
//

import SwiftUI

struct SpacesRootView: View {
    @ObservedObject var spaceService: SpaceService
    @ObservedObject var memoryService: MemoryService

    let onCreateMemory: (SpaceModel?) -> Void
    let onSelectMemory: (MemoryModel) -> Void
    let onCreateSpace: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("Spaces") {
                    ForEach(rootSpaces) { space in
                        NavigationLink(value: space) {
                            SpaceRowView(
                                space: space,
                                count: memoryCount(for: space),
                                parentLookup: spaceService.space(id:)
                            )
                        }
                        .accessibilityHint("Opens details for \(space.name)")
                    }
                }
            }
            .navigationTitle("Spaces")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        onCreateSpace()
                    } label: {
                        Image(systemName: "folder.badge.plus")
                    }
                    .accessibilityLabel("Create Space")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        onCreateMemory(nil)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Create Memory")
                }
            }
            .refreshable {
                await refresh()
            }
            .navigationDestination(for: SpaceModel.self) { space in
                SpaceDetailView(
                    space: space,
                    spaceService: spaceService,
                    memoryService: memoryService,
                    onCreateMemory: onCreateMemory,
                    onSelectMemory: onSelectMemory,
                    onCreateSpace: onCreateSpace
                )
            }
        }
    }

    private var rootSpaces: [SpaceModel] {
        spaceService.rootSpaces()
            .sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder {
                    return lhs.sortOrder < rhs.sortOrder
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
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

#Preview {
    let environment = AppEnvironment(persistence: PersistenceController.preview)
    environment.bootstrap()
    return SpacesRootView(
        spaceService: environment.spaceService,
        memoryService: environment.memoryService,
        onCreateMemory: { _ in },
        onSelectMemory: { _ in },
        onCreateSpace: {}
    )
}
