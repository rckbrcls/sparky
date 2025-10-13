//
//  Persistence.swift
//  i-cant-miss
//
//  Created by Erick Barcelos on 13/10/25.
//

import CoreData

final class PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        controller.seedPreviewData()
        return controller
    }()

    let container: NSPersistentContainer
    let backgroundContext: NSManagedObjectContext

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "i_cant_miss")
        if let description = container.persistentStoreDescriptions.first {
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            if inMemory {
                description.url = URL(fileURLWithPath: "/dev/null")
            } else {
                // Configure store location explicitly
                description.shouldMigrateStoreAutomatically = true
                description.shouldInferMappingModelAutomatically = true
            }
        }

        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Unresolved CoreData error \(error)")
            }
        }

        // Enhanced merge policies for better data consistency
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.transactionAuthor = "main"
        container.viewContext.undoManager = nil // Disable undo for better performance

        // Ensure changes are immediately visible
        container.viewContext.stalenessInterval = 0

        backgroundContext = container.newBackgroundContext()
        backgroundContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        backgroundContext.automaticallyMergesChangesFromParent = true
        backgroundContext.transactionAuthor = "background"
        backgroundContext.undoManager = nil

        // Setup notification observers for context synchronization
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contextDidSave(_:)),
            name: .NSManagedObjectContextDidSave,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func contextDidSave(_ notification: Notification) {
        guard let context = notification.object as? NSManagedObjectContext,
              context !== container.viewContext else {
            return
        }

        container.viewContext.perform {
            self.container.viewContext.mergeChanges(fromContextDidSave: notification)
        }
    }

    func save(context: NSManagedObjectContext? = nil) {
        let context = context ?? container.viewContext
        guard context.hasChanges else { return }
        do {
            try context.save()
            // Force refresh view context to ensure UI updates
            if context !== container.viewContext {
                container.viewContext.perform {
                    self.container.viewContext.refreshAllObjects()
                }
            }
        } catch {
            let nsError = error as NSError
            assertionFailure("Unresolved CoreData error \(nsError), \(nsError.userInfo)")
        }
    }

    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        container.performBackgroundTask { context in
            context.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
            block(context)
            if context.hasChanges {
                do {
                    try context.save()

                    // Wait for the save notification to be processed
                    // The contextDidSave observer will handle the merge
                } catch {
                    let nsError = error as NSError
                    assertionFailure("Failed to save background context \(nsError), \(nsError.userInfo)")
                }
            }
        }
    }
}

// MARK: - Preview seeding

private extension PersistenceController {
    func seedPreviewData() {
        let context = container.viewContext
        let calendar = Calendar.current
        let now = Date()

        let defaultFolder = Folder(context: context)
        defaultFolder.id = UUID()
        defaultFolder.name = "Personal"
        defaultFolder.iconName = "person"
        defaultFolder.colorHex = "#4F46E5"
        defaultFolder.isDefault = true
        defaultFolder.sortOrder = 0

        let workFolder = Folder(context: context)
        workFolder.id = UUID()
        workFolder.name = "Work"
        workFolder.iconName = "briefcase"
        workFolder.colorHex = "#10B981"
        workFolder.isDefault = false
        workFolder.sortOrder = 1

        let swiftTag = Tag(context: context)
        swiftTag.id = UUID()
        swiftTag.name = "SwiftUI"
        swiftTag.colorHex = "#F97316"

        let designTag = Tag(context: context)
        designTag.id = UUID()
        designTag.name = "Design"
        designTag.colorHex = "#EC4899"

        let note = Note(context: context)
        note.id = UUID()
        note.title = "Ideas for next release"
        note.content = """
        • Improve timeline grouping
        • Add quick templates for recurring reminders
        • Experiment with AI powered suggestions
        """
        note.createdAt = now
        note.updatedAt = now
        note.isPinned = true
        note.folder = workFolder
        note.addToTags(NSSet(array: [swiftTag, designTag]))

        let reminder = Reminder(context: context)
        reminder.id = UUID()
        reminder.title = "Send status update to Maya"
        reminder.notes = "Include metrics and next week's plan."
        reminder.setStatus(.active)
        reminder.setPriority(.high)
        reminder.createdAt = now
        reminder.updatedAt = now
        reminder.userOrder = 0
        reminder.snoozeCount = 1

        let timeTrigger = ReminderTrigger(context: context)
        timeTrigger.id = UUID()
        timeTrigger.setType(.time)
        timeTrigger.fireDate = calendar.date(byAdding: .hour, value: 3, to: now)
        timeTrigger.startDate = now
        timeTrigger.setRecurrence(RecurrenceRule(frequency: .weekly, interval: 1))
        timeTrigger.timeZoneIdentifier = TimeZone.current.identifier
        timeTrigger.weekdayMask = 0
        timeTrigger.isActive = true
        timeTrigger.locationLatitude = 0
        timeTrigger.locationLongitude = 0
        timeTrigger.locationRadius = 0
        timeTrigger.spacedStage = 0
        timeTrigger.ignoreCount = 0
        reminder.addToTriggers(timeTrigger)

        let locationTrigger = ReminderTrigger(context: context)
        locationTrigger.id = UUID()
        locationTrigger.setType(.location)
        locationTrigger.isActive = true
        locationTrigger.locationLatitude = 37.3327
        locationTrigger.locationLongitude = -122.0053
        locationTrigger.locationRadius = 150
        locationTrigger.locationName = "Apple Park"
        locationTrigger.setLocationEvent(.onEntry)
        locationTrigger.spacedStage = 0
        locationTrigger.ignoreCount = 0
        reminder.addToTriggers(locationTrigger)

        let snooze = ReminderSnooze(context: context)
        snooze.id = UUID()
        snooze.originalFireDate = now
        snooze.newFireDate = calendar.date(byAdding: .minute, value: 30, to: now) ?? now
        snooze.createdAt = now
        reminder.addToSnoozes(snooze)

        let birthdayReminder = Reminder(context: context)
        birthdayReminder.id = UUID()
        birthdayReminder.title = "Celebrate Leo's birthday"
        birthdayReminder.notes = "Pick up a gift and write a card."
        birthdayReminder.setStatus(.active)
        birthdayReminder.setPriority(.medium)
        birthdayReminder.createdAt = now
        birthdayReminder.updatedAt = now
        birthdayReminder.userOrder = 1
        birthdayReminder.snoozeCount = 0

        let importantDate = ImportantDate(context: context)
        importantDate.id = UUID()
        importantDate.title = "Leo's Birthday"
        importantDate.personName = "Leo"
        importantDate.isBirthday = true
        importantDate.date = calendar.nextDate(after: now, matching: DateComponents(month: 11, day: 5), matchingPolicy: .nextTimePreservingSmallerComponents) ?? now
        importantDate.createdAt = now
        importantDate.updatedAt = now
        importantDate.reminder = birthdayReminder

        let oneWeekLead = ImportantDateLeadTime(context: context)
        oneWeekLead.id = UUID()
        oneWeekLead.offsetSeconds = Int64(7 * 24 * 60 * 60)
        oneWeekLead.importantDate = importantDate

        let oneDayLead = ImportantDateLeadTime(context: context)
        oneDayLead.id = UUID()
        oneDayLead.offsetSeconds = Int64(24 * 60 * 60)
        oneDayLead.importantDate = importantDate

        importantDate.addToLeadTimes(NSSet(array: [oneWeekLead, oneDayLead]))

        save(context: context)
    }
}
