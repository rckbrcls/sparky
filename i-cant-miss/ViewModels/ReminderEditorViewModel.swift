//
//  ReminderEditorViewModel.swift
//  i-cant-miss
//
//  Created by Codex on 13/10/25.
//

import Foundation
import Combine

@MainActor
final class ReminderEditorViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var notes: String = ""
    @Published var priority: ReminderPriority = .medium
    @Published var status: ReminderStatus = .active
    @Published var triggers: [ReminderTriggerDraft] = []
    @Published var importantDate: ImportantDateModel?
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?

    private let environment: AppEnvironment
    private let existingReminderID: UUID?

    init(environment: AppEnvironment, reminder: ReminderModel?) {
        self.environment = environment
        self.existingReminderID = reminder?.id

        // Load data immediately in init to ensure it's available when view appears
        // First try to fetch fresh data from Core Data with relationships
        if let reminderId = reminder?.id,
           let freshReminder = environment.reminderService.fetchReminderWithRelationships(id: reminderId) {
            self.title = freshReminder.title
            self.notes = freshReminder.notes ?? ""
            self.priority = freshReminder.priority
            self.status = freshReminder.status
            self.triggers = freshReminder.triggers.map(ReminderEditorViewModel.draft(from:))
            self.importantDate = freshReminder.importantDate
        } else if let reminderId = reminder?.id,
                  let existingReminder = environment.reminderService.reminders.first(where: { $0.id == reminderId }) {
            self.title = existingReminder.title
            self.notes = existingReminder.notes ?? ""
            self.priority = existingReminder.priority
            self.status = existingReminder.status
            self.triggers = existingReminder.triggers.map(ReminderEditorViewModel.draft(from:))
            self.importantDate = existingReminder.importantDate
        } else {
            // New reminder or not found in service - use defaults
            self.title = reminder?.title ?? ""
            self.notes = reminder?.notes ?? ""
            self.priority = reminder?.priority ?? environment.settings.defaultReminderPriority
            self.status = reminder?.status ?? .active
            self.triggers = reminder?.triggers.map(ReminderEditorViewModel.draft(from:)) ?? []
            self.importantDate = reminder?.importantDate
        }
    }
    func loadData() {
        // Reload data from the existing reminder to ensure all relationships are populated
        if let reminderId = existingReminderID,
           let updatedReminder = environment.reminderService.reminders.first(where: { $0.id == reminderId }) {
            self.title = updatedReminder.title
            self.notes = updatedReminder.notes ?? ""
            self.priority = updatedReminder.priority
            self.status = updatedReminder.status
            self.triggers = updatedReminder.triggers.map(ReminderEditorViewModel.draft(from:))
            self.importantDate = updatedReminder.importantDate
        }
    }

    var existingReminder: ReminderModel? {
        guard let reminderId = existingReminderID else { return nil }
        return environment.reminderService.reminders.first(where: { $0.id == reminderId })
    }

    func addTimeTrigger(date: Date, recurrence: RecurrenceRule?) {
        let draft = ReminderTriggerDraft(
            type: .time,
            fireDate: date,
            startDate: Date(),
            recurrenceRule: recurrence,
            timeZoneIdentifier: TimeZone.current.identifier
        )
        triggers.append(draft)
    }

    func addWeekdayTrigger(selectedWeekdays: [Int]) {
        let mask = selectedWeekdays.reduce(into: Int16(0)) { partialResult, day in
            let bit = Int16(1 << day)
            partialResult |= bit
        }
        let draft = ReminderTriggerDraft(
            type: .dayOfWeek,
            fireDate: nil,
            startDate: Date(),
            weekdayMask: mask
        )
        triggers.append(draft)
    }

    func addLocationTrigger(name: String, latitude: Double, longitude: Double, radius: Double, event: LocationEvent) {
        let draft = ReminderTriggerDraft(
            type: .location,
            fireDate: nil,
            startDate: Date(),
            recurrenceRule: nil,
            timeZoneIdentifier: TimeZone.current.identifier,
            weekdayMask: 0,
            isActive: true,
            location: .init(latitude: latitude, longitude: longitude, radius: radius, name: name, event: event)
        )
        triggers.append(draft)
    }

    func addPersonTrigger(name: String, identifier: String?) {
        let draft = ReminderTriggerDraft(
            type: .person,
            fireDate: nil,
            startDate: Date(),
            person: .init(name: name, contactIdentifier: identifier),
            spacedStage: 0,
            ignoreCount: 0
        )
        triggers.append(draft)
    }

    func removeTrigger(id: UUID) {
        triggers.removeAll { $0.id == id }
    }

    func updateTrigger(id: UUID, with updatedDraft: ReminderTriggerDraft) {
        if let index = triggers.firstIndex(where: { $0.id == id }) {
            triggers[index] = updatedDraft
        }
    }

    func save() async -> Bool {
        do {
            guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                errorMessage = "Reminder title is required."
                return false
            }
            guard !triggers.isEmpty else {
                errorMessage = "Add at least one trigger."
                return false
            }
            isSaving = true
            defer { isSaving = false }

            if let reminder = existingReminder {
                var updated = reminder
                updated.title = title
                updated.notes = notes
                updated.status = status
                updated.priority = priority
                updated.triggers = triggers.map { $0.toModel() }
                updated.importantDate = importantDate
                updated.updatedAt = Date()

                _ = try await environment.reminderService.updateReminder(updated)
            } else {
                let draft = ReminderDraft(
                    title: title,
                    notes: notes,
                    status: status,
                    priority: priority,
                    createdAt: Date(),
                    updatedAt: Date(),
                    triggers: triggers,
                    importantDate: importantDate
                )
                _ = try await environment.reminderService.createReminder(from: draft)
            }

            await environment.reminderService.refresh(force: true)
            return true
        } catch {
            errorMessage = "Failed to save reminder."
            return false
        }
    }

    private static func draft(from model: ReminderTriggerModel) -> ReminderTriggerDraft {
        ReminderTriggerDraft(
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
    }
}
