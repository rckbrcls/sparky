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

        let defaultSpace = Space(context: context)
        defaultSpace.id = UUID()
        defaultSpace.name = "Personal"
        defaultSpace.iconName = "person"
        defaultSpace.colorHex = "#4F46E5"
        defaultSpace.isDefault = true
        defaultSpace.sortOrder = 0

        let workSpace = Space(context: context)
        workSpace.id = UUID()
        workSpace.name = "Work"
        workSpace.iconName = "briefcase"
        workSpace.colorHex = "#10B981"
        workSpace.isDefault = false
        workSpace.sortOrder = 1

        let swiftTag = Tag(context: context)
        swiftTag.id = UUID()
        swiftTag.name = "SwiftUI"
        swiftTag.colorHex = "#F97316"

        let designTag = Tag(context: context)
        designTag.id = UUID()
        designTag.name = "Design"
        designTag.colorHex = "#EC4899"

        // Create sample memory for notes functionality
        let noteMemory = Memory(context: context)
        noteMemory.id = UUID()
        noteMemory.title = "Ideas for next release"
        noteMemory.body = """
        • Improve timeline grouping
        • Add quick templates for recurring reminders
        • Experiment with AI powered suggestions
        """
        noteMemory.createdAt = now
        noteMemory.updatedAt = now
        noteMemory.isPinned = true
        noteMemory.statusRaw = "active"
        noteMemory.space = workSpace
        noteMemory.autoCompleteOnChecklistCompletion = false

        // Create sample memory with time trigger (reminder functionality)
        let reminderMemory = Memory(context: context)
        reminderMemory.id = UUID()
        reminderMemory.title = "Send status update to Maya"
        reminderMemory.body = "Include metrics and next week's plan."
        reminderMemory.statusRaw = "active"
        reminderMemory.isPinned = false
        reminderMemory.priorityRaw = NSNumber(value: 2) // High priority
        reminderMemory.createdAt = now
        reminderMemory.updatedAt = now
        reminderMemory.autoCompleteOnChecklistCompletion = false

        // Create sample memory with checklist (todo functionality)
        let todoMemory = Memory(context: context)
        todoMemory.id = UUID()
        todoMemory.title = "Weekend errands"
        todoMemory.body = "Finish before Sunday afternoon."
        todoMemory.createdAt = now
        todoMemory.updatedAt = now
        todoMemory.dueDate = calendar.date(byAdding: .day, value: 2, to: now)
        todoMemory.isPinned = true
        todoMemory.statusRaw = "active"
        todoMemory.space = defaultSpace
        todoMemory.autoCompleteOnChecklistCompletion = true

        // Create another sample memory with birthday reminder
        let birthdayMemory = Memory(context: context)
        birthdayMemory.id = UUID()
        birthdayMemory.title = "Celebrate Leo's birthday"
        birthdayMemory.body = "Pick up a gift and write a card."
        birthdayMemory.statusRaw = "active"
        birthdayMemory.isPinned = false
        birthdayMemory.priorityRaw = NSNumber(value: 1) // Medium priority
        birthdayMemory.createdAt = now
        birthdayMemory.updatedAt = now
        birthdayMemory.autoCompleteOnChecklistCompletion = false

        save(context: context)
    }
}
