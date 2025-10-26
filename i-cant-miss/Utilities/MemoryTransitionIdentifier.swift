//
//  MemoryTransitionIdentifier.swift
//  i-cant-miss
//
//  Created by Codex on 26/10/25.
//

import Foundation

struct MemoryTransitionIdentifier: Hashable {
    enum Context: Hashable {
        case timeline(section: MemoryService.TimelineSection.Kind)
        case timelineInbox
        case space(UUID)
        case custom(String)
    }

    let context: Context
    let memoryID: UUID
}
