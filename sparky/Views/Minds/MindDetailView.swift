//
//  MindDetailView.swift
//  sparky
//

import SwiftUI

struct MindDetailView: View {
    let mind: Mind

    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var mindService: MindService
    @ObservedObject var memoryService: MemoryService

    let onSelectMemory: (Memory) -> Void
    let onEditMemory: ((Memory) -> Void)?
    let onEditMind: ((Mind) -> Void)?
    let onMultiSelectionChange: (Bool) -> Void
    let onMindContextChange: ((Mind?) -> Void)?
    let onSearchActiveChange: (Bool) -> Void

    @State private var isSearching = false
    @State private var isMultiSelecting = false
    @State private var selectedMemoryIDs: Set<Memory.ID> = []
    @State private var isPerformingBulkAction = false
    @State private var showingDeleteConfirmation = false
    @State private var bulkActionErrorMessage: String?
    @State private var expandedSections: Set<MindSectionType> = Set(MindSectionType.allCases)
    @State private var selectedTriggerTypes: Set<MemoryTriggerType> = []
    @State private var sortStrategy: MemoryService.SortStrategy = .createdAtDescending
    @State private var showMindComposer = false
    @State private var mindToEdit: Mind?

    init(
        mind: Mind,
        mindService: MindService,
        memoryService: MemoryService,
        onSelectMemory: @escaping (Memory) -> Void,
        onEditMemory: ((Memory) -> Void)? = nil,
        onEditMind: ((Mind) -> Void)? = nil,
        onMultiSelectionChange: @escaping (Bool) -> Void,
        onMindContextChange: ((Mind?) -> Void)?,
        onSearchActiveChange: @escaping (Bool) -> Void
    ) {
        self.mind = mind
        self.mindService = mindService
        self.memoryService = memoryService
        self.onSelectMemory = onSelectMemory
        self.onEditMemory = onEditMemory
        self.onEditMind = onEditMind
        self.onMultiSelectionChange = onMultiSelectionChange
        self.onMindContextChange = onMindContextChange
        self.onSearchActiveChange = onSearchActiveChange
    }

    private var resolvedMind: Mind {
        mindService.mind(id: mind.id) ?? mind
    }

    private var isAllMinds: Bool {
        resolvedMind.isAllMinds
    }

    private var childMinds: [Mind] {
        return resolvedMind.children ?? []
    }

    private var memories: [Memory] {
        memoryService.memories(in: resolvedMind, includeCompleted: true)
    }

    private var filteredMemories: [Memory] {
        memoryService.memories(
            in: resolvedMind,
            statuses: [.active, .completed],
            includeCompleted: true,
            sort: sortStrategy
        ).filter { memory in
            guard !selectedTriggerTypes.isEmpty else { return true }
            return memory.triggers.contains { selectedTriggerTypes.contains($0.type) }
        }
    }

    private var pinnedMemories: [Memory] {
        filteredMemories.filter { $0.isPinned && $0.status == .active }
    }

    private var activeMemories: [Memory] {
        filteredMemories.filter { !$0.isPinned && $0.status == .active }
    }

    private var completedMemories: [Memory] {
        filteredMemories.filter { $0.status == .completed }
    }

    var body: some View {
        baseView
            .fullScreenCover(isPresented: $isSearching) {
                MemorySearchSheet(
                    mind: resolvedMind,
                    memoryService: memoryService,
                    mindService: mindService,
                    onSelectMemory: onSelectMemory
                )
            }
            .sheet(isPresented: $showMindComposer) {
                MindComposerView(environment: environment, mindToEdit: mindToEdit, parentMind: resolvedMind)
            }
            .onAppear {
                onMultiSelectionChange(false)
                onMindContextChange?(resolvedMind)
            }
            .onDisappear {
                onMindContextChange?(nil)
            }
            .onChange(of: isSearching) { _, newValue in
                onSearchActiveChange(newValue)
            }
    }

