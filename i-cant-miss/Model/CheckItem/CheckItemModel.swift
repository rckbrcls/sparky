//
//  CheckItemModel.swift
//  i-cant-miss
//

import Foundation

struct CheckItemModel: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var detail: String?
    var isCompleted: Bool
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date
    var completedAt: Date?
}
