//
//  RecurrenceRule.swift
//  sparky
//

import Foundation

struct RecurrenceRule: Codable, Hashable {
    let frequency: RecurrenceFrequency
    let interval: Int
    let endDate: Date?

    init(frequency: RecurrenceFrequency, interval: Int = 1, endDate: Date? = nil) {
        self.frequency = frequency
        self.interval = interval
        self.endDate = endDate
    }
}
