//
//  MemoryCardMetaBadge.swift
//  sparky
//

import SwiftUI

struct MemoryCardMetaBadge: View {
    let systemImage: String
    let text: String
    var color: Color = .secondary
    var isCompleted: Bool = false

    var body: some View {
        let resolvedColor = isCompleted ? Color.secondary : color

        return HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 9, weight: .semibold))
                .symbolRenderingMode(.monochrome)
            Text(text)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundStyle(resolvedColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(resolvedColor.opacity(0.16))
        )
        .lineLimit(1)
    }
}
