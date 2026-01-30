//
//  MemoryCompletionDate.swift
//  i-cant-miss
//

import Foundation
import SwiftData

@Model
final class MemoryCompletionDate: Identifiable {
    @Attribute(.unique) var id: UUID
    var date: Date
    var memory: Memory?

    init(
        id: UUID = UUID(),
        date: Date,
        memory: Memory? = nil
    ) {
        self.id = id
        self.date = date
        self.memory = memory
    }
}
