//
//  MindRootView.swift
//  i-cant-miss
//

import SwiftUI

struct MindRootView: View {
    @ObservedObject var mindService: MindService
    @ObservedObject var spaceService: SpaceService
    @ObservedObject var memoryService: MemoryService
    @Binding var navigationPath: NavigationPath

    let onSelectMemory: (MemoryModel) -> Void
    let onEditMemory: ((MemoryModel) -> Void)?
    let onCreateMind: () -> Void
    let onEditMind: ((MindModel) -> Void)?
    let onAddSpace: ((MindModel) -> Void)?
    let onMultiSelectionChange: (Bool) -> Void
    let onSpaceContextChange: (SpaceModel?) -> Void
    let onMindContextChange: ((MindModel?) -> Void)?
    let onSearchActiveChange: (Bool) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Minds")
                        .appLargeTitleStyle()
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)

                    VStack(spacing: 12) {
                        NavigationLink(value: SpaceModel.limboSpaces) {
                            LimboCardView(
                                space: SpaceModel.limboSpaces,
                                count: limboMemoryCounts().total,
                                completedCount: limboMemoryCounts().completed,
                                activeCount: limboActiveMemoryCount(),
                                spaceService: spaceService,
                                memoryService: memoryService,
                                mindService: mindService
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .accessibilityHint("Opens limbo details")
                        .padding(.horizontal, 20)
                        
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(displayMinds) { mind in
                                NavigationLink(value: mind) {
                                    MindGridItemView(
                                        mind: mind,
                                        count: spaceCounts(for: mind),
                                        activeCount: activeMemoryCount(for: mind),
                                        mindService: mindService,
                                        spaceService: spaceService,
                                        onEdit: onEditMind
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                .accessibilityHint("Opens details for \(mind.name)")
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
                    Button {
                        onCreateMind()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Create Mind")
                }
            }
            .navigationDestination(for: MindModel.self) { mind in
                MindDetailView(
                    mind: mind,
                    mindService: mindService,
                    spaceService: spaceService,
                    memoryService: memoryService,
                    onSelectMemory: onSelectMemory,
                    onEditMemory: onEditMemory,
                    onEditMind: onEditMind,
                    onAddSpace: onAddSpace,
                    onMultiSelectionChange: onMultiSelectionChange,
                    onSpaceContextChange: onSpaceContextChange,
                    onMindContextChange: onMindContextChange,
                    onSearchActiveChange: onSearchActiveChange
                )
            }
            .navigationDestination(for: SpaceModel.self) { space in
                SpaceDetailView(
                    space: space,
                    spaceService: spaceService,
                    memoryService: memoryService,
                    onSelectMemory: onSelectMemory,
                    onEditMemory: onEditMemory,
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
        }
        .onAppear {
            onMultiSelectionChange(false)
            onSpaceContextChange(nil)
            onMindContextChange?(nil)
        }
        .onChange(of: navigationPath) { oldPath, newPath in
            if newPath.isEmpty {
                onSpaceContextChange(nil)
                onMindContextChange?(nil)
            }
        }
    }

    private var displayMinds: [MindModel] {
        let sortedMinds = mindService.minds
            .filter { !$0.isDefault && !$0.isAllMinds } // Filter out the default "All Minds" and virtual "All Minds"
            .sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder {
                    return lhs.sortOrder < rhs.sortOrder
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        return [MindModel.allMinds] + sortedMinds
    }

    private func spaceCounts(for mind: MindModel) -> Int {
        if mind.isAllMinds {
            return spaceService.spaces.count
        } else {
            return spaceService.spaces.filter { space in
                guard let mindID = space.mind?.id else { return false }
                return mindID == mind.id
            }.count
        }
    }

    private func activeMemoryCount(for mind: MindModel) -> Int {
        let memories: [MemoryModel]
        if mind.isAllMinds {
            memories = memoryService.memories
        } else {
            let mindID = mind.id
            memories = memoryService.memories.filter { memory in
                guard let memorySpaceMindID = memory.space?.mind?.id else { return false }
                return memorySpaceMindID == mindID
            }
        }

        return memories.filter { $0.status == .active }.count
    }

    private func limboMemoryCounts() -> (completed: Int, total: Int) {
        let memories = memoryService.memories.filter { memory in
            memory.space == nil
        }
        let total = memories.count
        let completed = memories.filter { $0.isCompleted }.count
        return (completed, total)
    }

    private func limboActiveMemoryCount() -> Int {
        let memories = memoryService.memories.filter { memory in
            memory.space == nil
        }
        return memories.filter { $0.status == .active }.count
    }

    private func refresh() async {
        async let minds = mindService.refresh(force: true)
        async let spaces = spaceService.refresh(force: true)
        _ = await (minds, spaces)
    }
}

#Preview {
    let environment = AppEnvironment(persistence: PersistenceController.preview)
    environment.bootstrap()
    return MindRootView(
        mindService: environment.mindService,
        spaceService: environment.spaceService,
        memoryService: environment.memoryService,
        navigationPath: .constant(NavigationPath()),
        onSelectMemory: { _ in },
        onEditMemory: nil,
        onCreateMind: { },
        onEditMind: nil,
        onAddSpace: nil,
        onMultiSelectionChange: { _ in },
        onSpaceContextChange: { _ in },
        onMindContextChange: nil,
        onSearchActiveChange: { _ in }
    )
}
