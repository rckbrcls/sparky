//
//  CheckItemDraft.swift
//  sparky
//

import Foundation

struct CheckItemDraft: Identifiable, Hashable {
    let id: UUID
    var title: String
    var detail: String
    var isCompleted: Bool
    var sortOrder: Int
    var createdAt: Date
    var completedAt: Date?

    init(id: UUID = UUID(),
         title: String = "",
         detail: String = "",
         isCompleted: Bool = false,
         sortOrder: Int = 0,
         createdAt: Date = Date(),
         completedAt: Date? = nil) {
        self.id = id
        self.title = title
        self.detail = detail
        self.isCompleted = isCompleted
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.completedAt = completedAt
    }
}
