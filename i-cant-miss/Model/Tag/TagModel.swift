//
//  TagModel.swift
//  i-cant-miss
//

import Foundation

struct TagModel: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var colorHex: String?

    init(id: UUID, name: String, colorHex: String? = nil) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
    }
}
