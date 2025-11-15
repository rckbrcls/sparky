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
    @Test func recurringTimeReminderStaysActiveAfterCompletion() async throws {
        let persistence = PersistenceController(inMemory: true)
        let folderService = FolderService(persistence: persistence)
        let reminderService = ReminderService(persistence: persistence, folderService: folderService)

        let calendar = Calendar.current
        let now = Date()
        let fireDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: now) ?? now
        let recurrence = RecurrenceRule(frequency: .daily, interval: 1)

        let trigger = ReminderTriggerDraft(
            type: .time,
            fireDate: fireDate,
            startDate: fireDate,
            recurrenceRule: recurrence,
            timeZoneIdentifier: TimeZone.current.identifier,
            isActive: true
        )

        let draft = ReminderDraft(
            title: "Daily review",
            notes: nil,
            status: .active,
            priority: .medium,
            folderID: nil,
            triggers: [trigger]
        )
        let reminder = try await reminderService.createReminder(from: draft)

        let completed = try await reminderService.completeReminder(id: reminder.id)
        #expect(completed.status == .active)
        #expect(completed.lastCompletionDate != nil)

        guard let updatedTrigger = completed.triggers.first(where: { $0.type == .time }) else {
            #expect(Bool(false), "Missing time trigger after completion")
            return
        }

        let expectedDate = calendar.date(byAdding: .day, value: 1, to: fireDate) ?? fireDate
        if let fireDate = updatedTrigger.fireDate {
            #expect(abs(fireDate.timeIntervalSince(expectedDate)) < 2.0)
        } else {
            #expect(Bool(false), "Recurring trigger should keep fireDate")
        }
    }

    @MainActor
    @Test func recurringTimeReminderCompletingEarlyAdvancesToNextDay() async throws {
        let persistence = PersistenceController(inMemory: true)
        let folderService = FolderService(persistence: persistence)
        let reminderService = ReminderService(persistence: persistence, folderService: folderService)

        let calendar = Calendar.current
        let now = Date()
        let futureFireDate = calendar.date(byAdding: .hour, value: 6, to: now) ?? now.addingTimeInterval(21_600)
        let recurrence = RecurrenceRule(frequency: .daily, interval: 1)

        let trigger = ReminderTriggerDraft(
            type: .time,
            fireDate: futureFireDate,
            startDate: futureFireDate,
            recurrenceRule: recurrence,
            timeZoneIdentifier: TimeZone.current.identifier,
            isActive: true
        )

        let draft = ReminderDraft(
            title: "Morning routine",
            notes: nil,
            status: .active,
            priority: .medium,
            folderID: nil,
            triggers: [trigger]
        )

        let reminder = try await reminderService.createReminder(from: draft)
        let completed = try await reminderService.completeReminder(id: reminder.id)
        #expect(completed.status == .active)

        guard let updatedTrigger = completed.triggers.first(where: { $0.type == .time }) else {
            #expect(Bool(false), "Missing time trigger after completion")
            return
        }

        let expectedDate = calendar.date(byAdding: .day, value: 1, to: futureFireDate) ?? futureFireDate
        if let fireDate = updatedTrigger.fireDate {
            #expect(abs(fireDate.timeIntervalSince(expectedDate)) < 2.0)
        } else {
            #expect(Bool(false), "Recurring trigger should keep fireDate")
        }
    }

    @MainActor
    @Test func locationReminderRemainsActiveAfterCompletion() async throws {
        let persistence = PersistenceController(inMemory: true)
        let folderService = FolderService(persistence: persistence)
        let reminderService = ReminderService(persistence: persistence, folderService: folderService)

        let location = ReminderTriggerModel.TriggerLocation(
            latitude: 37.0,
            longitude: -122.0,
            radius: 150,
            name: "Office",
            event: .onEntry
        )
        let trigger = ReminderTriggerDraft(
            type: .location,
            isActive: true,
            location: location
        )
        let draft = ReminderDraft(
            title: "Drop off badge",
            notes: nil,
            status: .active,
            priority: .medium,
            folderID: nil,
            triggers: [trigger]
        )

        let reminder = try await reminderService.createReminder(from: draft)
        let completed = try await reminderService.completeReminder(id: reminder.id)

        #expect(completed.status == .active)
        #expect(completed.lastCompletionDate != nil)
    }

    @MainActor
    @Test func oneOffReminderCompletesAsExpected() async throws {
        let persistence = PersistenceController(inMemory: true)
        let folderService = FolderService(persistence: persistence)
        let reminderService = ReminderService(persistence: persistence, folderService: folderService)

        let now = Date()
        let fireDate = Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now
        let trigger = ReminderTriggerDraft(
            type: .time,
            fireDate: fireDate,
            startDate: fireDate,
            isActive: true
        )

        let draft = ReminderDraft(
            title: "One-off task",
            notes: nil,
            status: .active,
            priority: .medium,
            folderID: nil,
            triggers: [trigger]
        )
        let reminder = try await reminderService.createReminder(from: draft)

        let completed = try await reminderService.completeReminder(id: reminder.id)
        #expect(completed.status == .completed)
    }

    @MainActor
    @Test func sequentialNextSchedulesReminder() async throws {
        let persistence = PersistenceController(inMemory: true)
        let folderService = FolderService(persistence: persistence)
        let reminderService = ReminderService(persistence: persistence, folderService: folderService)

        let calendar = Calendar.current
        let now = Date()
        let baseFireDate = calendar.date(bySettingHour: 8, minute: 30, second: 0, of: now) ?? now

        let nextTriggerDraft = ReminderTriggerDraft(
            type: .time,
            fireDate: baseFireDate,
            startDate: baseFireDate,
            timeZoneIdentifier: TimeZone.current.identifier,
            weekdayMask: 0,
            isActive: true
        )

        let nextDraft = ReminderDraft(
            title: "Upper body training",
            notes: nil,
            status: .active,
            priority: .medium,
            folderID: nil,
            triggers: [nextTriggerDraft]
        )
        let nextReminder = try await reminderService.createReminder(from: nextDraft)

        let sequential = ReminderTriggerModel.TriggerSequential(
            previousMemoryID: nil,
            nextMemoryID: nextReminder.id
        )
        let sequentialDraft = ReminderTriggerDraft(
            type: .sequential,
            isActive: true,
            sequential: sequential
        )

        let currentDraft = ReminderDraft(
            title: "Leg day",
            notes: nil,
            status: .active,
            priority: .medium,
            folderID: nil,
            triggers: [sequentialDraft]
        )
        let currentReminder = try await reminderService.createReminder(from: currentDraft)

        let completionDate = Date()
        _ = try await reminderService.completeReminder(id: currentReminder.id)
        _ = await reminderService.refresh(force: true)

        let updatedNext = reminderService.fetchReminderWithRelationships(id: nextReminder.id)
        #expect(updatedNext != nil)

        guard
            let updatedNext,
            let timeTrigger = updatedNext.triggers.first(where: { $0.type == .time }),
            let fireDate = timeTrigger.fireDate
        else {
            return
        }

        let scheduledDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: completionDate))!
        let baseComponents = calendar.dateComponents([.hour, .minute, .second], from: baseFireDate)
        let expectedDate = calendar.date(
            bySettingHour: baseComponents.hour ?? 9,
            minute: baseComponents.minute ?? 0,
            second: baseComponents.second ?? 0,
            of: scheduledDay
        )!

        #expect(abs(fireDate.timeIntervalSince(expectedDate)) < 1.5)
        #expect(timeTrigger.startDate == fireDate)
        #expect(updatedNext.status == .active)
    }

    @MainActor
    @Test func sequentialPreviousSchedulesFollower() async throws {
        let persistence = PersistenceController(inMemory: true)
        let folderService = FolderService(persistence: persistence)
        let reminderService = ReminderService(persistence: persistence, folderService: folderService)

        let calendar = Calendar.current
        let now = Date()

        let currentFireDate = calendar.date(bySettingHour: 7, minute: 15, second: 0, of: now) ?? now
        let currentTrigger = ReminderTriggerDraft(
            type: .time,
            fireDate: currentFireDate,
            startDate: currentFireDate,
            timeZoneIdentifier: TimeZone.current.identifier,
            weekdayMask: 0,
            isActive: true
        )

        let currentDraft = ReminderDraft(
            title: "Warm-up session",
            notes: nil,
            status: .active,
            priority: .medium,
            folderID: nil,
            triggers: [currentTrigger]
        )
        let currentReminder = try await reminderService.createReminder(from: currentDraft)

        let followerFireDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: now) ?? now
        let followerTimeTrigger = ReminderTriggerDraft(
            type: .time,
            fireDate: followerFireDate,
            startDate: followerFireDate,
            timeZoneIdentifier: TimeZone.current.identifier,
            weekdayMask: 0,
            isActive: true
        )

        let followerSequential = ReminderTriggerModel.TriggerSequential(
            previousMemoryID: currentReminder.id,
            nextMemoryID: nil
        )
        let followerSequentialDraft = ReminderTriggerDraft(
            type: .sequential,
            isActive: true,
            sequential: followerSequential
        )

        let followerDraft = ReminderDraft(
            title: "Mobility routine",
            notes: nil,
            status: .active,
            priority: .medium,
            folderID: nil,
            triggers: [followerTimeTrigger, followerSequentialDraft]
        )
        let followerReminder = try await reminderService.createReminder(from: followerDraft)

        let completionDate = Date()
        _ = try await reminderService.completeReminder(id: currentReminder.id)
        _ = await reminderService.refresh(force: true)

        let updatedFollower = reminderService.fetchReminderWithRelationships(id: followerReminder.id)
        #expect(updatedFollower != nil)

        guard
            let updatedFollower,
            let timeTrigger = updatedFollower.triggers.first(where: { $0.type == .time }),
            let fireDate = timeTrigger.fireDate
        else {
            return
        }

        let scheduledDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: completionDate))!
        let baseComponents = calendar.dateComponents([.hour, .minute, .second], from: followerFireDate)
        let expectedDate = calendar.date(
            bySettingHour: baseComponents.hour ?? 9,
            minute: baseComponents.minute ?? 0,
            second: baseComponents.second ?? 0,
            of: scheduledDay
        )!

        #expect(abs(fireDate.timeIntervalSince(expectedDate)) < 1.5)
        #expect(timeTrigger.startDate == fireDate)
        #expect(updatedFollower.status == .active)
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
