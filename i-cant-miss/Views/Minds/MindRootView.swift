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
    let onEditLobe: ((LobeModel) -> Void)?
    let onAddLobe: ((MindModel) -> Void)?
    let onAddLobeWithoutMind: (() -> Void)?
    let onMultiSelectionChange: (Bool) -> Void
    let onLobeContextChange: (LobeModel?) -> Void
    let onMindContextChange: ((MindModel?) -> Void)?
    let onSearchActiveChange: (Bool) -> Void

    @State private var isMindsExpanded = true
    @State private var isLobesExpanded = true

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
                        // Minds Collapsible Section
                        VStack(spacing: 0) {
                            HStack {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isMindsExpanded.toggle()
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "brain.head.profile")
                                            .foregroundStyle(Color.purple)
                                            .font(.caption)
                                            .frame(width: 14, height: 14)
                                        Text("Minds")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundStyle(.primary)
                                        Text("\(displayMinds.count)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.secondary)
                                            .rotationEffect(.degrees(isMindsExpanded ? 90 : 0))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.purple.opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.purple.opacity(0.1), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, isMindsExpanded ? 8 : 0)
                            
                            if isMindsExpanded {
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
                                .padding(.bottom, displayLobesWithoutMind.isEmpty ? 0 : 12)
                            }
                        }
                        
                        // Lobes Collapsible Section
                        VStack(spacing: 0) {
                            HStack {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isLobesExpanded.toggle()
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "brain.fill")
                                            .foregroundStyle(Color.gray)
                                            .font(.caption)
                                            .frame(width: 14, height: 14)
                                        Text("Lobes")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundStyle(.primary)
                                        Text("\(displayLobesWithoutMind.count)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.secondary)
                                            .rotationEffect(.degrees(isLobesExpanded ? 90 : 0))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.gray.opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, isLobesExpanded ? 8 : 0)
                            
                            if isLobesExpanded {
                                VStack(spacing: 12) {
                                    // Lobe Limbo - shows memories without lobe
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
                                    
                                    if !displayLobesWithoutMind.isEmpty {
                                        LazyVGrid(columns: columns, spacing: 12) {
                                            ForEach(displayLobesWithoutMind) { lobe in
                                                NavigationLink(value: lobe) {
                                                    LobeGridItemView(
                                                        lobe: lobe,
                                                        count: memoryCounts(for: lobe).total,
                                                        completedCount: memoryCounts(for: lobe).completed,
                                                        activeCount: activeMemoryCount(for: lobe),
                                                        lobeService: lobeService,
                                                        memoryService: memoryService,
                                                        mindService: mindService,
                                                        onEdit: onEditLobe,
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
                        }
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
                    Menu {
                        Button {
                            onCreateMind()
                        } label: {
                            Label("Add Mind", systemImage: "brain.head.profile")
                        }
                        
                        Button {
                            onAddLobeWithoutMind?()
                        } label: {
                            Label("Add Lobe", systemImage: "brain.fill")
                        }
                        .disabled(onAddLobeWithoutMind == nil)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add")
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
                    onEditLobe: onEditLobe,
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
    
    private var displayLobesWithoutMind: [LobeModel] {
        lobeService.lobes
            .filter { lobe in
                guard !lobe.isAllLobes else { return false }
                guard !lobe.isAllLobeForMind else { return false }
                return lobe.mind == nil
            }
            .sorted { lhs, rhs in
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
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
    
    private func memoryCounts(for lobe: LobeModel) -> (completed: Int, total: Int) {
        let memories = memoryService.memories.filter { memory in
            guard let lobeID = memory.lobe?.id else { return false }
            return lobeID == lobe.id
        }
        let total = memories.count
        let completed = memories.filter { $0.isCompleted }.count
        return (completed, total)
    }
    
    private func activeMemoryCount(for lobe: LobeModel) -> Int {
        let memories = memoryService.memories.filter { memory in
            guard let lobeID = memory.lobe?.id else { return false }
            return lobeID == lobe.id
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
        onEditLobe: nil,
        onAddLobe: nil,
        onAddLobeWithoutMind: nil,
        onMultiSelectionChange: { _ in },
        onLobeContextChange: { _ in },
        onMindContextChange: nil,
        onSearchActiveChange: { _ in }
    )
}
