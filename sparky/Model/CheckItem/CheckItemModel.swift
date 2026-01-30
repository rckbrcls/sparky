//
//  CheckItemModel.swift
//  sparky
//

import Foundation
import SwiftData

@Model
final class CheckItemModel: Identifiable {
    @Attribute(.unique) var id: UUID
    var title: String
    var detail: String?
    var isCompleted: Bool
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date
    var completedAt: Date?

    var memory: Memory?

    init(
        id: UUID = UUID(),
        title: String,
        detail: String? = nil,
        isCompleted: Bool = false,
        sortOrder: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        completedAt: Date? = nil,
        memory: Memory? = nil
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.isCompleted = isCompleted
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
        self.memory = memory
    }
}