    private var baseView: some View {
        ScrollView {
            VStack(spacing: 0) {
                Text(resolvedMind.name)
                    .appLargeTitleStyle()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)

                FilterBadgesBar(selectedTriggerTypes: $selectedTriggerTypes, sortStrategy: $sortStrategy)

                if childMinds.isEmpty && memories.isEmpty {
                    EmptyStateView(
                        systemImage: "brain.fill",
                        title: "No Content",
                        message: "This mind doesn't have any content yet."
                    )
                } else {
                    VStack(spacing: 0) {
                        if !childMinds.isEmpty {
                            MindMindsSection(
                                childMinds: childMinds,
                                isExpanded: expandedSections.contains(.minds),
                                mindService: mindService,
                                activeMemoryCountProvider: activeMemoryCount,
                                onToggleExpanded: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if expandedSections.contains(.minds) {
                                            expandedSections.remove(.minds)
                                        } else {
                                            expandedSections.insert(.minds)
                                        }
                                    }
                                }
                            )
                        }

                        if !pinnedMemories.isEmpty {
                            MindMemorySection(
                                sectionType: .pinned,
                                memories: pinnedMemories,
                                isExpanded: expandedSections.contains(.pinned),
                                isMultiSelecting: isMultiSelecting,
                                selectedMemoryIDs: selectedMemoryIDs,
                                isPerformingBulkAction: isPerformingBulkAction,
                                onSelectMemory: onSelectMemory,
                                onEditMemory: onEditMemory,
                                onToggleSelection: toggleMemorySelection,
                                onToggleExpanded: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if expandedSections.contains(.pinned) {
                                            expandedSections.remove(.pinned)
                                        } else {
                                            expandedSections.insert(.pinned)
                                        }
                                    }
                                }
                            )
                        }

                        if !activeMemories.isEmpty {
                            MindMemorySection(
                                sectionType: .active,
                                memories: activeMemories,
                                isExpanded: expandedSections.contains(.active),
                                isMultiSelecting: isMultiSelecting,
                                selectedMemoryIDs: selectedMemoryIDs,
                                isPerformingBulkAction: isPerformingBulkAction,
                                onSelectMemory: onSelectMemory,
                                onEditMemory: onEditMemory,
                                onToggleSelection: toggleMemorySelection,
                                onToggleExpanded: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if expandedSections.contains(.active) {
                                            expandedSections.remove(.active)
                                        } else {
                                            expandedSections.insert(.active)
                                        }
                                    }
                                }
                            )
                        }

                        if !completedMemories.isEmpty {
                            MindMemorySection(
                                sectionType: .complete,
                                memories: completedMemories,
                                isExpanded: expandedSections.contains(.complete),
                                isMultiSelecting: isMultiSelecting,
                                selectedMemoryIDs: selectedMemoryIDs,
                                isPerformingBulkAction: isPerformingBulkAction,
                                onSelectMemory: onSelectMemory,
                                onEditMemory: onEditMemory,
                                onToggleSelection: toggleMemorySelection,
                                onToggleExpanded: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if expandedSections.contains(.complete) {
                                            expandedSections.remove(.complete)
                                        } else {
                                            expandedSections.insert(.complete)
                                        }
                                    }
                                }
                            )
                        }
                    }
                }
            }
        }
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
                    showMindComposer = true
                } label: {
                    Image(systemName: "plus")
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    isSearching = true
                } label: {
                    Image(systemName: "magnifyingglass")
                }
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    private func activeMemoryCount(_ mind: Mind) -> Int {
        let memories: [Memory]
        if mind.isAllMinds {
            memories = memoryService.memories
        } else {
            memories = memoryService.memories.filter { $0.mind?.id == mind.id }
        }

        return memories.filter { $0.status == .active }.count
    }

    private func toggleMemorySelection(_ memory: Memory) {
        let id = memory.id
        if selectedMemoryIDs.contains(id) {
            selectedMemoryIDs.remove(id)
        } else {
            selectedMemoryIDs.insert(id)
        }
    }
}
