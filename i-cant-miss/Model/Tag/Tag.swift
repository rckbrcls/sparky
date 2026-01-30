//
//  Tag.swift
//  i-cant-miss
//

import Foundation
import SwiftData

@Model
final class Tag: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorHex: String?

    init(
        id: UUID = UUID(),
        name: String = "",
        colorHex: String? = nil
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
    }
}

// MARK: - Hashable

extension Tag: Hashable {
    static func == (lhs: Tag, rhs: Tag) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
