//
//  CalendarColorHelper.swift
//  i-cant-miss
//
//  Created by Codex on 09/03/24.
//

import SwiftUI

struct CalendarColorHelper {
    static func color(for memory: MemoryModel) -> Color {
        // Prioridade primeiro
        if let priority = memory.priority {
            switch priority {
            case .high:
                return .red
            case .medium:
                return .orange
            case .low:
                return .yellow
            case .noPriority:
                break
            }
        }

        // Depois espaço
        if let space = memory.space,
           let colorHex = space.colorHex,
           let color = Color(hex: colorHex) {
            return color
        }

        // Fallback para cor padrão
        return .accent
    }

    static func indicatorColor(for memories: [MemoryModel]) -> Color {
        guard !memories.isEmpty else { return .clear }

        // Se todas têm a mesma prioridade/espaço, usar essa cor
        let colors = memories.map { color(for: $0) }
        if let firstColor = colors.first,
           colors.allSatisfy({ $0 == firstColor }) {
            return firstColor
        }

        // Se há memórias de alta prioridade, usar vermelho
        if memories.contains(where: { $0.priority == .high }) {
            return .red
        }

        // Se há memórias de média prioridade, usar laranja
        if memories.contains(where: { $0.priority == .medium }) {
            return .orange
        }

        // Fallback para cor padrão
        return .accent
    }
}

