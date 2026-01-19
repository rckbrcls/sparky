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
    static let mindAllSpacePrefix = "22222222-2222-2222-2222-222222222222"

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

    static func allSpace(for mind: MindModel) -> SpaceModel {
        let deterministicID = deterministicUUID(for: mind.id)
        return SpaceModel(
            id: deterministicID,
            name: "All",
            colorHex: nil,
            iconName: "square.grid.2x2.fill",
            sortOrder: Int.min,
            isDefault: false,
            mind: mind
        )
    }

    var isAllSpaces: Bool {
        id == SpaceModel.allSpacesIdentifier
    }

    var isInboxSpaces: Bool {
        id == SpaceModel.inboxSpacesIdentifier
    }

    func isAllSpace(for mind: MindModel?) -> Bool {
        guard let mind = mind else { return false }
        let expectedID = SpaceModel.deterministicUUID(for: mind.id)
        return id == expectedID && self.mind?.id == mind.id
    }

    var isAllSpaceForMind: Bool {
        guard let mind = mind else { return false }
        return isAllSpace(for: mind)
    }

    private static func deterministicUUID(for mindID: UUID) -> UUID {
        let input = "mind-all-space-\(mindID.uuidString)"
        let data = input.data(using: .utf8)!
        var hash: UInt64 = 5381
        for byte in data {
            hash = ((hash << 5) &+ hash) &+ UInt64(byte)
        }
        
        var bytes = [UInt8](repeating: 0, count: 16)
        for i in 0..<8 {
            bytes[i] = UInt8((hash >> (i * 8)) & 0xFF)
        }
        let secondHash = hash &* 31
        for i in 0..<8 {
            bytes[i + 8] = UInt8((secondHash >> (i * 8)) & 0xFF)
        }
        
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
