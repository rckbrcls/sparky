//
//  MindModel.swift
//  i-cant-miss
//

import Foundation

struct MindModel: Identifiable, Hashable {
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

extension MindModel {
    static let allMindsIdentifier = UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")!
    static let inboxMindsIdentifier = UUID(uuidString: "EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE")!

    static var allMinds: MindModel {
        MindModel(
            id: allMindsIdentifier,
            name: "All",
            colorHex: nil,
            iconName: "brain.head.profile",
            sortOrder: Int.min,
            isDefault: true
        )
    }

    static var inboxMinds: MindModel {
        MindModel(
            id: inboxMindsIdentifier,
            name: "Inbox",
            colorHex: nil,
            iconName: "tray.fill",
            sortOrder: Int.min + 1,
            isDefault: false
        )
    }

    var isAllMinds: Bool {
        id == MindModel.allMindsIdentifier
    }

    var isInboxMinds: Bool {
        id == MindModel.inboxMindsIdentifier
    }
}
