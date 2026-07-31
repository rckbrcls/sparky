//
//  MindMindsGrid.swift
//  sparky
//

import SwiftUI

struct MindMindsGrid: View {
    let childMinds: [Mind]
    let mindService: MindService
    let activeMemoryCounts: [Mind.ID: Int]
    let onEditMind: ((Mind) -> Void)?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
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
                .buttonStyle(.plain)
                .accessibilityHint("Opens details for \(childMind.name)")
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .padding(.horizontal, 20)
    }
}
