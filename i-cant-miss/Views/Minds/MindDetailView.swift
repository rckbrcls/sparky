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
    let onAddSpace: ((MindModel) -> Void)?
    let onMultiSelectionChange: (Bool) -> Void
    let onSpaceContextChange: (SpaceModel?) -> Void
    let onMindContextChange: ((MindModel?) -> Void)?
    let onSearchActiveChange: (Bool) -> Void

    @State private var isSearching = false

    init(
        mind: MindModel,
        mindService: MindService,
        spaceService: SpaceService,
        memoryService: MemoryService,
        onSelectMemory: @escaping (MemoryModel) -> Void,
        onEditMind: ((MindModel) -> Void)?,
        onAddSpace: ((MindModel) -> Void)?,
        onMultiSelectionChange: @escaping (Bool) -> Void,
        onSpaceContextChange: @escaping (SpaceModel?) -> Void,
        onMindContextChange: ((MindModel?) -> Void)?,
        onSearchActiveChange: @escaping (Bool) -> Void
    ) {
        self.mind = mind
        self.mindService = mindService
        self.spaceService = spaceService
        self.memoryService = memoryService
        self.onSelectMemory = onSelectMemory
        self.onEditMind = onEditMind
        self.onAddSpace = onAddSpace
        self.onMultiSelectionChange = onMultiSelectionChange
        self.onSpaceContextChange = onSpaceContextChange
        self.onMindContextChange = onMindContextChange
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

    private var isInboxMinds: Bool {
        resolvedMind.isInboxMinds
    }

    private var spacesInMind: [SpaceModel] {
        let filteredSpaces: [SpaceModel]
        if isAllMinds {
            let defaultSpaces = [SpaceModel.allSpaces, SpaceModel.inboxSpaces]
            filteredSpaces = spaceService.spaces
            return defaultSpaces + filteredSpaces
        } else if isInboxMinds {
            filteredSpaces = spaceService.spaces.filter { space in
                // Inclui spaces sem mind ou com mind "All Minds"
                space.mind == nil || space.mind?.id == MindModel.allMindsIdentifier
            }
            return filteredSpaces
        } else {
            filteredSpaces = spaceService.spaces.filter { space in
                guard let mindID = space.mind?.id else { return false }
                return mindID == mind.id
            }
            let allSpace = SpaceModel.allSpace(for: resolvedMind)
            return [allSpace] + filteredSpaces
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
                onMindContextChange?(resolvedMind)
            }
            .onDisappear {
                // Limpar mind context quando sair do MindDetailView
                onMindContextChange?(nil)
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
                                    onEdit: nil,
                                    showOnlyRemaining: true
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

        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 70)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    isSearching = true
                } label: {
                    Image(systemName: "magnifyingglass")
                }
            }

            if !isAllMinds, let onAddSpace = onAddSpace {
                ToolbarItem(placement: .navigationBarTrailing) {
                
                    Button {
                        onAddSpace(resolvedMind)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add Space")
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
            .onDisappear {
                // Quando sair do SpaceDetailView, manter o mind context
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    private func memoryCounts(for space: SpaceModel) -> (completed: Int, total: Int) {
        let memories: [MemoryModel]
        if space.isAllSpaces {
            memories = memoryService.memories
        } else if space.isInboxSpaces {
            memories = memoryService.memories.filter { memory in
                memory.space == nil
            }
        } else if space.isAllSpaceForMind {
            guard let mindID = space.mind?.id else {
                return (0, 0)
            }
            memories = memoryService.memories.filter { memory in
                guard let memorySpaceMindID = memory.space?.mind?.id else { return false }
                return memorySpaceMindID == mindID
            }
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
