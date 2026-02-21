//
//  MemoryOccurrence.swift
//  sparky
//

import Foundation

struct MemoryOccurrence: Identifiable {
    let memory: Memory
    let occurrenceDate: Date

    var id: String { "\(memory.id.uuidString)-\(Int(occurrenceDate.timeIntervalSince1970))" }
}
