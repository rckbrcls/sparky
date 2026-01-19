//
//  LimboCardView.swift
//  i-cant-miss
//

import SwiftUI

struct LimboCardView: View {
    let space: SpaceModel
    let count: Int
    let completedCount: Int
    let activeCount: Int
    let spaceService: SpaceService?
    let memoryService: MemoryService?
    let mindService: MindService?

    init(
        space: SpaceModel,
        count: Int,
        completedCount: Int = 0,
        activeCount: Int = 0,
        spaceService: SpaceService? = nil,
        memoryService: MemoryService? = nil,
        mindService: MindService? = nil
    ) {
        self.space = space
        self.count = count
        self.completedCount = completedCount
        self.activeCount = activeCount
        self.spaceService = spaceService
        self.memoryService = memoryService
        self.mindService = mindService
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: space.iconName ?? "tray")
                    .foregroundStyle(spaceColor)
                    .frame(width: 32, height: 32)
                    .glassEffect(.regular.tint(spaceColor.opacity(0.15)))

                Spacer()

                if activeCount > 0 {
                    Text("\(activeCount)")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .frame(height: 20)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(spaceColor)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(darkerBorderColor(for: spaceColor), lineWidth: 1)
                                )
                        )
                }
            }
            .frame(maxWidth: .infinity)
            
            Text(space.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .lineLimit(2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 60)
        .cardStyle()
    }

    private var spaceColor: Color {
        .purple
    }

    private func darkerBorderColor(for color: Color) -> Color {
        let uiColor = UIColor(color)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        if uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
            return Color(hue: hue, saturation: saturation, brightness: max(0, brightness * 0.7), opacity: alpha)
        }
        
        return color.opacity(0.6)
    }
}
