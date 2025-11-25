//
//  PersonTrigger.swift
//  i-cant-miss
//
//  Created by Codex on 13/10/25.
//

import Foundation

/// Trigger baseado em pessoa/contato
struct PersonTrigger: TriggerProtocol {
    let id: UUID
    var type: MemoryTriggerType { .person }
    var startDate: Date?
    var isActive: Bool
    var person: PersonData
    var spacedStage: Int
    var lastReviewDate: Date?
    var ignoreCount: Int

    struct PersonData: Hashable, Codable {
        var name: String
        var contactIdentifier: String?
    }

    init(
        id: UUID = UUID(),
        startDate: Date? = nil,
        isActive: Bool = true,
        person: PersonData,
        spacedStage: Int = 0,
        lastReviewDate: Date? = nil,
        ignoreCount: Int = 0
    ) {
        self.id = id
        self.startDate = startDate
        self.isActive = isActive
        self.person = person
        self.spacedStage = spacedStage
        self.lastReviewDate = lastReviewDate
        self.ignoreCount = ignoreCount
    }
}
