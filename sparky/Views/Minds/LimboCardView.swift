//
//  LimboCardView.swift
//  sparky
//

import SwiftUI

struct LimboCardView: View {
    let mind: Mind
    let count: Int
    let completedCount: Int
    let activeCount: Int
    let memoryService: MemoryService?
    let mindService: MindService?

    init(
        mind: Mind,
        count: Int,
        completedCount: Int = 0,
        activeCount: Int = 0,
        memoryService: MemoryService? = nil,
        mindService: MindService? = nil
    ) {
        self.mind = mind
        self.count = count
        self.completedCount = completedCount
        self.activeCount = activeCount
        self.memoryService = memoryService
        self.mindService = mindService
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: mind.iconName ?? "tray")
                    .foregroundStyle(mindColor)
                    .frame(width: 32, height: 32)
                    .glassEffect(.regular.tint(mindColor.opacity(0.15)))

                Text(mind.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }

            Spacer()

            if activeCount > 0 {
                Text("\(activeCount)")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .frame(height: 20)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(mindColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(darkerBorderColor(for: mindColor), lineWidth: 1)
                            )
                    )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 100)
        .cardStyle()
    }

    private var mindColor: Color {
        .accentColor
    }

    private func darkerBorderColor(for color: Color) -> Color {
        // Semantic, platform-neutral border treatment.
        color.opacity(0.65)
    }
}
