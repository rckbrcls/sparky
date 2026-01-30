//
//  MindDetailView.swift
//  i-cant-miss
//

import SwiftUI

struct MindDetailView: View {
    let mind: Mind

    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var mindService: MindService
    @ObservedObject var lobeService: LobeService
    @ObservedObject var memoryService: MemoryService

    let onSelectMemory: (Memory) -> Void
    let onEditMemory: ((Memory) -> Void)?
    let onEditMind: ((Mind) -> Void)?
    let onAddLobe: ((Mind) -> Void)?
    let onMultiSelectionChange: (Bool) -> Void
    let onLobeContextChange: (Space?) -> Void
    let onMindContextChange: ((Mind?) -> Void)?
    let onSearchActiveChange: (Bool) -> Void

    @State private var isSearching = false

    init(
        mind: Mind,
        mindService: MindService,
        lobeService: LobeService,
        memoryService: MemoryService,
        onSelectMemory: @escaping (Memory) -> Void,
        onEditMemory: ((Memory) -> Void)? = nil,
        onEditMind: ((Mind) -> Void)?,
        onAddLobe: ((Mind) -> Void)?,
        onMultiSelectionChange: @escaping (Bool) -> Void,
        onLobeContextChange: @escaping (Space?) -> Void,
        onMindContextChange: ((Mind?) -> Void)?,
        onSearchActiveChange: @escaping (Bool) -> Void
    ) {
        self.mind = mind
        self.mindService = mindService
        self.lobeService = lobeService
        self.memoryService = memoryService
        self.onSelectMemory = onSelectMemory
        self.onEditMemory = onEditMemory
        self.onEditMind = onEditMind
        self.onAddLobe = onAddLobe
        self.onMultiSelectionChange = onMultiSelectionChange
        self.onLobeContextChange = onLobeContextChange
        self.onMindContextChange = onMindContextChange
        self.onSearchActiveChange = onSearchActiveChange
    }

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var resolvedMind: Mind {
        mindService.mind(id: mind.id) ?? mind
    }

    private var isAllMinds: Bool {
        resolvedMind.isAllMinds
    }

    private var lobesInMind: [Space] {
        let filteredLobes: [Space]
        if isAllMinds {
            let defaultLobes = [Space.allSpaces]
            filteredLobes = lobeService.lobes
            return defaultLobes + filteredLobes
        } else {
            filteredLobes = lobeService.lobes.filter { lobe in
                guard let mindID = lobe.mind?.id else { return false }
                return mindID == mind.id
            }
            let allLobe = Space.allLobe(for: resolvedMind)
            return [allLobe] + filteredLobes
        }
    }

    var body: some View {
        baseView
            .fullScreenCover(isPresented: $isSearching) {
                MemorySearchSheet(
                    lobe: Space.allLobe(for: resolvedMind),
                    memoryService: memoryService,
                    onSelectMemory: onSelectMemory,
                    lobeService: lobeService
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

                if lobesInMind.isEmpty {
                    EmptyStateView(
                        systemImage: "brain.fill",
                        title: "No Lobes",
                        message: "This mind doesn't have any lobes yet."
                    )
                    .padding(.horizontal, 20)
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(lobesInMind) { lobe in
                            NavigationLink(value: lobe) {
                                LobeGridItemView(
                                    lobe: lobe,
                                    count: memoryCounts(for: lobe).total,
                                    completedCount: memoryCounts(for: lobe).completed,
                                    activeCount: activeMemoryCount(for: lobe),
                                    lobeService: lobeService,
                                    memoryService: memoryService,
                                    mindService: mindService,
                                    onEdit: nil,
                                    showOnlyRemaining: true
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .accessibilityHint("Opens details for \(lobe.name)")
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

            if !isAllMinds, let onAddLobe = onAddLobe {
                ToolbarItem(placement: .navigationBarTrailing) {
                
                    Button {
                        onAddLobe(resolvedMind)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add Lobe")
                }
            }
        }
        .navigationDestination(for: Space.self) { lobe in
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
            .onDisappear {
                // Quando sair do LobeDetailView, manter o mind context
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    private func memoryCounts(for lobe: Space) -> (completed: Int, total: Int) {
        let memories: [Memory]
        if lobe.isAllSpaces {
            memories = memoryService.memories
        } else if lobe.isAllLobeForMind {
            guard let mindID = lobe.mind?.id else {
                return (0, 0)
            }
            memories = memoryService.memories.filter { memory in
                guard let memoryLobeMindID = memory.lobe?.mind?.id else { return false }
                return memoryLobeMindID == mindID
            }
        } else {
            memories = memoryService.memories.filter { memory in
                guard let lobeID = memory.lobe?.id else { return false }
                return lobeID == lobe.id
            }
        }

        let total = memories.count
        let completed = memories.filter { $0.isCompleted }.count
        return (completed, total)
    }

    private func activeMemoryCount(for lobe: Space) -> Int {
        let memories: [Memory]
        if lobe.isAllSpaces {
            memories = memoryService.memories
        } else if lobe.isAllLobeForMind {
            guard let mindID = lobe.mind?.id else {
                return 0
            }
            memories = memoryService.memories.filter { memory in
                guard let memoryLobeMindID = memory.lobe?.mind?.id else { return false }
                return memoryLobeMindID == mindID
            }
        } else {
            memories = memoryService.memories.filter { memory in
                guard let lobeID = memory.lobe?.id else { return false }
                return lobeID == lobe.id
            }
        }

        return memories.filter { $0.status == .active }.count
    }
}
