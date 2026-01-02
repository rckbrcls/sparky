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
                                        MemoryCardView(
                                            memoryID: memory.id,
                                            memoryService: memoryService,
                                            onToggleCompletion: {
                                                Task { try? await memoryService.toggleCompletion(memoryID: memory.id) }
                                            }
                                        )
                                        .onTapGesture {
                                            onSelectMemory(memory)
                                            dismiss()
                                        }
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.bottom, 20)
                            }
                        }
                        .padding(.vertical)
                    }
                } else {
                    // Search Results
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(searchResults) { memory in
                                MemoryCardView(
                                    memoryID: memory.id,
                                    memoryService: memoryService,
                                    onToggleCompletion: {
                                        Task { try? await memoryService.toggleCompletion(memoryID: memory.id) }
                                    }
                                )
                                .onTapGesture {
                                    onSelectMemory(memory)
                                    dismiss()
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .onAppear {
                isSearchFieldFocused = true
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}
