//
//  ReminderService.swift
//  i-cant-miss
//
//  Created by Codex on 13/10/25.
//

import SwiftUI
import Combine
import CoreData
import os.log

@MainActor
final class ReminderService: ObservableObject {
    enum TimelineFilter: CaseIterable {
        case all
        case overdue
        case today
        case upcoming
    }

    enum ReminderServiceError: Error {
        case reminderNotFound
        case missingTrigger
        case validationFailed(String)
    }

    @Published private(set) var reminders: [ReminderModel] = []
    @Published private(set) var lastRefreshed: Date?

    private let persistence: PersistenceController
    private var refreshTimer: AnyCancellable?
    private let logger = Logger(subsystem: "i-cant-miss", category: "ReminderService")
    private var cache: [TimelineFilter: [ReminderModel]] = [:]
    private var cacheTimestamps: [TimelineFilter: Date] = [:]
    private let cacheTTL: TimeInterval = 30
    private static let spacedIntervals = [1, 3, 7, 14, 30, 60, 90]

    var notificationScheduler: NotificationScheduler?
    var geofenceManager: GeofenceManager?

    init(persistence: PersistenceController) {
        self.persistence = persistence
        configureAutoRefresh()
    }

    func configureAutoRefresh() {
        refreshTimer?.cancel()
        refreshTimer = Timer.publish(every: cacheTTL, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.refresh(force: false)
                }
            }
    }

    @discardableResult
    func refresh(force: Bool) async -> [ReminderModel] {
        if !force, let last = lastRefreshed, Date().timeIntervalSince(last) < cacheTTL {
            return reminders
        }

        let context = persistence.container.viewContext
        do {
            let fetchedModels = try await fetchReminders(in: context)
            reminders = fetchedModels
            lastRefreshed = Date()
            cache.removeAll()
            cacheTimestamps.removeAll()
            if let scheduler = notificationScheduler {
                await scheduler.refreshNotifications(reminders: fetchedModels)
            }
            geofenceManager?.sync(reminders: fetchedModels)
            return fetchedModels
        } catch {
            logger.error("Failed to refresh reminders: \(error.localizedDescription)")
            return reminders
        }
    }

    func reminders(for filter: TimelineFilter) -> [ReminderModel] {
        if let timestamp = cacheTimestamps[filter],
           Date().timeIntervalSince(timestamp) < cacheTTL,
           let cached = cache[filter] {
            return cached
        }

        let values: [ReminderModel]
        switch filter {
        case .all:
            values = reminders
        case .overdue:
            values = reminders.filter { model in
                guard model.status == .active || model.status == .overdue else { return false }
                guard let next = model.nextFireDate() else { return false }
                return next < Date()
            }
        case .today:
            values = reminders.filter { model in
                guard let next = model.nextFireDate() else { return false }
                return Calendar.current.isDate(next, inSameDayAs: Date())
            }
        case .upcoming:
            values = reminders.filter { model in
                guard let next = model.nextFireDate() else { return false }
                return next >= Date().addingTimeInterval(60 * 15)
            }
        }

        cache[filter] = values
        cacheTimestamps[filter] = Date()
        return values
    }

    func createReminder(from draft: ReminderDraft) async throws -> ReminderModel {
        try await withCheckedThrowingContinuation { continuation in
            persistence.performBackgroundTask { context in
                do {
                    let reminder = try self.insertReminder(draft: draft, context: context)
                    let objectID = reminder.objectID
                    try context.save()

                    self.fetchReminder(by: objectID) { result in
                        continuation.resume(with: result)
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func updateReminder(_ model: ReminderModel) async throws -> ReminderModel {
        try await withCheckedThrowingContinuation { continuation in
            persistence.performBackgroundTask { context in
                do {
                    guard let reminder = try self.fetchReminder(by: model.id, context: context) else {
                        throw ReminderServiceError.reminderNotFound
                    }

                    reminder.title = model.title
                    reminder.notes = model.notes
                    reminder.setStatus(model.status)
                    reminder.setPriority(model.priority)
                    reminder.updatedAt = Date()

                    try self.syncTriggers(of: reminder, with: model.triggers, context: context)

                    if let importantModel = model.importantDate {
                        try self.syncImportantDate(for: reminder, model: importantModel, context: context)
                    } else {
                        reminder.importantDate = nil
                    }

                    try context.save()

                    self.fetchReminder(by: reminder.objectID) { result in
                        continuation.resume(with: result)
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func completeReminder(id: UUID) async throws -> ReminderModel {
        try await mutateReminder(id: id) { reminder, _ in
            reminder.setStatus(.completed)
            reminder.lastCompletionDate = Date()
            reminder.updatedAt = Date()
            ReminderService.updatePersonTriggers(reminder, success: true)
        }
    }

    func restoreReminder(id: UUID) async throws -> ReminderModel {
        try await mutateReminder(id: id) { reminder, _ in
            reminder.setStatus(.active)
            reminder.updatedAt = Date()
        }
    }

    func archiveReminder(id: UUID) async throws -> ReminderModel {
        try await mutateReminder(id: id) { reminder, _ in
            reminder.setStatus(.archived)
            reminder.updatedAt = Date()
        }
    }

    func postponeReminder(id: UUID, by interval: TimeInterval) async throws -> ReminderModel {
        try await mutateReminder(id: id) { reminder, _ in
            guard let trigger = reminder.triggerSet.first(where: { $0.triggerType == .time }) else {
                throw ReminderServiceError.missingTrigger
            }
            let newDate = (trigger.fireDate ?? Date()).addingTimeInterval(interval)
            trigger.fireDate = newDate
            trigger.startDate = newDate
            reminder.updatedAt = Date()
            ReminderService.updatePersonTriggers(reminder, success: false)
        }
    }

    func snoozeReminder(id: UUID, by interval: TimeInterval) async throws -> ReminderModel {
        try await mutateReminder(id: id) { reminder, context in
            guard let timeTrigger = reminder.triggerSet.first(where: { $0.triggerType == .time }) else {
                throw ReminderServiceError.missingTrigger
            }
            let now = Date()
            let originalDate = timeTrigger.fireDate ?? now
            let newDate = originalDate.addingTimeInterval(interval)
            timeTrigger.fireDate = newDate
            reminder.snoozeCount += 1
            reminder.updatedAt = now

            let snooze = ReminderSnooze(context: reminder.managedObjectContext ?? context)
            snooze.id = UUID()
            snooze.originalFireDate = originalDate
            snooze.newFireDate = newDate
            snooze.createdAt = now
            snooze.reminder = reminder
            ReminderService.updatePersonTriggers(reminder, success: false)
        }
    }

    func deleteReminder(id: UUID) async throws {
        try await withCheckedThrowingContinuation { continuation in
            persistence.performBackgroundTask { context in
                do {
                    guard let reminder = try self.fetchReminder(by: id, context: context) else {
                        throw ReminderServiceError.reminderNotFound
                    }
                    context.delete(reminder)
                    try context.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
        if let scheduler = notificationScheduler {
            await scheduler.removeNotifications(for: id)
        }
        geofenceManager?.removeGeofences(for: id)
    }

    // MARK: - Private

    private func fetchReminder(by objectID: NSManagedObjectID, completion: @escaping (Result<ReminderModel, Error>) -> Void) {
        let viewContext = persistence.container.viewContext
        viewContext.perform {
            do {
                guard let reminder = try viewContext.existingObject(with: objectID) as? Reminder else {
                    throw ReminderServiceError.reminderNotFound
                }
                completion(.success(reminder.toModel()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    private func mutateReminder(id: UUID, mutation: @escaping (Reminder, NSManagedObjectContext) throws -> Void) async throws -> ReminderModel {
        try await withCheckedThrowingContinuation { continuation in
            persistence.performBackgroundTask { context in
                do {
                    guard let reminder = try self.fetchReminder(by: id, context: context) else {
                        throw ReminderServiceError.reminderNotFound
                    }
                    try mutation(reminder, context)
                    try context.save()
                    self.fetchReminder(by: reminder.objectID) { result in
                        continuation.resume(with: result)
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func fetchReminder(by id: UUID, context: NSManagedObjectContext) throws -> Reminder? {
        let request = Reminder.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private static func updatePersonTriggers(_ reminder: Reminder, success: Bool) {
        for trigger in reminder.triggerSet where trigger.triggerType == .person {
            if success {
                trigger.spacedStage = min(trigger.spacedStage + 1, Int16(spacedIntervals.count - 1))
                trigger.ignoreCount = 0
            } else {
                let newIgnore = trigger.ignoreCount + 1
                if newIgnore >= 2 {
                    trigger.spacedStage = max(trigger.spacedStage - 1, 0)
                    trigger.ignoreCount = 0
                } else {
                    trigger.ignoreCount = newIgnore
                }
            }

            let stageIndex = min(max(Int(trigger.spacedStage), 0), spacedIntervals.count - 1)
            let days = spacedIntervals[stageIndex]
            let nextDate = Calendar.current.date(byAdding: .day, value: days, to: Date())
            trigger.lastReviewDate = Date()
            trigger.fireDate = nextDate
        }
    }

    private func fetchReminders(in context: NSManagedObjectContext) async throws -> [ReminderModel] {
        let request = Reminder.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Reminder.statusRaw, ascending: true),
            NSSortDescriptor(keyPath: \Reminder.userOrder, ascending: true),
            NSSortDescriptor(keyPath: \Reminder.updatedAt, ascending: false)
        ]
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let entities = try context.fetch(request)
                    continuation.resume(returning: entities.map { $0.toModel() })
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func insertReminder(draft: ReminderDraft, context: NSManagedObjectContext) throws -> Reminder {
        guard !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ReminderServiceError.validationFailed("Title is required")
        }
        guard !draft.triggers.isEmpty else {
            throw ReminderServiceError.validationFailed("At least one trigger is required")
        }

        let reminder = Reminder(context: context)
        reminder.id = draft.id
        reminder.title = draft.title
        reminder.notes = draft.notes
        reminder.setStatus(draft.status)
        reminder.setPriority(draft.priority)
        reminder.createdAt = draft.createdAt
        reminder.updatedAt = draft.updatedAt
        reminder.userOrder = 0
        reminder.snoozeCount = 0

        for triggerDraft in draft.triggers {
            let trigger = ReminderTrigger(context: context)
            trigger.id = triggerDraft.id
            trigger.setType(triggerDraft.type)
            trigger.fireDate = triggerDraft.fireDate
            trigger.startDate = triggerDraft.startDate
            trigger.setRecurrence(triggerDraft.recurrenceRule)
            trigger.timeZoneIdentifier = triggerDraft.timeZoneIdentifier
            trigger.weekdayMask = triggerDraft.weekdayMask
            trigger.isActive = triggerDraft.isActive
            trigger.spacedStage = Int16(triggerDraft.spacedStage)
            trigger.lastReviewDate = triggerDraft.lastReviewDate
            trigger.ignoreCount = Int16(triggerDraft.ignoreCount)

            if let location = triggerDraft.location {
                trigger.locationLatitude = location.latitude
                trigger.locationLongitude = location.longitude
                trigger.locationRadius = location.radius
                trigger.locationName = location.name
                trigger.setLocationEvent(location.event)
            }

            if let person = triggerDraft.person {
                trigger.personName = person.name
                trigger.personContactIdentifier = person.contactIdentifier
            }

            reminder.addToTriggers(trigger)
        }

        if let importantDate = draft.importantDate {
            try syncImportantDate(for: reminder, model: importantDate, context: context)
        }

        return reminder
    }

    private func syncTriggers(of reminder: Reminder, with models: [ReminderTriggerModel], context: NSManagedObjectContext) throws {
        let existing = Dictionary(uniqueKeysWithValues: reminder.triggerSet.map { ($0.id, $0) })
        let incoming = Dictionary(uniqueKeysWithValues: models.map { ($0.id, $0) })

        for (id, trigger) in existing where incoming[id] == nil {
            context.delete(trigger)
        }

        for model in models {
            if let trigger = existing[model.id] {
                trigger.setType(model.type)
                trigger.fireDate = model.fireDate
                trigger.startDate = model.startDate
                trigger.setRecurrence(model.recurrenceRule)
                trigger.timeZoneIdentifier = model.timeZoneIdentifier
                trigger.weekdayMask = model.weekdayMask
                trigger.isActive = model.isActive
                trigger.spacedStage = Int16(model.spacedStage)
                trigger.lastReviewDate = model.lastReviewDate
                trigger.ignoreCount = Int16(model.ignoreCount)

                if let location = model.location {
                    trigger.locationLatitude = location.latitude
                    trigger.locationLongitude = location.longitude
                    trigger.locationRadius = location.radius
                    trigger.locationName = location.name
                    trigger.setLocationEvent(location.event)
                } else {
                    trigger.locationLatitude = 0
                    trigger.locationLongitude = 0
                    trigger.locationRadius = 0
                    trigger.locationName = nil
                    trigger.setLocationEvent(nil)
                }

                if let person = model.person {
                    trigger.personName = person.name
                    trigger.personContactIdentifier = person.contactIdentifier
                } else {
                    trigger.personName = nil
                    trigger.personContactIdentifier = nil
                }
            } else {
                let draft = ReminderTriggerDraft(
                    id: model.id,
                    type: model.type,
                    fireDate: model.fireDate,
                    startDate: model.startDate,
                    recurrenceRule: model.recurrenceRule,
                    timeZoneIdentifier: model.timeZoneIdentifier,
                    weekdayMask: model.weekdayMask,
                    isActive: model.isActive,
                    location: model.location,
                    person: model.person,
                    spacedStage: model.spacedStage,
                    lastReviewDate: model.lastReviewDate,
                    ignoreCount: model.ignoreCount
                )
                let trigger = ReminderTrigger(context: context)
                trigger.id = draft.id
                trigger.setType(draft.type)
                trigger.fireDate = draft.fireDate
                trigger.startDate = draft.startDate
                trigger.setRecurrence(draft.recurrenceRule)
                trigger.timeZoneIdentifier = draft.timeZoneIdentifier
                trigger.weekdayMask = draft.weekdayMask
                trigger.isActive = draft.isActive
                trigger.spacedStage = Int16(draft.spacedStage)
                trigger.lastReviewDate = draft.lastReviewDate
                trigger.ignoreCount = Int16(draft.ignoreCount)

                if let location = draft.location {
                    trigger.locationLatitude = location.latitude
                    trigger.locationLongitude = location.longitude
                    trigger.locationRadius = location.radius
                    trigger.locationName = location.name
                    trigger.setLocationEvent(location.event)
                }

                if let person = draft.person {
                    trigger.personName = person.name
                    trigger.personContactIdentifier = person.contactIdentifier
                }

                reminder.addToTriggers(trigger)
            }
        }
    }

    private func syncImportantDate(for reminder: Reminder, model: ImportantDateModel, context: NSManagedObjectContext) throws {
        let entity = reminder.importantDate ?? ImportantDate(context: context)
        entity.id = model.id
        entity.title = model.title
        entity.personName = model.personName
        entity.isBirthday = model.isBirthday
        entity.date = model.date
        entity.createdAt = model.createdAt
        entity.updatedAt = model.updatedAt
        entity.reminder = reminder

        let existingLeadTimes = Dictionary(uniqueKeysWithValues: entity.leadTimeSet.map { ($0.id, $0) })

        for leadModel in model.leadTimes {
            if let leadEntity = existingLeadTimes[leadModel.id] {
                leadEntity.offsetSeconds = Int64(leadModel.offset)
            } else {
                let lead = ImportantDateLeadTime(context: context)
                lead.id = leadModel.id
                lead.offsetSeconds = Int64(leadModel.offset)
                lead.importantDate = entity
            }
        }

        for (id, entity) in existingLeadTimes where !model.leadTimes.contains(where: { $0.id == id }) {
            context.delete(entity)
        }

        reminder.importantDate = entity
    }
}

// MARK: - ReminderModel helpers

extension ReminderModel {
    func nextFireDate(from reference: Date = Date()) -> Date? {
        triggers
            .compactMap { $0.nextFireDate(from: reference) }
            .min()
    }
}

extension ReminderTriggerModel {
    func nextFireDate(from reference: Date = Date()) -> Date? {
        switch type {
        case .time, .importantDate:
            return fireDate
        case .dayOfWeek:
            return nextWeekdayOccurrence(from: reference)
        case .location, .person:
            // Location and person triggers rely on external events; fallback to startDate for ordering.
            return startDate ?? fireDate
        }
    }

    private func nextWeekdayOccurrence(from reference: Date) -> Date? {
        guard weekdayMask != 0 else { return fireDate ?? startDate }
        let calendar = Calendar.current
        let targetDays = (1...7).compactMap { day -> Int? in
            let bit = 1 << day
            return (weekdayMask & Int16(bit)) != 0 ? day : nil
        }

        guard !targetDays.isEmpty else { return fireDate ?? startDate }

        let refDate = reference
        let refWeekday = calendar.component(.weekday, from: refDate)

        for dayOffset in 0..<7 {
            let candidate = calendar.date(byAdding: .day, value: dayOffset, to: refDate) ?? refDate
            let weekday = calendar.component(.weekday, from: candidate)
            if targetDays.contains(weekday) {
                let start = startDate ?? candidate
                return candidate < start ? start : candidate
            }
        }
        return fireDate ?? startDate
    }
}
