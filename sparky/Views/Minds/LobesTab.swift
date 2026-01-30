//
//  LobesTab.swift
//  sparky
//
//  Created by Antigravity on 2026-01-28.
//

import SwiftUI

struct LobesTab: View {
    @ObservedObject var lobeService: LobeService
    @ObservedObject var mindService: MindService
    @ObservedObject var memoryService: MemoryService

    let onEditLobe: ((Space) -> Void)?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Lobes")
                    .appLargeTitleStyle()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                LazyVGrid(columns: columns, spacing: 12) {
                    // Lobe Limbo - shows memories without lobe
                    NavigationLink(value: Space.limbo) {
                        LimboCardView(
                            lobe: Space.limbo,
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

                    // All Lobes card - shows all memories
                    NavigationLink(value: Space.allSpaces) {
                        LobeGridItemView(
                            lobe: Space.allSpaces,
                            count: memoryCounts(for: Space.allSpaces).total,
                            completedCount: memoryCounts(for: Space.allSpaces).completed,
                            activeCount: activeMemoryCount(for: Space.allSpaces),
                            lobeService: lobeService,
                            memoryService: memoryService,
                            mindService: mindService,
                            onEdit: nil,
                            showOnlyRemaining: true
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityHint("Opens details for all lobes")

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
                .padding(.bottom, 100) // Extra padding for bottom inset
            }
            .padding(.top, 16)
        }
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
    }

    private var displayLobesWithoutMind: [Space] {
        lobeService.lobes
            .filter { lobe in
                guard !lobe.isAllSpaces else { return false }
                guard !lobe.isAllSpaceForMind else { return false }
                return lobe.mind == nil
            }
            .sorted { lhs, rhs in
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
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

    private func memoryCounts(for lobe: Space) -> (completed: Int, total: Int) {
        let memories: [Memory]
        if lobe.isAllSpaces {
            memories = memoryService.memories
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
        } else {
            memories = memoryService.memories.filter { memory in
                guard let lobeID = memory.lobe?.id else { return false }
                return lobeID == lobe.id
            }
        }
        return memories.filter { $0.status == .active }.count
    }
}
