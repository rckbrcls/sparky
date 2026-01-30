//
//  MemoryTriggerSequential.swift
//  sparky
//

import Foundation
import SwiftData

@Model
final class MemoryTriggerSequential: Identifiable {
    @Attribute(.unique) var id: UUID
    var sequenceID: UUID = UUID()
    var stepIndex: Int = 0
    /// When the sequence begins. Before this date, no memory is "current".
    var startDate: Date?
    /// The currently active step index in the sequence (shared across all memories in the sequence).
    var currentStepIndex: Int = 0

    var trigger: MemoryTriggerModel?

    init(
        id: UUID = UUID(),
        sequenceID: UUID = UUID(),
        stepIndex: Int = 0,
        startDate: Date? = nil,
        currentStepIndex: Int = 0,
        trigger: MemoryTriggerModel? = nil
    ) {
        self.id = id
        self.sequenceID = sequenceID
        self.stepIndex = stepIndex
        self.startDate = startDate
        self.currentStepIndex = currentStepIndex
        self.trigger = trigger
    }
}
