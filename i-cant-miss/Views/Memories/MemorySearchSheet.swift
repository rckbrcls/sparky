//
//  MemorySearchSheet.swift
//  i-cant-miss
//
//  Created by Codex on 02/01/26.
//

import SwiftUI

struct MemorySearchSheet: View {
    let space: SpaceModel
    @ObservedObject var memoryService: MemoryService

    let onSelectMemory: (MemoryModel) -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var environment: AppEnvironment

    @State private var searchText = ""
    @FocusState private var isSearchFieldFocused: Bool

    private var isAllSpace: Bool {
        spaceService.space(id: space.id)?.isAllSpaces ?? space.isAllSpaces
    }

    private var resolvedSpace: SpaceModel {
        spaceService.space(id: space.id) ?? space
    }

    // We need spaceService to resolve the space correctly if it updates,
    // although for search strictly we might just trust the passed space or resolvedSpace.
    // Let's grab it from init.
    // SpaceDetailView has it, let's pass it.
    @ObservedObject var spaceService: SpaceService

    // MARK: - Context Menu Actions

    private func togglePin(for memory: MemoryModel) async {
        do {
            try await environment.memoryService.togglePin(memoryID: memory.id)
        } catch {
            // Handle error silently
        }
    }

    private func toggleCompletion(for memory: MemoryModel) async {
        do {
            try await environment.memoryService.toggleCompletion(memoryID: memory.id)
        } catch {
            // Handle error silently
        }
    }

    private func deleteMemory(_ memory: MemoryModel) async {
        do {
            try await environment.memoryService.deleteMemory(id: memory.id)
        } catch {
            // Handle error silently
        }
    }

    private func moveMemory(_ memory: MemoryModel, to spaceID: UUID?) async {
        let currentID = memory.space?.id
        guard currentID != spaceID else { return }

        do {
            let targetSpace = spaceID.flatMap { environment.spaceService.space(id: $0) }
            try await environment.memoryService.moveMemory(memory.id, to: targetSpace)
        } catch {
            // Handle error silently
        }
    }

    private func setStatus(for memory: MemoryModel, to status: MemoryStatus) async {
        guard status != memory.status else { return }
        do {
            try await environment.memoryService.setStatus(memoryID: memory.id, status: status)
        } catch {
            // Handle error silently
        }
    }

    @ViewBuilder
    private func memoryCard(for memory: MemoryModel) -> some View {
        MemoryCardView(
            memoryID: memory.id,
            memoryService: memoryService,
            onTogglePin: { Task { await togglePin(for: memory) } },
            onToggleCompletion: { Task { await toggleCompletion(for: memory) } },
            onDelete: { Task { await deleteMemory(memory) } },
            onMoveToSpace: { spaceID in Task { await moveMemory(memory, to: spaceID) } },
            onUpdateStatus: { status in Task { await setStatus(for: memory, to: status) } }
        )
        .onTapGesture {
            onSelectMemory(memory)
            dismiss()
        }
    }

    private var recentMemories: [MemoryModel] {
        // Fetch top 10 most recently updated memories in this space
        let allInSpace = memoryService.memories(
            in: isAllSpace ? nil : resolvedSpace,
            statuses: [], // All statuses? Or just active?
            // Usually "Recent" implies things I interacted with.
            // Let's include everything for now, or maybe just active/completed?
            // The user said "recent memories", usually implies updated or accessed.
            includeCompleted: true,
            sort: .updatedAtDescending
        )
        return Array(allInSpace.prefix(3))
    }

    private var searchResults: [MemoryModel] {
        guard !searchText.isEmpty else { return [] }
        let allInSpace = memoryService.memories(
            in: isAllSpace ? nil : resolvedSpace,
            statuses: [],
            includeCompleted: true,
            sort: .updatedAtDescending
        )

        let lowercasedSearch = searchText.lowercased()
        return allInSpace.filter { memory in
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
