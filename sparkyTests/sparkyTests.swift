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

    @MainActor
    @Test func reminderResetsWhenScheduleTriggerChanges() async throws {
        let dataController = DataController(inMemory: true)
        let environment = AppEnvironment(dataController: dataController)
        let initialFireDate = Date().addingTimeInterval(7200)
        let updatedFireDate = Date().addingTimeInterval(21600)

        let draft = MemoryDraft(
            title: "Reset on schedule change",
            scheduleConfig: ScheduleConfigDraft(
                fireDate: initialFireDate,
                startDate: initialFireDate,
                timeZoneIdentifier: TimeZone.current.identifier,
                isActive: true
            ),
            reminderConfig: ReminderConfigDraft(
                intervalValue: 1,
                intervalUnit: .hours,
                repeatCount: nil
            )
        )

        let memory = try await environment.memoryService.createMemory(from: draft)
        guard let beforeUpdate = environment.memoryService.memory(id: memory.id),
              let beforeSchedule = beforeUpdate.scheduleConfig,
              let beforeReminder = beforeUpdate.reminderConfig else {
            Issue.record("Expected schedule and reminder before update")
            return
        }

        #expect(beforeReminder.startedAt != nil)
        if let startedAt = beforeReminder.startedAt {
            #expect(abs(startedAt.timeIntervalSince(initialFireDate)) < 1)
        }

        let updatedSchedule = ScheduleConfigDraft(
            id: beforeSchedule.id,
            fireDate: updatedFireDate,
            startDate: updatedFireDate,
            recurrenceRule: beforeSchedule.recurrenceRule,
            timeZoneIdentifier: beforeSchedule.timeZoneIdentifier,
            weekdayMask: beforeSchedule.weekdayMask,
            isActive: beforeSchedule.isActive,
            isAllDay: beforeSchedule.isAllDay,
            recurrenceEndType: beforeSchedule.recurrenceEndType
        )

        let updateDraft = MemoryDraft(
            id: beforeUpdate.id,
            title: beforeUpdate.title,
            scheduleConfig: updatedSchedule,
            reminderConfig: ReminderConfigDraft.from(beforeReminder)
        )

        let updated = try await environment.memoryService.updateMemory(from: updateDraft)
        guard let updatedReminder = updated.reminderConfig else {
            Issue.record("Expected reminder after schedule change")
            return
        }

        #expect(updatedReminder.startedBy == .schedule)
        #expect(updatedReminder.startedAt != nil)
        if let startedAt = updatedReminder.startedAt {
            #expect(abs(startedAt.timeIntervalSince(updatedFireDate)) < 1)
        }
    }

    @MainActor
    @Test func reminderResetsWhenLocationTriggerChanges() async throws {
        let dataController = DataController(inMemory: true)
        let environment = AppEnvironment(dataController: dataController)

        let draft = MemoryDraft(
            title: "Reset on location change",
            locationConfig: LocationConfigDraft.createDefault(),
            reminderConfig: ReminderConfigDraft(
                intervalValue: 1,
                intervalUnit: .hours,
                repeatCount: nil
            )
        )

        let memory = try await environment.memoryService.createMemory(from: draft)
        let triggerDate = Date().addingTimeInterval(300)
        await environment.memoryService.markPrimaryTriggerFired(
            memoryID: memory.id,
            at: triggerDate,
            source: .location
        )

        guard let beforeUpdate = environment.memoryService.memory(id: memory.id),
              let beforeLocation = beforeUpdate.locationConfig,
              let beforeReminder = beforeUpdate.reminderConfig else {
            Issue.record("Expected location and reminder before update")
            return
        }

        #expect(beforeReminder.startedBy == .location)
        #expect(beforeReminder.startedAt != nil)

        let updatedLocation = LocationConfigDraft(
            id: beforeLocation.id,
            latitude: beforeLocation.latitude + 0.002,
            longitude: beforeLocation.longitude,
            radius: beforeLocation.radius,
            name: beforeLocation.name,
            event: beforeLocation.event,
            isActive: beforeLocation.isActive
        )

        let updateDraft = MemoryDraft(
            id: beforeUpdate.id,
            title: beforeUpdate.title,
            locationConfig: updatedLocation,
            reminderConfig: ReminderConfigDraft.from(beforeReminder)
        )

        let updated = try await environment.memoryService.updateMemory(from: updateDraft)
        let updatedReminder = updated.reminderConfig
        #expect(updatedReminder?.startedAt == nil)
        #expect(updatedReminder?.startedBy == nil)
    }

    @MainActor
    @Test func reminderDoesNotResetWhenOnlyMetadataChanges() async throws {
        let dataController = DataController(inMemory: true)
        let environment = AppEnvironment(dataController: dataController)
        let fireDate = Date().addingTimeInterval(7200)

        let draft = MemoryDraft(
            title: "Metadata source",
            scheduleConfig: ScheduleConfigDraft(
                fireDate: fireDate,
                startDate: fireDate,
                timeZoneIdentifier: TimeZone.current.identifier,
                isActive: true
            ),
            reminderConfig: ReminderConfigDraft(
                intervalValue: 1,
                intervalUnit: .hours,
                repeatCount: nil
            ),
            note: "Original note"
        )

        let memory = try await environment.memoryService.createMemory(from: draft)
        guard let beforeUpdate = environment.memoryService.memory(id: memory.id),
              let beforeSchedule = beforeUpdate.scheduleConfig,
              let beforeReminder = beforeUpdate.reminderConfig,
              let originalStart = beforeReminder.startedAt else {
            Issue.record("Expected schedule/reminder start before metadata update")
            return
        }

        let updateDraft = MemoryDraft(
            id: beforeUpdate.id,
            title: "Metadata updated",
            scheduleConfig: ScheduleConfigDraft.from(beforeSchedule),
            reminderConfig: ReminderConfigDraft.from(beforeReminder),
            note: "Updated note"
        )

        let updated = try await environment.memoryService.updateMemory(from: updateDraft)
        guard let updatedReminder = updated.reminderConfig else {
            Issue.record("Expected reminder after metadata update")
            return
        }

        #expect(updatedReminder.startedBy == .schedule)
        #expect(updatedReminder.startedAt != nil)
        if let updatedStart = updatedReminder.startedAt {
            #expect(abs(updatedStart.timeIntervalSince(originalStart)) < 1)
        }
    }

    @MainActor
    @Test func reminderDoesNotResetWhenOnlyReminderCadenceChanges() async throws {
        let dataController = DataController(inMemory: true)
        let environment = AppEnvironment(dataController: dataController)
        let fireDate = Date().addingTimeInterval(7200)

        let draft = MemoryDraft(
            title: "Cadence source",
            scheduleConfig: ScheduleConfigDraft(
                fireDate: fireDate,
                startDate: fireDate,
                timeZoneIdentifier: TimeZone.current.identifier,
                isActive: true
            ),
            reminderConfig: ReminderConfigDraft(
                intervalValue: 1,
                intervalUnit: .hours,
                repeatCount: nil
            )
        )

        let memory = try await environment.memoryService.createMemory(from: draft)
        guard let beforeUpdate = environment.memoryService.memory(id: memory.id),
              let beforeSchedule = beforeUpdate.scheduleConfig,
              let beforeReminder = beforeUpdate.reminderConfig,
              let originalStart = beforeReminder.startedAt else {
            Issue.record("Expected schedule/reminder start before cadence update")
            return
        }

        var updatedReminderDraft = ReminderConfigDraft.from(beforeReminder)
        updatedReminderDraft.intervalValue = 2
        updatedReminderDraft.intervalUnit = .hours
        updatedReminderDraft.repeatCount = 4

        let updateDraft = MemoryDraft(
            id: beforeUpdate.id,
            title: beforeUpdate.title,
            scheduleConfig: ScheduleConfigDraft.from(beforeSchedule),
            reminderConfig: updatedReminderDraft
        )

        let updated = try await environment.memoryService.updateMemory(from: updateDraft)
        guard let updatedReminder = updated.reminderConfig else {
            Issue.record("Expected reminder after cadence update")
            return
        }

        #expect(updatedReminder.intervalValue == 2)
        #expect(updatedReminder.repeatCount == 4)
        #expect(updatedReminder.startedBy == .schedule)
        #expect(updatedReminder.startedAt != nil)
        if let updatedStart = updatedReminder.startedAt {
            #expect(abs(updatedStart.timeIntervalSince(originalStart)) < 1)
        }
    }
}
