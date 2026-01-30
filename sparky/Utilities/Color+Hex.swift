//
//  Color+Hex.swift
//  sparky
//
//  Created by Codex on 13/10/25.
//

import SwiftUI

extension Color {
    init?(hex: String) {
        let sanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard sanitized.count == 6,
              let value = UInt64(sanitized, radix: 16) else {
            return nil
        }

        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0

        self.init(red: red, green: green, blue: blue)
    }

    func toHex() -> String? {
        guard let components = UIColor(self).cgColor.components,
              components.count >= 3 else {
            return nil
        }

        let r = Int(components[0] * 255.0)
        let g = Int(components[1] * 255.0)
        let b = Int(components[2] * 255.0)

        return String(format: "#%02X%02X%02X", r, g, b)
    }

    // Preset colors that work well in both light and dark mode
    struct PresetColors {
        struct PresetColor: Identifiable {
            let id: String
            let name: String
            let hex: String

            var color: Color {
                Color(hex: hex) ?? .blue
            }
        }

        static let all: [PresetColor] = [
            PresetColor(id: "indigo", name: "Indigo", hex: "#6366F1"),
            PresetColor(id: "blue", name: "Blue", hex: "#3B82F6"),
            PresetColor(id: "cyan", name: "Cyan", hex: "#06B6D4"),
            PresetColor(id: "teal", name: "Teal", hex: "#14B8A6"),
            PresetColor(id: "green", name: "Green", hex: "#10B981"),
            PresetColor(id: "lime", name: "Lime", hex: "#84CC16"),
            PresetColor(id: "yellow", name: "Yellow", hex: "#EAB308"),
            PresetColor(id: "orange", name: "Orange", hex: "#F97316"),
            PresetColor(id: "red", name: "Red", hex: "#EF4444"),
            PresetColor(id: "pink", name: "Pink", hex: "#EC4899"),
            PresetColor(id: "purple", name: "Purple", hex: "#A855F7"),
            PresetColor(id: "violet", name: "Violet", hex: "#8B5CF6")
        ]
    }
}
