//
//  MindsTab.swift
//  sparky
//
//  Created by Antigravity on 2026-01-28.
//

import SwiftUI

struct MindsTab: View {
    @ObservedObject var mindService: MindService
    @ObservedObject var memoryService: MemoryService

    let onEditMind: ((Mind) -> Void)?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Minds")
                    .appLargeTitleStyle()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(displayMinds, id: \.id) { mind in
                        NavigationLink(value: mind) {
                            MindGridItemView(
                                mind: mind,
                                count: childMindCount(for: mind),
                                activeCount: activeMemoryCount(for: mind),
                                mindService: mindService,
                                onEdit: onEditMind
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .accessibilityHint("Opens details for \(mind.name)")
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

    private var displayMinds: [Mind] {
        let virtualMinds = [Mind.allMinds, Mind.limbo]
        let persistedMinds = mindService.minds
            .filter { $0.parent == nil }
            .sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder {
                    return lhs.sortOrder < rhs.sortOrder
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        return virtualMinds + persistedMinds
    }

    private func childMindCount(for mind: Mind) -> Int {
        return mind.children?.count ?? 0
    }

    private func activeMemoryCount(for mind: Mind) -> Int {
        let memories: [Memory]
        if mind.isAllMinds {
            memories = memoryService.memories
        } else if mind.isLimbo {
            memories = memoryService.memories.filter { $0.mind == nil }
        } else {
            let descendantIDs = mind.allDescendantIDs
            memories = memoryService.memories.filter { memory in
                guard let mindID = memory.mind?.id else { return false }
                return descendantIDs.contains(mindID)
            }
        }

        return memories.filter { $0.status == .active }.count
    }
}
