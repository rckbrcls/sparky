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
    let onCreateSpace: () -> Void
    let onEditSpace: ((SpaceModel) -> Void)?
    let onMultiSelectionChange: (Bool) -> Void
    let onSpaceContextChange: (SpaceModel?) -> Void
    let onSearchActiveChange: (Bool) -> Void

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                Text("Spaces")
                    .appLargeTitleStyle()
                    .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                Section {
                    ForEach(displaySpaces) { space in
                        NavigationLink(value: space) {
                            SpaceRowView(
                                space: space,
                                count: memoryCount(for: space),
                                spaceService: spaceService,
                                memoryService: memoryService,
                                onEdit: onEditSpace
                            )
                        }
                        .accessibilityHint("Opens details for \(space.name)")
                        .moveDisabled(space.isAllSpaces)
                    }
                    .onMove(perform: moveSpaces)
                }
            }
            .listSectionSpacing(.compact)
            .contentMargins(.top, 0, for: .scrollContent)
            .environment(\.defaultMinListRowHeight, 0)
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height:  70)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        onCreateSpace()
                    } label: {
                        Image(systemName: "folder.badge.plus")
                    }
                    .accessibilityLabel("Create Space")
                }
            }
            .toolbarTitleDisplayMode(.inline)
            .navigationDestination(for: SpaceModel.self) { space in
                SpaceDetailView(
                    space: space,
                    spaceService: spaceService,
                    memoryService: memoryService,
                    onSelectMemory: onSelectMemory,
                    onEditSpace: onEditSpace,
                    onMultiSelectionChange: onMultiSelectionChange,
                    onSpaceContextChange: { newSpace in
                        // Immediately notify when space context changes
                        onSpaceContextChange(newSpace)
                    },
                    onSearchActiveChange: onSearchActiveChange
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
        let sortedSpaces = spaceService.spaces
            .sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder {
                    return lhs.sortOrder < rhs.sortOrder
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        return [SpaceModel.allSpaces] + sortedSpaces
    }

    private func moveSpaces(from source: IndexSet, to destination: Int) {
        // Prevent moving to position 0 (All space must stay first)
        guard destination > 0 else { return }

        // Prevent moving the All space (index 0)
        if source.contains(0) { return }

        // Create mutable copy of display spaces
        var reorderedSpaces = displaySpaces
        reorderedSpaces.move(fromOffsets: source, toOffset: destination)

        // Extract only the user-created spaces (exclude All space) and get their IDs
        let orderedIDs = reorderedSpaces
            .filter { !$0.isAllSpaces }
            .map { $0.id }

        // Persist the new order
        Task {
            try? await spaceService.reorderSpaces(orderedIDs)
        }
    }

    private func memoryCount(for space: SpaceModel) -> Int {
        if space.isAllSpaces {
            return memoryService.memories.count
        }
        return memoryService.memories.filter { memory in
            guard let spaceID = memory.space?.id else { return false }
            return spaceID == space.id
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
        onCreateSpace: { },
        onEditSpace: nil,
        onMultiSelectionChange: { _ in },
        onSpaceContextChange: { _ in },
        onSearchActiveChange: { _ in }
    )
}
