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
    let onEditMemory: ((MemoryModel) -> Void)?
    let onCreateSpace: (SpaceModel?) -> Void
    let onEditSpace: ((SpaceModel) -> Void)?
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
                                memoryService: memoryService,
                                parentLookup: spaceService.space(id:),
                                onEdit: onEditSpace
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
                    onEditMemory: onEditMemory,
                    onCreateSpace: onCreateSpace,
                    onEditSpace: onEditSpace,
                    onMultiSelectionChange: onMultiSelectionChange,
                    onSpaceContextChange: { newSpace in
                        // Immediately notify when space context changes
                        onSpaceContextChange(newSpace)
                    }
                )
                .onAppear {
                    // Ensure context is set immediately when destination appears
                    onSpaceContextChange(space)
                }
            }
        }
        .onAppear {
            onMultiSelectionChange(false)
            onSpaceContextChange(nil)
        }
        .onChange(of: navigationPath) { oldPath, newPath in
            // When navigation path changes, if it's empty, clear the context
            // Otherwise, let SpaceDetailView notify the context
            if newPath.isEmpty {
                onSpaceContextChange(nil)
            }
        }
    }

    private var displaySpaces: [SpaceModel] {
        let rootSpaces = spaceService.rootSpaces()
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
        return memoryService.memories.filter { memory in
            guard let spaceID = memory.space?.id else { return false }
            return ids.contains(spaceID)
        }.count
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
        onEditMemory: nil,
        onCreateSpace: { _ in },
        onEditSpace: nil,
        onMultiSelectionChange: { _ in },
        onSpaceContextChange: { _ in }
    )
}
