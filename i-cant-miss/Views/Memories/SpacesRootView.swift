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

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Spaces")
                        .appLargeTitleStyle()
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(displaySpaces) { space in
                            NavigationLink(value: space) {
                                SpaceGridItemView(
                                    space: space,
                                    count: memoryCounts(for: space).total,
                                    completedCount: memoryCounts(for: space).completed,
                                    spaceService: spaceService,
                                    memoryService: memoryService,
                                    onEdit: onEditSpace
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .accessibilityHint("Opens details for \(space.name)")
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .toolbarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
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

    private func memoryCounts(for space: SpaceModel) -> (completed: Int, total: Int) {
        let memories: [MemoryModel]
        if space.isAllSpaces {
            memories = memoryService.memories
        } else {
            memories = memoryService.memories.filter { memory in
                guard let spaceID = memory.space?.id else { return false }
                return spaceID == space.id
            }
        }

        let total = memories.count
        let completed = memories.filter { $0.isCompleted }.count
        return (completed, total)
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
