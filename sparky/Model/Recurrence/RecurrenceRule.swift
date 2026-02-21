//
//  RecurrenceRule.swift
//  sparky
//

import Foundation

struct RecurrenceRule: Codable, Hashable {
    let frequency: RecurrenceFrequency
    let interval: Int
    let endDate: Date?
    let occurrenceCount: Int?

    init(frequency: RecurrenceFrequency, interval: Int = 1, endDate: Date? = nil, occurrenceCount: Int? = nil) {
        self.frequency = frequency
        self.interval = interval
        self.endDate = endDate
        self.occurrenceCount = occurrenceCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        frequency = try container.decode(RecurrenceFrequency.self, forKey: .frequency)
        interval = try container.decode(Int.self, forKey: .interval)
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        occurrenceCount = try container.decodeIfPresent(Int.self, forKey: .occurrenceCount)
    }
}
