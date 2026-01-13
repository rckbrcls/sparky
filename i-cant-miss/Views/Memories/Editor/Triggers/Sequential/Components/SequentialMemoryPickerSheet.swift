//
//  SequentialMemoryPickerSheet.swift
//  i-cant-miss
//
//  Created by Codex on 02/01/26.
//

import SwiftUI

struct SequentialMemoryPickerSheet: View {
    @ObservedObject var viewModel: MemoryEditorViewModel
    let excludedMemoryIDs: Set<UUID>
    let onSelect: (MemoryModel) -> Void

    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    private var spaceService: SpaceService {
        viewModel.environment.spaceService
    }

    private var memoryService: MemoryService {
        viewModel.environment.memoryService
    }

    var body: some View {
        NavigationStack {
            List {
                if !searchText.isEmpty {
                    activeSearchResults
                } else {
                    spacesList
                }
            }
            .listStyle(.plain)
            .searchable(text: $searchText, prompt: "Search memories")
            .navigationTitle("Select Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var spacesList: some View {
        Section {
            ForEach(displaySpaces) { space in
                NavigationLink {
                    SequentialSpaceDetailView(
                        space: space,
                        viewModel: viewModel,
                        excludedMemoryIDs: excludedMemoryIDs,
                        onSelect: { memory in
                            onSelect(memory)
                            dismiss()
                        }
                    )
                } label: {
                    HStack {
                        Image(systemName: space.iconName ?? "square.grid.2x2")
                            .foregroundStyle(Color(hex: space.colorHex ?? "") ?? .gray)
                            .frame(width: 24, height: 24)

                        Text(space.name)
                            .foregroundStyle(.primary)

                        Spacer()

                        Text("\(memoryCount(for: space))")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .cardStyle()
                }
                .listRowInsets(.init(top: 8, leading: 20, bottom: 8, trailing: 20))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        } header: {
            Text("Spaces")
        }
    }

    private var activeSearchResults: some View {
        Section {
            let matches = filteredMemories(query: searchText)
            if matches.isEmpty {
                Text("No matching memories found")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(matches) { memory in
                    Button {
                        onSelect(memory)
                        dismiss()
                    } label: {
                        SequentialMemoryPickerRow(memory: memory)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(.init(top: 8, leading: 20, bottom: 8, trailing: 20))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
        } header: {
            Text("Search Results")
        }
    }

    private var displaySpaces: [SpaceModel] {
        let sortedSpaces = spaceService.spaces
            .sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder {
                    return lhs.sortOrder < rhs.sortOrder
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        return [SpaceModel.allSpaces] + sortedSpaces
    }

    private func memoryCount(for space: SpaceModel) -> Int {
        if space.isAllSpaces {
            return memoryService.memories.filter { !isExcluded($0) }.count
        }
        return memoryService.memories.filter { memory in
            guard let spaceID = memory.space?.id else { return false }
            return spaceID == space.id && !isExcluded(memory)
        }.count
    }

    private func filteredMemories(query: String) -> [MemoryModel] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        return memoryService.memories.filter { memory in
            guard !isExcluded(memory) else { return false }
            return memory.title.localizedCaseInsensitiveContains(trimmed) ||
                   (memory.space?.name ?? "").localizedCaseInsensitiveContains(trimmed)
        }
    }

    private func isExcluded(_ memory: MemoryModel) -> Bool {
        if let editingID = viewModel.editingMemoryID, memory.id == editingID {
            return true
        }
        return excludedMemoryIDs.contains(memory.id)
    }
}

private struct SequentialSpaceDetailView: View {
    let space: SpaceModel
    @ObservedObject var viewModel: MemoryEditorViewModel
    let excludedMemoryIDs: Set<UUID>
    let onSelect: (MemoryModel) -> Void

    @State private var searchText = ""

    private var memories: [MemoryModel] {
        let all = viewModel.environment.memoryService.memories
        let filtered: [MemoryModel]

        if space.isAllSpaces {
            filtered = all
        } else {
            filtered = all.filter { $0.space?.id == space.id }
        }

        // Filter out excluded and apply search
        return filtered.filter { memory in
            if let editingID = viewModel.editingMemoryID, memory.id == editingID { return false }
            if excludedMemoryIDs.contains(memory.id) { return false }

            if !searchText.isEmpty {
                return memory.title.localizedCaseInsensitiveContains(searchText)
            }
            return true
        }.sorted { $0.updatedAt > $1.updatedAt }
    }

    var body: some View {
        List {
            if memories.isEmpty {
                Text("No available memories")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(memories) { memory in
                    Button {
                        onSelect(memory)
                    } label: {
                        SequentialMemoryPickerRow(memory: memory)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(.init(top: 8, leading: 20, bottom: 8, trailing: 20))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
        }
        .listStyle(.plain)
        .searchable(text: $searchText, prompt: "Search in \(space.name)")
        .navigationTitle(space.name)
    }
}

private struct SequentialMemoryPickerRow: View {
    let memory: MemoryModel

    var body: some View {
        HStack(spacing: 12) {
            let spaceIcon = memory.space?.iconName ?? "square.grid.2x2"
            let spaceColor = memory.space?.colorHex.flatMap { Color(hex: $0) } ?? .gray

            Image(systemName: spaceIcon)
                .foregroundStyle(spaceColor)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(memory.title)
                    .foregroundStyle(memory.isCompleted ? .secondary : .primary)
                    .strikethrough(memory.isCompleted, color: .secondary)

                if let spaceName = memory.space?.name {
                    Text(spaceName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if memory.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .cardStyle()
    }
}
