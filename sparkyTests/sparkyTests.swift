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

    @MainActor
    @Test func reminderRequiresPrimaryTrigger() async throws {
        let dataController = DataController(inMemory: true)
        let environment = AppEnvironment(dataController: dataController)

        let draft = MemoryDraft(
            title: "Reminder without primary trigger",
            reminderConfig: ReminderConfigDraft(
                intervalValue: 1,
                intervalUnit: .hours,
                repeatCount: nil
            )
        )

        let memory = try await environment.memoryService.createMemory(from: draft)
        let persisted = environment.memoryService.memory(id: memory.id)

        #expect(persisted?.reminderConfig == nil)
    }

    @MainActor
    @Test func reminderPrefersFirstTriggerEvent() async throws {
        let dataController = DataController(inMemory: true)
        let environment = AppEnvironment(dataController: dataController)
        let fireDate = Date().addingTimeInterval(7200)

        let draft = MemoryDraft(
            title: "Reminder with schedule and location",
            scheduleConfig: ScheduleConfigDraft(
                fireDate: fireDate,
                startDate: fireDate,
                timeZoneIdentifier: TimeZone.current.identifier,
                isActive: true
            ),
            locationConfig: LocationConfigDraft.createDefault(),
            reminderConfig: ReminderConfigDraft(
                intervalValue: 1,
                intervalUnit: .hours,
                repeatCount: nil
            )
        )

        let memory = try await environment.memoryService.createMemory(from: draft)
        let initial = environment.memoryService.memory(id: memory.id)
        #expect(initial?.reminderConfig?.startedBy == .schedule)
        #expect(initial?.reminderConfig?.startedAt == fireDate)

        let earlierLocationEvent = Date().addingTimeInterval(300)
        await environment.memoryService.markPrimaryTriggerFired(
            memoryID: memory.id,
            at: earlierLocationEvent,
            source: .location
        )

        let updated = environment.memoryService.memory(id: memory.id)
        #expect(updated?.reminderConfig?.startedBy == .location)
        #expect(updated?.reminderConfig?.startedAt != nil)
        if let updatedStart = updated?.reminderConfig?.startedAt {
            #expect(abs(updatedStart.timeIntervalSince(earlierLocationEvent)) < 1)
        }
    }

    @MainActor
    @Test func reminderResetsWhenReactivatingMemory() async throws {
        let dataController = DataController(inMemory: true)
        let environment = AppEnvironment(dataController: dataController)

        let draft = MemoryDraft(
            title: "Reset reminder on reopen",
            locationConfig: LocationConfigDraft.createDefault(),
            reminderConfig: ReminderConfigDraft(
                intervalValue: 1,
                intervalUnit: .hours,
                repeatCount: nil
            )
        )

        let memory = try await environment.memoryService.createMemory(from: draft)
        #expect(environment.memoryService.memory(id: memory.id)?.reminderConfig?.startedAt == nil)

        try await environment.memoryService.setStatus(memoryID: memory.id, status: .completed)
        try await environment.memoryService.setStatus(memoryID: memory.id, status: .active)

        let reopened = environment.memoryService.memory(id: memory.id)
        #expect(reopened?.status == .active)
        #expect(reopened?.reminderConfig?.startedAt == nil)
        #expect(reopened?.reminderConfig?.startedBy == nil)
    }
}
