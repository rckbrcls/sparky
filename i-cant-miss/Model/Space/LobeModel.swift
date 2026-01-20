//
//  LobeModel.swift
//  i-cant-miss
//

import Foundation

struct LobeModel: Identifiable, Hashable {
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

extension LobeModel {
    static let allLobesIdentifier = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    static let inboxLobesIdentifier = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    static let limboLobesIdentifier = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    static let mindAllLobePrefix = "22222222-2222-2222-2222-222222222222"

    static var allLobes: LobeModel {
        LobeModel(
            id: allLobesIdentifier,
            name: "All",
            colorHex: nil,
            iconName: "square.grid.2x2.fill",
            sortOrder: Int.min,
            isDefault: true
        )
    }

    static var inboxLobes: LobeModel {
        LobeModel(
            id: inboxLobesIdentifier,
            name: "Inbox",
            colorHex: nil,
            iconName: "tray.fill",
            sortOrder: Int.min + 1,
            isDefault: false
        )
    }

    static var limboLobes: LobeModel {
        LobeModel(
            id: limboLobesIdentifier,
            name: "Limbo",
            colorHex: nil,
            iconName: "tray",
            sortOrder: Int.min + 2,
            isDefault: false
        )
    }

    static func allLobe(for mind: MindModel) -> LobeModel {
        let deterministicID = deterministicUUID(for: mind.id)
        return LobeModel(
            id: deterministicID,
            name: "All",
            colorHex: nil,
            iconName: "square.grid.2x2.fill",
            sortOrder: Int.min,
            isDefault: false,
            mind: mind
        )
    }

    var isAllLobes: Bool {
        id == LobeModel.allLobesIdentifier
    }

    var isInboxLobes: Bool {
        id == LobeModel.inboxLobesIdentifier
    }

    var isLimboLobes: Bool {
        id == LobeModel.limboLobesIdentifier
    }

    func isAllLobe(for mind: MindModel?) -> Bool {
        guard let mind = mind else { return false }
        let expectedID = LobeModel.deterministicUUID(for: mind.id)
        return id == expectedID && self.mind?.id == mind.id
    }

    var isAllLobeForMind: Bool {
        guard let mind = mind else { return false }
        return isAllLobe(for: mind)
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
