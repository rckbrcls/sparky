//
//  MemorySearchSheet.swift
//  i-cant-miss
//
//  Created by Codex on 02/01/26.
//

import SwiftUI

struct MemorySearchSheet: View {
    let lobe: Space
    @ObservedObject var memoryService: MemoryService

    let onSelectMemory: (Memory) -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var environment: AppEnvironment

    @State private var searchText = ""
    @FocusState private var isSearchFieldFocused: Bool

    private var isAllLobe: Bool {
        lobeService.lobe(id: lobe.id)?.isAllSpaces ?? lobe.isAllSpaces
    }

    private var resolvedLobe: Space {
        lobeService.lobe(id: lobe.id) ?? lobe
    }

    private var isAllLobeForMind: Bool {
        resolvedLobe.isAllLobeForMind
    }

    private var isInboxLobe: Bool {
        resolvedLobe.isInbox
    }

    private var isLimboLobe: Bool {
        resolvedLobe.isLimbo
    }

    // We need lobeService to resolve the lobe correctly if it updates,
    // although for search strictly we might just trust the passed lobe or resolvedLobe.
    // Let's grab it from init.
    // LobeDetailView has it, let's pass it.
    @ObservedObject var lobeService: LobeService

    // MARK: - Context Menu Actions

    private func togglePin(for memory: Memory) async {
        do {
            try await environment.memoryService.togglePin(memoryID: memory.id)
        } catch {
            // Handle error silently
        }
    }

    private func toggleCompletion(for memory: Memory) async {
        do {
            try await environment.memoryService.toggleCompletion(memoryID: memory.id)
        } catch {
            // Handle error silently
        }
    }

    private func deleteMemory(_ memory: Memory) async {
        do {
            try await environment.memoryService.deleteMemory(id: memory.id)
        } catch {
            // Handle error silently
        }
    }

    private func moveMemory(_ memory: Memory, to lobeID: UUID?) async {
        let currentID = memory.lobe?.id
        guard currentID != lobeID else { return }

        do {
            let targetLobe = lobeID.flatMap { environment.lobeService.lobe(id: $0) }
            try await environment.memoryService.moveMemory(memory.id, to: targetLobe)
        } catch {
            // Handle error silently
        }
    }

    private func setStatus(for memory: Memory, to status: MemoryStatus) async {
        guard status != memory.status else { return }
        do {
            try await environment.memoryService.setStatus(memoryID: memory.id, status: status)
        } catch {
            // Handle error silently
        }
    }

    @ViewBuilder
    private func memoryCard(for memory: Memory) -> some View {
        MemoryCardView(
            memoryID: memory.id,
            memoryService: memoryService,
            onTogglePin: { Task { await togglePin(for: memory) } },
            onToggleCompletion: { Task { await toggleCompletion(for: memory) } },
            onDelete: { Task { await deleteMemory(memory) } },
            onMoveToLobe: { lobeID in Task { await moveMemory(memory, to: lobeID) } },
            onUpdateStatus: { status in Task { await setStatus(for: memory, to: status) } }
        )
        .onTapGesture {
            onSelectMemory(memory)
            dismiss()
        }
    }

    private var recentMemories: [Memory] {
        let allInLobe: [Memory]
        
        if isAllLobe {
            allInLobe = memoryService.memories(
                in: nil,
                statuses: [.active],
                includeCompleted: false,
                sort: .createdAtDescending
            )
        } else if isInboxLobe || isLimboLobe {
            let unsorted = memoryService.memories.filter { memory in
                memory.lobe == nil && memory.status == .active
            }
            allInLobe = memoryService.sortedMemories(unsorted, using: .createdAtDescending)
        } else if isAllLobeForMind {
            guard let mindID = resolvedLobe.mind?.id else {
                return []
            }
            let unsorted = memoryService.memories.filter { memory in
                guard let memoryLobeMindID = memory.lobe?.mind?.id else { return false }
                return memoryLobeMindID == mindID && memory.status == .active
            }
            allInLobe = memoryService.sortedMemories(unsorted, using: .createdAtDescending)
        } else {
            allInLobe = memoryService.memories(
                in: resolvedLobe,
                statuses: [.active],
                includeCompleted: false,
                sort: .createdAtDescending
            )
        }
        
        return Array(allInLobe.prefix(5))
    }

    private var searchResults: [Memory] {
        guard !searchText.isEmpty else { return [] }
        
        let allInLobe: [Memory]
        
        if isAllLobe {
            allInLobe = memoryService.memories(
                in: nil,
                statuses: [],
                includeCompleted: true,
                sort: .updatedAtDescending
            )
        } else if isInboxLobe || isLimboLobe {
            let unsorted = memoryService.memories.filter { memory in
                memory.lobe == nil
            }
            allInLobe = memoryService.sortedMemories(unsorted, using: .updatedAtDescending)
        } else if isAllLobeForMind {
            guard let mindID = resolvedLobe.mind?.id else {
                return []
            }
            let unsorted = memoryService.memories.filter { memory in
                guard let memoryLobeMindID = memory.lobe?.mind?.id else { return false }
                return memoryLobeMindID == mindID
            }
            allInLobe = memoryService.sortedMemories(unsorted, using: .updatedAtDescending)
        } else {
            allInLobe = memoryService.memories(
                in: resolvedLobe,
                statuses: [],
                includeCompleted: true,
                sort: .updatedAtDescending
            )
        }

        let lowercasedSearch = searchText.lowercased()
        return allInLobe.filter { memory in
            if memory.title.lowercased().contains(lowercasedSearch) {
                return true
            }
            if let note = memory.note, note.lowercased().contains(lowercasedSearch) {
                return true
            }
            return false
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                HStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Search memories...", text: $searchText)
                            .textFieldStyle(.plain)
                            .focused($isSearchFieldFocused)
                            .submitLabel(.search)

                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(12)
                    .glassEffect()
                }
                .padding()

                if searchText.isEmpty {
                    // Recent Memories Section
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            if !recentMemories.isEmpty {
                                Text("Recent Memories")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal)

                                VStack(spacing: 16) {
                                    ForEach(recentMemories) { memory in
                                        memoryCard(for: memory)
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.bottom, 20)
                            }
                        }
                        .padding(.vertical)
                    }
                    .scrollDismissesKeyboard(.interactively)
                } else {
                    // Search Results
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(searchResults) { memory in
                                memoryCard(for: memory)
                            }
                        }
                        .padding()
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .fontWeight(.medium)
                    }
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .onAppear {
                isSearchFieldFocused = true
            }
        }
    }
}
