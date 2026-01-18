//
//  MindDetailView.swift
//  i-cant-miss
//

import SwiftUI

struct MindDetailView: View {
    let mind: MindModel

    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var mindService: MindService
    @ObservedObject var spaceService: SpaceService
    @ObservedObject var memoryService: MemoryService

    let onSelectMemory: (MemoryModel) -> Void
    let onEditMind: ((MindModel) -> Void)?
    let onMultiSelectionChange: (Bool) -> Void
    let onSpaceContextChange: (SpaceModel?) -> Void
    let onSearchActiveChange: (Bool) -> Void

    @State private var isSearching = false

    init(
        mind: MindModel,
        mindService: MindService,
        spaceService: SpaceService,
        memoryService: MemoryService,
        onSelectMemory: @escaping (MemoryModel) -> Void,
        onEditMind: ((MindModel) -> Void)?,
        onMultiSelectionChange: @escaping (Bool) -> Void,
        onSpaceContextChange: @escaping (SpaceModel?) -> Void,
        onSearchActiveChange: @escaping (Bool) -> Void
    ) {
        self.mind = mind
        self.mindService = mindService
        self.spaceService = spaceService
        self.memoryService = memoryService
        self.onSelectMemory = onSelectMemory
        self.onEditMind = onEditMind
        self.onMultiSelectionChange = onMultiSelectionChange
        self.onSpaceContextChange = onSpaceContextChange
        self.onSearchActiveChange = onSearchActiveChange
    }

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var resolvedMind: MindModel {
        mindService.mind(id: mind.id) ?? mind
    }

    private var isAllMinds: Bool {
        resolvedMind.isAllMinds
    }

    private var spacesInMind: [SpaceModel] {
        if isAllMinds {
            return spaceService.spaces
        } else {
            return spaceService.spaces.filter { space in
                guard let mindID = space.mind?.id else { return false }
                return mindID == mind.id
            }
        }
    }

    var body: some View {
        baseView
            .fullScreenCover(isPresented: $isSearching) {
                MemorySearchSheet(
                    space: SpaceModel.allSpaces,
                    memoryService: memoryService,
                    onSelectMemory: onSelectMemory,
                    spaceService: spaceService
                )
            }
            .onAppear {
                onMultiSelectionChange(false)
            }
            .onChange(of: isSearching) { _, newValue in
                onSearchActiveChange(newValue)
            }
    }

    private var baseView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(resolvedMind.name)
                    .appLargeTitleStyle()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                if spacesInMind.isEmpty {
                    EmptyStateView(
                        systemImage: "square.grid.2x2",
                        title: "No Spaces",
                        message: "This mind doesn't have any spaces yet."
                    )
                    .padding(.horizontal, 20)
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(spacesInMind) { space in
                            NavigationLink(value: space) {
                                SpaceGridItemView(
                                    space: space,
                                    count: memoryCounts(for: space).total,
                                    completedCount: memoryCounts(for: space).completed,
                                    spaceService: spaceService,
                                    memoryService: memoryService,
                                    mindService: mindService,
                                    onEdit: nil
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .accessibilityHint("Opens details for \(space.name)")
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .toolbarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 70)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button {
                        isSearching = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }

                    if !isAllMinds, onEditMind != nil {
                        Button {
                            onEditMind?(resolvedMind)
                        } label: {
                            Image(systemName: "pencil")
                        }
                    }
                }
            }
        }
        .navigationDestination(for: SpaceModel.self) { space in
            SpaceDetailView(
                space: space,
                spaceService: spaceService,
                memoryService: memoryService,
                onSelectMemory: onSelectMemory,
                onEditSpace: nil,
                onMultiSelectionChange: onMultiSelectionChange,
                onSpaceContextChange: { newSpace in
                    onSpaceContextChange(newSpace)
                },
                onSearchActiveChange: onSearchActiveChange
            )
            .onAppear {
                onSpaceContextChange(space)
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationTitle(resolvedMind.name)
        .navigationBarTitleDisplayMode(.large)
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
}
