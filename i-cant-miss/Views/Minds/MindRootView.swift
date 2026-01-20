//
//  MindRootView.swift
//  i-cant-miss
//

import SwiftUI

struct MindRootView: View {
    @ObservedObject var mindService: MindService
    @ObservedObject var lobeService: LobeService
    @ObservedObject var memoryService: MemoryService
    @Binding var navigationPath: NavigationPath

    let onSelectMemory: (MemoryModel) -> Void
    let onEditMemory: ((MemoryModel) -> Void)?
    let onCreateMind: () -> Void
    let onEditMind: ((MindModel) -> Void)?
    let onAddLobe: ((MindModel) -> Void)?
    let onMultiSelectionChange: (Bool) -> Void
    let onLobeContextChange: (LobeModel?) -> Void
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
                        NavigationLink(value: LobeModel.limboLobes) {
                            LimboCardView(
                                lobe: LobeModel.limboLobes,
                                count: limboMemoryCounts().total,
                                completedCount: limboMemoryCounts().completed,
                                activeCount: limboActiveMemoryCount(),
                                lobeService: lobeService,
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
                                        count: lobeCounts(for: mind),
                                        activeCount: activeMemoryCount(for: mind),
                                        mindService: mindService,
                                        lobeService: lobeService,
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
                    lobeService: lobeService,
                    memoryService: memoryService,
                    onSelectMemory: onSelectMemory,
                    onEditMemory: onEditMemory,
                    onEditMind: onEditMind,
                    onAddLobe: onAddLobe,
                    onMultiSelectionChange: onMultiSelectionChange,
                    onLobeContextChange: onLobeContextChange,
                    onMindContextChange: onMindContextChange,
                    onSearchActiveChange: onSearchActiveChange
                )
            }
            .navigationDestination(for: LobeModel.self) { lobe in
                LobeDetailView(
                    lobe: lobe,
                    lobeService: lobeService,
                    memoryService: memoryService,
                    onSelectMemory: onSelectMemory,
                    onEditMemory: onEditMemory,
                    onEditLobe: nil,
                    onMultiSelectionChange: onMultiSelectionChange,
                    onLobeContextChange: { newLobe in
                        onLobeContextChange(newLobe)
                    },
                    onSearchActiveChange: onSearchActiveChange
                )
                .onAppear {
                    onLobeContextChange(lobe)
                }
            }
        }
        .onAppear {
            onMultiSelectionChange(false)
            onLobeContextChange(nil)
            onMindContextChange?(nil)
        }
        .onChange(of: navigationPath) { oldPath, newPath in
            if newPath.isEmpty {
                onLobeContextChange(nil)
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

    private func lobeCounts(for mind: MindModel) -> Int {
        if mind.isAllMinds {
            return lobeService.lobes.count
        } else {
            return lobeService.lobes.filter { lobe in
                guard let mindID = lobe.mind?.id else { return false }
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
                guard let memoryLobeMindID = memory.lobe?.mind?.id else { return false }
                return memoryLobeMindID == mindID
            }
        }

        return memories.filter { $0.status == .active }.count
    }

    private func limboMemoryCounts() -> (completed: Int, total: Int) {
        let memories = memoryService.memories.filter { memory in
            memory.lobe == nil
        }
        let total = memories.count
        let completed = memories.filter { $0.isCompleted }.count
        return (completed, total)
    }

    private func limboActiveMemoryCount() -> Int {
        let memories = memoryService.memories.filter { memory in
            memory.lobe == nil
        }
        return memories.filter { $0.status == .active }.count
    }

    private func refresh() async {
        async let minds = mindService.refresh(force: true)
        async let lobes = lobeService.refresh(force: true)
        _ = await (minds, lobes)
    }
}

#Preview {
    let environment = AppEnvironment(persistence: PersistenceController.preview)
    environment.bootstrap()
    return MindRootView(
        mindService: environment.mindService,
        lobeService: environment.lobeService,
        memoryService: environment.memoryService,
        navigationPath: .constant(NavigationPath()),
        onSelectMemory: { _ in },
        onEditMemory: nil,
        onCreateMind: { },
        onEditMind: nil,
        onAddLobe: nil,
        onMultiSelectionChange: { _ in },
        onLobeContextChange: { _ in },
        onMindContextChange: nil,
        onSearchActiveChange: { _ in }
    )
}
