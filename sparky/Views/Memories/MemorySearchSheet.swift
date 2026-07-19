//
//  MemorySearchSheet.swift
//  sparky
//
//  Created by Codex on 02/01/26.
//

import SwiftUI

struct MemorySearchSheet: View {
    let mind: Mind
    @ObservedObject var memoryService: MemoryService
    @ObservedObject var mindService: MindService

    let onSelectMemory: (Memory) -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var environment: AppEnvironment

    @State private var searchText = ""
    @State private var memoryPendingRecurringCompletion: Memory?
    @FocusState private var isSearchFieldFocused: Bool

    private var isAllMinds: Bool {
        mind.isAllMinds
    }

    private var isLimbo: Bool {
        mind.isLimbo
    }

    // MARK: - Context Menu Actions

    private func togglePin(for memory: Memory) async {
        do {
            try await environment.memoryService.togglePin(memoryID: memory.id)
        } catch {
            // Handle error silently
        }
    }

    private func toggleCompletion(for memory: Memory) async {
        if memory.hasRecurringTriggers && !memory.isCompleted {
            memoryPendingRecurringCompletion = memory
            return
        }
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

    private func moveMemory(_ memory: Memory, to mindID: UUID?) async {
        let currentID = memory.mind?.id
        guard currentID != mindID else { return }

        do {
            let targetMind = mindID.flatMap { environment.mindService.mind(id: $0) }
            try await environment.memoryService.moveMemory(memory.id, to: targetMind)
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
            onMoveToMind: { mindID in Task { await moveMemory(memory, to: mindID) } },
            onUpdateStatus: { status in Task { await setStatus(for: memory, to: status) } }
        )
        .onTapGesture {
            onSelectMemory(memory)
            dismiss()
        }
    }

    private var recentMemories: [Memory] {
        let allInMind: [Memory]

        if isAllMinds {
            allInMind = memoryService.memories(
                in: nil,
                statuses: [.active],
                includeCompleted: false,
                sort: .createdAtDescending
            )
        } else if isLimbo {
            let unsorted = memoryService.memories.filter { memory in
                memory.mind == nil && memory.status == .active
            }
            allInMind = memoryService.sortedMemories(unsorted, using: .createdAtDescending)
        } else {
            let descendantIDs = mind.allDescendantIDs
            let unsorted = memoryService.memories.filter { memory in
                guard let memMindID = memory.mind?.id else { return false }
                return descendantIDs.contains(memMindID) && memory.status == .active
            }
            allInMind = memoryService.sortedMemories(unsorted, using: .createdAtDescending)
        }

        return Array(allInMind.prefix(5))
    }

    private var searchResults: [Memory] {
        guard !searchText.isEmpty else { return [] }

        let allInMind: [Memory]

        if isAllMinds {
            allInMind = memoryService.memories(
                in: nil,
                statuses: [],
                includeCompleted: true,
                sort: .updatedAtDescending
            )
        } else if isLimbo {
            let unsorted = memoryService.memories.filter { memory in
                memory.mind == nil
            }
            allInMind = memoryService.sortedMemories(unsorted, using: .updatedAtDescending)
        } else {
            let descendantIDs = mind.allDescendantIDs
            let unsorted = memoryService.memories.filter { memory in
                guard let memMindID = memory.mind?.id else { return false }
                return descendantIDs.contains(memMindID)
            }
            allInMind = memoryService.sortedMemories(unsorted, using: .updatedAtDescending)
        }

        let lowercasedSearch = searchText.lowercased()
        return allInMind.filter { memory in
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
                .liquidGlass(in: RoundedRectangle(cornerRadius: 22, style: .continuous))
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
            .inlinePhoneNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .fontWeight(.medium)
                    }
                }
            }
            .background(Color.Theme.groupedBackground)
            .onAppear {
                isSearchFieldFocused = true
            }
            .alert("End Recurrence?", isPresented: Binding(
                get: { memoryPendingRecurringCompletion != nil },
                set: { if !$0 { memoryPendingRecurringCompletion = nil } }
            )) {
                Button("Complete", role: .destructive) {
                    if let memory = memoryPendingRecurringCompletion {
                        Task { try? await environment.memoryService.toggleCompletion(memoryID: memory.id) }
                    }
                    memoryPendingRecurringCompletion = nil
                }
                Button("Cancel", role: .cancel) {
                    memoryPendingRecurringCompletion = nil
                }
            } message: {
                Text("This memory repeats. Completing it will end the recurrence and remove future triggers.")
            }
        }
    }
}
