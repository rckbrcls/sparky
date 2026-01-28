//
//  MindsTab.swift
//  i-cant-miss
//
//  Created by Antigravity on 2026-01-28.
//

import SwiftUI

struct MindsTab: View {
    @ObservedObject var mindService: MindService
    @ObservedObject var lobeService: LobeService
    @ObservedObject var memoryService: MemoryService

    let onEditMind: ((MindModel) -> Void)?

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
                    ForEach(displayMinds) { mind in
                        NavigationLink(value: mind) {
                            MindGridItemView(
                                mind: mind,
                                count: lobeCounts(for: mind),
                                activeCount: activeMemoryCount(for: mind),
                                mindService: mindService,
                                lobeService: lobeService,
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

    private var displayMinds: [MindModel] {
        let sortedMinds = mindService.minds
            .filter { !$0.isDefault && !$0.isAllMinds }
            .sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder {
                    return lhs.sortOrder < rhs.sortOrder
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        return [MindModel.allMinds] + sortedMinds
    }

    private func lobeCounts(for mind: MindModel) -> Int {
        if mind.isAllMinds {
            return lobeService.lobes.count
        } else {
            return lobeService.lobes.filter { lobe in
                guard let mindID = lobe.mind?.id else { return false }
                return mindID == mind.id
            }.count
        }
    }

    private func activeMemoryCount(for mind: MindModel) -> Int {
        let memories: [MemoryModel]
        if mind.isAllMinds {
            memories = memoryService.memories
        } else {
            let mindID = mind.id
            memories = memoryService.memories.filter { memory in
                guard let memoryLobeMindID = memory.lobe?.mind?.id else { return false }
                return memoryLobeMindID == mindID
            }
        }

        return memories.filter { $0.status == .active }.count
    }
}
