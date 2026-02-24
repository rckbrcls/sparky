//
//  MindSection.swift
//  sparky
//

import SwiftUI

struct MindSection<Content: View>: View {
    let sectionType: MindSectionType
    let count: Int
    let isExpanded: Bool
    let onToggleExpanded: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MindSectionHeaderButton(
                sectionType: sectionType,
                count: count,
                isExpanded: isExpanded,
                onToggle: onToggleExpanded
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 16)
            .padding(.bottom, 4)
            .padding(.horizontal, 20)

            if isExpanded {
                content()
            }
        }
    }
}

struct MindMemorySection: View {
    let sectionType: MindSectionType
    let memories: [Memory]
    let isExpanded: Bool
    let isMultiSelecting: Bool
    let selectedMemoryIDs: Set<Memory.ID>
    let isPerformingBulkAction: Bool
    let onSelectMemory: (Memory) -> Void
    let onEditMemory: ((Memory) -> Void)?
    let onToggleSelection: (Memory) -> Void
    let onToggleExpanded: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MindSectionHeaderButton(
                sectionType: sectionType,
                count: memories.count,
                isExpanded: isExpanded,
                onToggle: onToggleExpanded
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 16)
            .padding(.bottom, 4)
            .padding(.horizontal, 20)

            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(memories) { memory in
                        MemoryListItemButton(
                            memory: memory,
                            isMultiSelecting: isMultiSelecting,
                            isSelected: selectedMemoryIDs.contains(memory.id),
                            isDisabled: isPerformingBulkAction,
                            onSelect: onSelectMemory,
                            onToggleSelection: onToggleSelection,
                            onEditMemory: onEditMemory
                        )
                        .padding(.vertical, 8)
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
    }
}

struct MindMindsSection: View {
    let childMinds: [Mind]
    let isExpanded: Bool
    let mindService: MindService
    let activeMemoryCounts: [Mind.ID: Int]
    let onEditMind: ((Mind) -> Void)?
    let onToggleExpanded: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MindSectionHeaderButton(
                sectionType: .minds,
                count: childMinds.count,
                isExpanded: isExpanded,
                onToggle: onToggleExpanded
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 16)
            .padding(.bottom, 4)
            .padding(.horizontal, 20)

            if isExpanded {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(childMinds) { childMind in
                        NavigationLink(value: childMind) {
                            MindGridItemView(
                                mind: childMind,
                                count: childMind.children?.count ?? 0,
                                activeCount: activeMemoryCounts[childMind.id, default: 0],
                                mindService: mindService,
                                onEdit: onEditMind
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .accessibilityHint("Opens details for \(childMind.name)")
                    }
                }
                .padding(.top, 8)
                .padding(.horizontal, 20)
            }
        }
    }
}
