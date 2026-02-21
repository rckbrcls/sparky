//
//  Mind.swift
//  sparky
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

    @Relationship(deleteRule: .nullify, inverse: \Mind.parent)
    var children: [Mind]?
    var parent: Mind?

    @Relationship(deleteRule: .nullify, inverse: \Memory.mind)
    var memories: [Memory]?

    init(
        id: UUID = UUID(),
        name: String = "",
        colorHex: String? = nil,
        iconName: String? = nil,
        sortOrder: Int = 0,
        isDefault: Bool = false,
        parent: Mind? = nil
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.iconName = iconName
        self.sortOrder = sortOrder
        self.isDefault = isDefault
        self.parent = parent
    }
}

// MARK: - Static Members

extension Mind {
    static let allMindsIdentifier = UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")!
    static let limboIdentifier = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

    static var allMinds: Mind {
        Mind(
            id: allMindsIdentifier,
            name: "All",
            colorHex: nil,
            iconName: "tray.full.fill",
            sortOrder: Int.min,
            isDefault: true
        )
    }

    static var limbo: Mind {
        Mind(
            id: limboIdentifier,
            name: "Limbo",
            colorHex: nil,
            iconName: "questionmark.folder.fill",
            sortOrder: Int.min + 1,
            isDefault: false
        )
    }

    var isAllMinds: Bool {
        id == Mind.allMindsIdentifier
    }

    var isLimbo: Bool {
        id == Mind.limboIdentifier
    }

    var allDescendantIDs: Set<UUID> {
        var ids: Set<UUID> = [id]
        for child in children ?? [] {
            ids.formUnion(child.allDescendantIDs)
        }
        return ids
    }
}
