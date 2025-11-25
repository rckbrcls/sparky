//
//  FocusTrigger.swift
//  i-cant-miss
//
//  Created by Codex on 13/10/25.
//

import Foundation

/// Trigger baseado em modo de foco
struct FocusTrigger: TriggerProtocol {
    let id: UUID
    var type: MemoryTriggerType { .focus }
    var startDate: Date?
    var isActive: Bool
    var focus: FocusData
    var spacedStage: Int
    var lastReviewDate: Date?
    var ignoreCount: Int

    struct FocusData: Hashable, Codable {
        var focusIdentifier: String?
        var focusName: String
    }

    init(
        id: UUID = UUID(),
        startDate: Date? = nil,
        isActive: Bool = true,
        focus: FocusData,
        spacedStage: Int = 0,
        lastReviewDate: Date? = nil,
        ignoreCount: Int = 0
    ) {
        self.id = id
        self.startDate = startDate
        self.isActive = isActive
        self.focus = focus
        self.spacedStage = spacedStage
        self.lastReviewDate = lastReviewDate
        self.ignoreCount = ignoreCount
    }
}
