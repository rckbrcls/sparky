//
//  LocationTrigger.swift
//  i-cant-miss
//
//  Created by Codex on 13/10/25.
//

import Foundation

/// Trigger baseado em localização geográfica
struct LocationTrigger: TriggerProtocol {
    let id: UUID
    var type: MemoryTriggerType { .location }
    var startDate: Date?
    var isActive: Bool
    var location: LocationData
    var spacedStage: Int
    var lastReviewDate: Date?
    var ignoreCount: Int

    struct LocationData: Hashable, Codable {
        var latitude: Double
        var longitude: Double
        var radius: Double
        var name: String?
        var event: LocationEvent
    }

    init(
        id: UUID = UUID(),
        startDate: Date? = nil,
        isActive: Bool = true,
        location: LocationData,
        spacedStage: Int = 0,
        lastReviewDate: Date? = nil,
        ignoreCount: Int = 0
    ) {
        self.id = id
        self.startDate = startDate
        self.isActive = isActive
        self.location = location
        self.spacedStage = spacedStage
        self.lastReviewDate = lastReviewDate
        self.ignoreCount = ignoreCount
    }
}
