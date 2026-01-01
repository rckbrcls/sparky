//
//  SequentialTrigger.swift
//  i-cant-miss
//
//  Created by Codex on 13/10/25.
//

import Foundation

/// Trigger sequencial baseado em outras memórias
struct SequentialTrigger: TriggerProtocol {
    let id: UUID
    var type: MemoryTriggerType { .sequential }
    var startDate: Date?
    var isActive: Bool
    var sequential: SequentialData
    var spacedStage: Int
    var lastReviewDate: Date?
    var ignoreCount: Int

    struct SequentialData: Hashable, Codable {
        var sequenceID: UUID
        var stepIndex: Int

        init(sequenceID: UUID = UUID(), stepIndex: Int = 0) {
            self.sequenceID = sequenceID
            self.stepIndex = stepIndex
        }
    }

    init(
        id: UUID = UUID(),
        startDate: Date? = nil,
        isActive: Bool = true,
        sequential: SequentialData,
        spacedStage: Int = 0,
        lastReviewDate: Date? = nil,
        ignoreCount: Int = 0
    ) {
        self.id = id
        self.startDate = startDate
        self.isActive = isActive
        self.sequential = sequential
        self.spacedStage = spacedStage
        self.lastReviewDate = lastReviewDate
        self.ignoreCount = ignoreCount
    }
}
