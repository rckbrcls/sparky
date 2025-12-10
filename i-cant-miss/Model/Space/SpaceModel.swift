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
    var parentID: UUID?
    var childIDs: [UUID]
    var isDefault: Bool

    init(id: UUID,
         name: String,
         colorHex: String? = nil,
         iconName: String? = nil,
         sortOrder: Int = 0,
         parentID: UUID? = nil,
         childIDs: [UUID] = [],
         isDefault: Bool = false) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.iconName = iconName
        self.sortOrder = sortOrder
        self.parentID = parentID
        self.childIDs = childIDs
        self.isDefault = isDefault
    }

    var isRoot: Bool { parentID == nil }
    var hasChildren: Bool { !childIDs.isEmpty }
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
            parentID: nil,
            childIDs: [],
            isDefault: true
        )
    }

    var isAllSpaces: Bool {
        id == SpaceModel.allSpacesIdentifier
    }

    func isAncestor(of space: SpaceModel, using lookup: (UUID) -> SpaceModel?) -> Bool {
        guard let parentID else { return false }
        if parentID == space.id { return true }
        guard let parent = lookup(parentID) else { return false }
        return parent.isAncestor(of: space, using: lookup)
    }
}
