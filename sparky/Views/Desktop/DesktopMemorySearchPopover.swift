#if os(macOS)

import SwiftUI

struct DesktopMemorySearchPopover: View {
    @ObservedObject var memoryService: MemoryService
    let onSelect: (Memory) -> Void

    @State private var query = ""
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Search Memories", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .padding(.horizontal, 14)
                .frame(height: 42)
                .background(Color.Theme.elementBackground)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.Theme.separator)
                        .frame(height: 1)
                }
                .focused($isSearchFieldFocused)

            if displayedMemories.isEmpty {
                ContentUnavailableView(
                    query.isEmpty ? "No Recent Memories" : "No Results",
                    systemImage: "magnifyingglass",
                    description: Text(
                        query.isEmpty
                            ? "Memories you edit will appear here."
                            : "Try a different title or note."
                    )
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        Text(query.isEmpty ? "Recent" : "Results")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.Theme.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.top, 10)

                        ForEach(displayedMemories, id: \.id) { memory in
                            Button {
                                onSelect(memory)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: memory.status == .completed ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(
                                            memory.status == .completed
                                                ? Color.Theme.textTertiary
                                                : CalendarColorHelper.color(for: memory)
                                        )

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(memory.title)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(Color.Theme.textPrimary)
                                            .lineLimit(1)

                                        if let note = memory.note, !note.isEmpty {
                                            Text(note)
                                                .font(.caption)
                                                .foregroundStyle(Color.Theme.textSecondary)
                                                .lineLimit(1)
                                        }
                                    }

                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 12)
                                .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
        }
        .frame(width: 360, height: 420)
        .background(Color.Theme.secondaryBackground)
        .onAppear {
            isSearchFieldFocused = true
        }
    }

    private var displayedMemories: [Memory] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedQuery.isEmpty {
            return Array(
                memoryService.memories
                    .sorted {
                        ($0.updatedAt ?? $0.createdAt ?? .distantPast)
                            > ($1.updatedAt ?? $1.createdAt ?? .distantPast)
                    }
                    .prefix(8)
            )
        }

        return memoryService.memories
            .filter { memory in
                memory.title.localizedCaseInsensitiveContains(trimmedQuery)
                    || memory.note?.localizedCaseInsensitiveContains(trimmedQuery) == true
            }
            .sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
    }
}

#endif
