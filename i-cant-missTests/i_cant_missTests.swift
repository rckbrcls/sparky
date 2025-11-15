//
//  i_cant_missTests.swift
//  i-cant-missTests
//
//  Created by Erick Barcelos on 13/10/25.
//

import Foundation
import Testing
@testable import i_cant_miss

struct i_cant_missTests {

    @MainActor
    @Test func memoryServiceBasicOperations() async throws {
        let persistence = PersistenceController(inMemory: true)
        let environment = AppEnvironment(persistence: persistence)

        let draft = MemoryDraft(
            title: "Test Memory",
            status: .active,
            priority: .medium,
            isPinned: false
        )

        let memory = try await environment.memoryService.createMemory(from: draft)
        #expect(memory.title == "Test Memory")
        #expect(memory.status == .active)
        #expect(memory.priority == .medium)
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
        let persistence = PersistenceController(inMemory: true)
        let environment = AppEnvironment(persistence: persistence)

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

    @MainActor
    @Test func viewModelSequentialTriggerLifecycle() async throws {
        let persistence = PersistenceController(inMemory: true)
        let environment = AppEnvironment(persistence: persistence)

        let viewModel = MemoryEditorViewModel(
            environment: environment,
            attachmentStore: environment.attachmentStore,
            memory: nil,
            defaultSpace: nil,
            template: .blank
        )

        let previous = UUID()
        let next = UUID()

        viewModel.updateSequentialTrigger(previousMemoryID: previous, nextMemoryID: next)

        let sequentialTrigger = viewModel.sequentialTrigger
        #expect(sequentialTrigger != nil)
        #expect(sequentialTrigger?.sequential?.previousMemoryID == previous)
        #expect(sequentialTrigger?.sequential?.nextMemoryID == next)

        viewModel.updateSequentialTrigger(previousMemoryID: nil, nextMemoryID: nil)
        #expect(viewModel.sequentialTrigger == nil)
    }
}
