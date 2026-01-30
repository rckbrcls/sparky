//
//  MemoryAttachmentReference.swift
//  i-cant-miss
//

import Foundation
import SwiftData

@Model
final class MemoryAttachmentReference: Identifiable {
    @Attribute(.unique) var id: UUID
    var kindRaw: String
    var sortOrder: Int
    var createdAt: Date
    var memory: Memory?

    init(
        id: UUID = UUID(),
        kindRaw: String,
        sortOrder: Int,
        createdAt: Date = Date(),
        memory: Memory? = nil
    ) {
        self.id = id
        self.kindRaw = kindRaw
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.memory = memory
    }
}
