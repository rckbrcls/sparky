//
//  sparkyTests.swift
//  sparkyTests
//
//  Created by Erick Barcelos on 13/10/25.
//

import Foundation
import Testing
@testable import sparky

struct sparkyTests {

    @MainActor
    @Test func memoryServiceBasicOperations() async throws {
        let dataController = DataController(inMemory: true)
        let environment = AppEnvironment(dataController: dataController)

        let draft = MemoryDraft(
            title: "Test Memory",
            status: .active,
            isPinned: false
        )

        let memory = try await environment.memoryService.createMemory(from: draft)
        #expect(memory.title == "Test Memory")
        #expect(memory.status == .active)
        #expect(!memory.isPinned)

        // Test toggle pin
        try await environment.memoryService.togglePin(memoryID: memory.id)
        let updatedMemory = environment.memoryService.memory(id: memory.id)
        #expect(updatedMemory?.isPinned == true)

        // Test completion toggle
        try await environment.memoryService.toggleCompletion(memoryID: memory.id)
        let completedMemory = environment.memoryService.memory(id: memory.id)
        #expect(completedMemory?.status == .completed)
    }

    @MainActor
    @Test func memoryTimelineFiltering() async throws {
        let dataController = DataController(inMemory: true)
        let environment = AppEnvironment(dataController: dataController)

        let draft1 = MemoryDraft(title: "Active Memory")
        let draft2 = MemoryDraft(title: "Completed Memory", status: .completed)

        _ = try await environment.memoryService.createMemory(from: draft1)
        _ = try await environment.memoryService.createMemory(from: draft2)

        let activeMemories = environment.memoryService.memories(in: nil, statuses: [.active])
        let completedMemories = environment.memoryService.memories(in: nil, statuses: [.completed])

        #expect(activeMemories.count == 1)
        #expect(activeMemories.first?.title == "Active Memory")
        #expect(completedMemories.count == 1)
        #expect(completedMemories.first?.title == "Completed Memory")
    }
}
