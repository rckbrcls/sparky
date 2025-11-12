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
    @Binding var navigationPath: NavigationPath

    let onSelectMemory: (MemoryModel) -> Void
    let onCreateSpace: (SpaceModel?) -> Void
    let onMultiSelectionChange: (Bool) -> Void
    let onSpaceContextChange: (SpaceModel?) -> Void

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                Section {
                    ForEach(displaySpaces) { space in
                        NavigationLink(value: space) {
                            SpaceRowView(
                                space: space,
                                count: memoryCount(for: space),
                                spaceService: spaceService,
                                parentLookup: spaceService.space(id:)
                            )
                        }
                        .accessibilityHint("Opens details for \(space.name)")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height:  70)
            }
            .navigationTitle("Spaces")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        onCreateSpace(nil)
                    } label: {
                        Image(systemName: "folder.badge.plus")
                    }
                    .accessibilityLabel("Create Space")
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
                    onSelectMemory: onSelectMemory,
                    onCreateSpace: onCreateSpace,
                    onMultiSelectionChange: onMultiSelectionChange,
                    onSpaceContextChange: onSpaceContextChange
                )
            }
        }
        .onAppear {
            onMultiSelectionChange(false)
            onSpaceContextChange(nil)
        }
    }

    private var displaySpaces: [SpaceModel] {
        let rootSpaces = spaceService.rootSpaces()
            .filter { $0.id != SpaceModel.inboxIdentifier }
            .sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder {
                    return lhs.sortOrder < rhs.sortOrder
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        return [SpaceModel.allSpaces] + rootSpaces
    }

    private func memoryCount(for space: SpaceModel) -> Int {
        if space.isAllSpaces {
            return memoryService.memories.count
        }
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
        navigationPath: .constant(NavigationPath()),
        onSelectMemory: { _ in },
        onCreateSpace: { _ in },
        onMultiSelectionChange: { _ in },
        onSpaceContextChange: { _ in }
    )
}
