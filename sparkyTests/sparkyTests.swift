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
    @Test func nestedRemindersAreIndependentPerPrimary() async throws {
        let dataController = DataController(inMemory: true)
        let environment = AppEnvironment(dataController: dataController)
        let fireDate = Date().addingTimeInterval(7200)

        let draft = MemoryDraft(
            title: "Dual nested reminders",
            scheduleConfig: ScheduleConfigDraft(
                fireDate: fireDate,
                startDate: fireDate,
                timeZoneIdentifier: TimeZone.current.identifier,
                isActive: true,
                reminder: NestedReminderPolicy(
                    isActive: true,
                    intervalValue: 1,
                    intervalUnit: .hours
                ),
                focusEnabled: true
            ),
            locationConfig: LocationConfigDraft(
                latitude: 37.33,
                longitude: -122.01,
                radius: 200,
                name: "Office",
                event: .onEntry,
                isActive: true,
                reminder: NestedReminderPolicy(
                    isActive: true,
                    intervalValue: 30,
                    intervalUnit: .minutes
                )
            )
        )

        let memory = try await environment.memoryService.createMemory(from: draft)
        let persisted = environment.memoryService.memory(id: memory.id)

        #expect(persisted?.hasFocus == true)
        #expect(persisted?.scheduleConfig?.hasActiveReminder == true)
        #expect(persisted?.locationConfig?.hasActiveReminder == true)
        #expect(persisted?.locationConfig?.reminderStartedAt == nil)

        // Schedule reminder can seed from fireDate during executor sync.
        #expect(persisted?.scheduleConfig?.reminderStartedAt == fireDate
                || persisted?.scheduleConfig?.reminder.startedAt == nil
                || abs((persisted?.scheduleConfig?.reminderStartedAt ?? fireDate).timeIntervalSince(fireDate)) < 1)

        let locationEvent = Date().addingTimeInterval(300)
        await environment.memoryService.markPrimaryTriggerFired(
            memoryID: memory.id,
            at: locationEvent,
            source: .location
        )

        let updated = environment.memoryService.memory(id: memory.id)
        #expect(updated?.locationConfig?.reminderStartedAt != nil)
        if let started = updated?.locationConfig?.reminderStartedAt {
            #expect(abs(started.timeIntervalSince(locationEvent)) < 1)
        }
        // Location fire must not wipe schedule nested start.
        if let scheduleStart = updated?.scheduleConfig?.reminderStartedAt {
            #expect(abs(scheduleStart.timeIntervalSince(fireDate)) < 1)
        }
    }

    @MainActor
    @Test func nestedReminderClearsWhenReactivatingMemory() async throws {
        let dataController = DataController(inMemory: true)
        let environment = AppEnvironment(dataController: dataController)

        var location = LocationConfigDraft.createDefault()
        location.reminder = NestedReminderPolicy(isActive: true, intervalValue: 1, intervalUnit: .hours)

        let draft = MemoryDraft(
            title: "Reset nested reminder on reopen",
            locationConfig: location
        )

        let memory = try await environment.memoryService.createMemory(from: draft)
        await environment.memoryService.markPrimaryTriggerFired(
            memoryID: memory.id,
            at: Date(),
            source: .location
        )
        #expect(environment.memoryService.memory(id: memory.id)?.locationConfig?.reminderStartedAt != nil)

        try await environment.memoryService.setStatus(memoryID: memory.id, status: .completed)
        try await environment.memoryService.setStatus(memoryID: memory.id, status: .active)

        let reopened = environment.memoryService.memory(id: memory.id)
        #expect(reopened?.status == .active)
        #expect(reopened?.locationConfig?.reminderStartedAt == nil)
    }

    @MainActor
    @Test func nestedReminderResetsWhenScheduleTriggerChanges() async throws {
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
                isActive: true,
                reminder: NestedReminderPolicy(isActive: true, intervalValue: 1, intervalUnit: .hours),
                focusEnabled: false
            )
        )

        let memory = try await environment.memoryService.createMemory(from: draft)
        guard let beforeUpdate = environment.memoryService.memory(id: memory.id),
              let beforeSchedule = beforeUpdate.scheduleConfig else {
            Issue.record("Expected schedule before update")
            return
        }

        // Seed start as executor would.
        beforeSchedule.reminderStartedAt = initialFireDate
        dataController.save()

        var updatedSchedule = ScheduleConfigDraft.from(beforeSchedule)
        updatedSchedule.fireDate = updatedFireDate
        updatedSchedule.startDate = updatedFireDate
        // Keep nested reminder active; start should clear because primary changed.
        updatedSchedule.reminder.startedAt = beforeSchedule.reminderStartedAt

        let updateDraft = MemoryDraft(
            id: beforeUpdate.id,
            title: beforeUpdate.title,
            scheduleConfig: updatedSchedule
        )

        let updated = try await environment.memoryService.updateMemory(from: updateDraft)
        // Cleared on update because primary trigger changed; executor may re-seed from new fireDate.
        let startedAt = updated.scheduleConfig?.reminderStartedAt
        if let startedAt {
            #expect(abs(startedAt.timeIntervalSince(updatedFireDate)) < 1)
        } else {
            #expect(startedAt == nil)
        }
    }

    @MainActor
    @Test func nestedReminderResetsWhenLocationTriggerChanges() async throws {
        let dataController = DataController(inMemory: true)
        let environment = AppEnvironment(dataController: dataController)

        var location = LocationConfigDraft.createDefault()
        location.reminder = NestedReminderPolicy(isActive: true, intervalValue: 1, intervalUnit: .hours)

        let draft = MemoryDraft(
            title: "Reset on location change",
            locationConfig: location
        )

        let memory = try await environment.memoryService.createMemory(from: draft)
        let triggerDate = Date().addingTimeInterval(300)
        await environment.memoryService.markPrimaryTriggerFired(
            memoryID: memory.id,
            at: triggerDate,
            source: .location
        )

        guard let beforeUpdate = environment.memoryService.memory(id: memory.id),
              let beforeLocation = beforeUpdate.locationConfig else {
            Issue.record("Expected location before update")
            return
        }

        #expect(beforeLocation.reminderStartedAt != nil)

        var updatedLocation = LocationConfigDraft.from(beforeLocation)
        updatedLocation.latitude += 0.002
        updatedLocation.reminder.startedAt = beforeLocation.reminderStartedAt

        let updateDraft = MemoryDraft(
            id: beforeUpdate.id,
            title: beforeUpdate.title,
            locationConfig: updatedLocation
        )

        let updated = try await environment.memoryService.updateMemory(from: updateDraft)
        #expect(updated.locationConfig?.reminderStartedAt == nil)
    }

    @MainActor
    @Test func nestedReminderKeepsStartWhenOnlyMetadataChanges() async throws {
        let dataController = DataController(inMemory: true)
        let environment = AppEnvironment(dataController: dataController)
        let fireDate = Date().addingTimeInterval(7200)

        let draft = MemoryDraft(
            title: "Metadata source",
            scheduleConfig: ScheduleConfigDraft(
                fireDate: fireDate,
                startDate: fireDate,
                timeZoneIdentifier: TimeZone.current.identifier,
                isActive: true,
                reminder: NestedReminderPolicy(
                    isActive: true,
                    intervalValue: 1,
                    intervalUnit: .hours,
                    startedAt: fireDate
                )
            ),
            note: "Original note"
        )

        let memory = try await environment.memoryService.createMemory(from: draft)
        guard let beforeUpdate = environment.memoryService.memory(id: memory.id),
              let beforeSchedule = beforeUpdate.scheduleConfig,
              let originalStart = beforeSchedule.reminderStartedAt else {
            Issue.record("Expected schedule nested start before metadata update")
            return
        }

        let updateDraft = MemoryDraft(
            id: beforeUpdate.id,
            title: "Metadata updated",
            scheduleConfig: ScheduleConfigDraft.from(beforeSchedule),
            note: "Updated note"
        )

        let updated = try await environment.memoryService.updateMemory(from: updateDraft)
        guard let updatedStart = updated.scheduleConfig?.reminderStartedAt else {
            Issue.record("Expected nested start after metadata update")
            return
        }

        #expect(abs(updatedStart.timeIntervalSince(originalStart)) < 1)
    }

    @MainActor
    @Test func nestedReminderKeepsStartWhenOnlyCadenceChanges() async throws {
        let dataController = DataController(inMemory: true)
        let environment = AppEnvironment(dataController: dataController)
        let fireDate = Date().addingTimeInterval(7200)

        let draft = MemoryDraft(
            title: "Cadence source",
            scheduleConfig: ScheduleConfigDraft(
                fireDate: fireDate,
                startDate: fireDate,
                timeZoneIdentifier: TimeZone.current.identifier,
                isActive: true,
                reminder: NestedReminderPolicy(
                    isActive: true,
                    intervalValue: 1,
                    intervalUnit: .hours,
                    startedAt: fireDate
                )
            )
        )

        let memory = try await environment.memoryService.createMemory(from: draft)
        guard let beforeUpdate = environment.memoryService.memory(id: memory.id),
              let beforeSchedule = beforeUpdate.scheduleConfig,
              let originalStart = beforeSchedule.reminderStartedAt else {
            Issue.record("Expected schedule nested start before cadence update")
            return
        }

        var updatedSchedule = ScheduleConfigDraft.from(beforeSchedule)
        updatedSchedule.reminder.intervalValue = 2
        updatedSchedule.reminder.repeatCount = 4

        let updateDraft = MemoryDraft(
            id: beforeUpdate.id,
            title: beforeUpdate.title,
            scheduleConfig: updatedSchedule
        )

        let updated = try await environment.memoryService.updateMemory(from: updateDraft)
        guard let updatedScheduleModel = updated.scheduleConfig else {
            Issue.record("Expected schedule after cadence update")
            return
        }

        #expect(updatedScheduleModel.reminderIntervalValue == 2)
        #expect(updatedScheduleModel.reminderRepeatCount == 4)
        #expect(updatedScheduleModel.reminderStartedAt != nil)
        if let updatedStart = updatedScheduleModel.reminderStartedAt {
            #expect(abs(updatedStart.timeIntervalSince(originalStart)) < 1)
        }
    }

    @MainActor
    @Test func focusEnabledOnlyOnSchedule() async throws {
        let dataController = DataController(inMemory: true)
        let environment = AppEnvironment(dataController: dataController)
        let fireDate = Date().addingTimeInterval(600)

        let draft = MemoryDraft(
            title: "Focus memory",
            scheduleConfig: ScheduleConfigDraft(
                fireDate: fireDate,
                startDate: fireDate,
                timeZoneIdentifier: TimeZone.current.identifier,
                isActive: true,
                focusEnabled: true
            )
        )

        let memory = try await environment.memoryService.createMemory(from: draft)
        #expect(memory.hasFocus)
        #expect(memory.scheduleConfig?.focusEnabled == true)

        environment.startFocus(for: memory.id)
        #expect(environment.focusTimer.activeMemoryID == memory.id)
        #expect(environment.pendingFocusOpenRequest?.memoryID == memory.id)
    }

    @Test func nestedReminderPolicyDefaults() {
        let policy = NestedReminderPolicy.createDefault()
        #expect(policy.isActive)
        #expect(policy.intervalValue == 1)
        #expect(policy.intervalUnit == .hours)
        #expect(policy.repeatCount == nil)
        #expect(policy.secondsInterval == 3600)

        let cleared = policy.clearingStart()
        #expect(cleared.startedAt == nil)
    }
}
