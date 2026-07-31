//
//  MindMemoryDisplayContent.swift
//  sparky
//

import Foundation

struct MindMemoryDisplayContent {
    let pinnedMemories: [Memory]
    let remainingMemories: [Memory]

    init(memories: [Memory]) {
        pinnedMemories = memories.filter { memory in
            memory.isPinned && memory.status == .active
        }
        remainingMemories = memories.filter { memory in
            !memory.isPinned || memory.status == .completed
        }
    }
}
