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
    var mind: MindModel?

    init(id: UUID,
         name: String,
         colorHex: String? = nil,
         iconName: String? = nil,
         sortOrder: Int = 0,
         isDefault: Bool = false,
         mind: MindModel? = nil) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.iconName = iconName
        self.sortOrder = sortOrder
        self.isDefault = isDefault
        self.mind = mind
    }
}

// MARK: - Static Members

extension SpaceModel {
    static let allSpacesIdentifier = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    static let inboxSpacesIdentifier = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

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

    static var inboxSpaces: SpaceModel {
        SpaceModel(
            id: inboxSpacesIdentifier,
            name: "Inbox",
            colorHex: nil,
            iconName: "tray.fill",
            sortOrder: Int.min + 1,
            isDefault: false
        )
    }

    var isAllSpaces: Bool {
        id == SpaceModel.allSpacesIdentifier
    }

    var isInboxSpaces: Bool {
        id == SpaceModel.inboxSpacesIdentifier
    }
}
