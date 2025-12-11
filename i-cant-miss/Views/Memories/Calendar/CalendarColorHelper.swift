//
//  CalendarColorHelper.swift
//  i-cant-miss
//
//  Created by Codex on 09/03/24.
//

import SwiftUI

struct CalendarColorHelper {
    static func color(for memory: MemoryModel) -> Color {
        // Check space color first
        if let space = memory.space,
           let colorHex = space.colorHex,
           let color = Color(hex: colorHex) {
            return color
        }

        // Fallback to default color
        return .accent
    }

    static func indicatorColor(for memories: [MemoryModel]) -> Color {
        guard !memories.isEmpty else { return .clear }

        // If all have the same space color, use that color
        let colors = memories.map { color(for: $0) }
        if let firstColor = colors.first,
           colors.allSatisfy({ $0 == firstColor }) {
            return firstColor
        }

        // Fallback to default color
        return .accent
    }
}
