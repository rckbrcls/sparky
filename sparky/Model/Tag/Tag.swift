//
//  Tag.swift
//  sparky
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
