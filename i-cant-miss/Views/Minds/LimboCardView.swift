//
//  LimboCardView.swift
//  i-cant-miss
//

import SwiftUI

struct LimboCardView: View {
    let lobe: Space
    let count: Int
    let completedCount: Int
    let activeCount: Int
    let lobeService: LobeService?
    let memoryService: MemoryService?
    let mindService: MindService?

    init(
        lobe: Space,
        count: Int,
        completedCount: Int = 0,
        activeCount: Int = 0,
        lobeService: LobeService? = nil,
        memoryService: MemoryService? = nil,
        mindService: MindService? = nil
    ) {
        self.lobe = lobe
        self.count = count
        self.completedCount = completedCount
        self.activeCount = activeCount
        self.lobeService = lobeService
        self.memoryService = memoryService
        self.mindService = mindService
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: lobe.iconName ?? "tray")
                    .foregroundStyle(lobeColor)
                    .frame(width: 32, height: 32)
                    .glassEffect(.regular.tint(lobeColor.opacity(0.15)))

                Text(lobe.name)
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
                            .fill(lobeColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(darkerBorderColor(for: lobeColor), lineWidth: 1)
                            )
                    )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 100)
        .cardStyle()
    }

    private var lobeColor: Color {
        .accentColor
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
