//
//  SpaceModel.swift
//  i-cant-miss
//

import Foundation

struct SpaceModel: Identifiable, Hashable {
    let id: UUID
    var name: String
    var colorHex: String?
    var iconName: String?
    var sortOrder: Int
    var isDefault: Bool

    init(id: UUID,
         name: String,
         colorHex: String? = nil,
         iconName: String? = nil,
         sortOrder: Int = 0,
         isDefault: Bool = false) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.iconName = iconName
        self.sortOrder = sortOrder
        self.isDefault = isDefault
    }
}

// MARK: - Static Members

extension SpaceModel {
    static let allSpacesIdentifier = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    static var allSpaces: SpaceModel {
        SpaceModel(
            id: allSpacesIdentifier,
            name: "All",
            colorHex: nil,
            iconName: "square.grid.2x2.fill",
            sortOrder: Int.min,
            isDefault: true
        )
    }

    var isAllSpaces: Bool {
        id == SpaceModel.allSpacesIdentifier
    }
}
