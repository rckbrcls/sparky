//
//  TriggerProtocol.swift
//  sparky
//
//  Created by Codex on 13/10/25.
//

import Foundation

/// Protocolo base para todos os tipos de triggers
protocol TriggerProtocol: Identifiable, Hashable, Codable {
    var id: UUID { get }
    var type: MemoryTriggerType { get }
    var isActive: Bool { get set }
    var startDate: Date? { get set }
    var spacedStage: Int { get set }
    var lastReviewDate: Date? { get set }
    var ignoreCount: Int { get set }
}

extension TriggerProtocol {
    func toModel() -> MemoryTriggerModel {
        TriggerFactory.createModel(from: self)
    }
}
