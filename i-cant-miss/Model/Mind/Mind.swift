//
//  Mind.swift
//  i-cant-miss
//

import Foundation
import SwiftData

@Model
final class Mind: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorHex: String?
    var iconName: String?
    var sortOrder: Int
    var isDefault: Bool

    @Relationship(deleteRule: .nullify, inverse: \Space.mind)
    var spaces: [Space]?

    init(
        id: UUID = UUID(),
        name: String = "",
        colorHex: String? = nil,
        iconName: String? = nil,
        sortOrder: Int = 0,
        isDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.iconName = iconName
        self.sortOrder = sortOrder
        self.isDefault = isDefault
    }
}

// MARK: - Static Members

extension Mind {
    static let allMindsIdentifier = UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")!
    static let inboxMindsIdentifier = UUID(uuidString: "EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE")!

    static var allMinds: Mind {
        Mind(
            id: allMindsIdentifier,
            name: "All",
            colorHex: nil,
            iconName: "brain.head.profile",
            sortOrder: Int.min,
            isDefault: true
        )
    }

    static var inboxMinds: Mind {
        Mind(
            id: inboxMindsIdentifier,
            name: "Inbox",
            colorHex: nil,
            iconName: "tray.fill",
            sortOrder: Int.min + 1,
            isDefault: false
        )
    }

    var isAllMinds: Bool {
        id == Mind.allMindsIdentifier
    }

    var isInboxMinds: Bool {
        id == Mind.inboxMindsIdentifier
    }
}
