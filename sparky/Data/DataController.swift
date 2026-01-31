//
//  DataController.swift
//  sparky
//
//  SwiftData container and context management
//

import Foundation
import SwiftData

@MainActor
final class DataController: Sendable {
    static let shared = DataController()

    static let preview: DataController = {
        let controller = DataController(inMemory: true)
        controller.seedPreviewData()
        return controller
    }()

    let container: ModelContainer
    let modelContext: ModelContext

    private static let migrationVersionKey = "sparky.triggerMigrationVersion"
    private static let currentMigrationVersion = 1

    init(inMemory: Bool = false) {
        let schema = Schema([
            Mind.self,
            Space.self,
            Memory.self,
            Tag.self,
            CheckItemModel.self,
            // New trigger config models
            ScheduleConfig.self,
            LocationConfig.self,
            // Legacy trigger models (kept for migration)
            MemoryTriggerModel.self,
            MemoryTriggerLocation.self,
            MemoryAttachmentReference.self,
            MemoryCompletionDate.self
        ])

        let modelConfiguration: ModelConfiguration
        if inMemory {
            modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true
            )
        } else {
            modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true
            )
        }

        do {
            container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            modelContext = container.mainContext
            modelContext.autosaveEnabled = true

            // Run migration if needed
            if !inMemory {
                migrateTriggersIfNeeded()
            }
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    // MARK: - Migration

    private func migrateTriggersIfNeeded() {
        let currentVersion = UserDefaults.standard.integer(forKey: Self.migrationVersionKey)
        guard currentVersion < Self.currentMigrationVersion else { return }

        do {
            var descriptor = FetchDescriptor<Memory>()
            descriptor.includePendingChanges = true
            let memories = try modelContext.fetch(descriptor)

            for memory in memories {
                migrateMemoryTriggers(memory)
            }

            if modelContext.hasChanges {
                try modelContext.save()
            }

            UserDefaults.standard.set(Self.currentMigrationVersion, forKey: Self.migrationVersionKey)
        } catch {
            assertionFailure("Migration failed: \(error)")
        }
    }

    private func migrateMemoryTriggers(_ memory: Memory) {
        // Skip if already migrated (has new config models)
        if memory.scheduleConfig != nil || memory.locationConfig != nil {
            return
        }

        // Migrate scheduled triggers
        if let scheduledTrigger = memory.triggers.first(where: { $0.type == .scheduled && $0.isActive }) {
            let scheduleConfig = ScheduleConfig(
                id: scheduledTrigger.id,
                fireDate: scheduledTrigger.fireDate,
                startDate: scheduledTrigger.startDate,
                recurrenceRule: scheduledTrigger.recurrenceRule,
                timeZoneIdentifier: scheduledTrigger.timeZoneIdentifier,
                weekdayMask: scheduledTrigger.weekdayMask,
                isActive: scheduledTrigger.isActive,
                isAllDay: scheduledTrigger.isAllDay,
                memory: memory
            )
            memory.scheduleConfig = scheduleConfig
        }

        // Migrate location triggers
        if let locationTrigger = memory.triggers.first(where: { $0.type == .location && $0.isActive }),
           let location = locationTrigger.location {
            let locationConfig = LocationConfig(
                id: locationTrigger.id,
                latitude: location.latitude,
                longitude: location.longitude,
                radius: location.radius,
                name: location.name,
                event: location.event,
                isActive: locationTrigger.isActive,
                memory: memory
            )
            memory.locationConfig = locationConfig
        }

        // Note: Sequential triggers are intentionally not migrated (being removed)
    }

    func save() {
        guard modelContext.hasChanges else { return }
        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save context: \(error)")
        }
    }

    func newBackgroundContext() -> ModelContext {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }

    func performBackgroundTask(_ block: @escaping @Sendable (ModelContext) throws -> Void) {
        Task.detached {
            let context = ModelContext(self.container)
            context.autosaveEnabled = false
            do {
                try block(context)
                if context.hasChanges {
                    try context.save()
                }
            } catch {
                assertionFailure("Background task failed: \(error)")
            }
        }
    }

    func performBackgroundTaskAsync<T: Sendable>(_ block: @escaping @Sendable (ModelContext) throws -> T) async throws -> T {
        try await Task.detached {
            let context = ModelContext(self.container)
            context.autosaveEnabled = false
            let result = try block(context)
            if context.hasChanges {
                try context.save()
            }
            return result
        }.value
    }
}

// MARK: - Preview seeding

extension DataController {
    func seedPreviewData() {
        let calendar = Calendar.current
        let now = Date()

        let defaultSpace = Space(
            id: UUID(),
            name: "Personal",
            colorHex: "#4F46E5",
            iconName: "person",
            sortOrder: 0,
            isDefault: true,
           
        )

        let workSpace = Space(
            id: UUID(),
            name: "Work",
            colorHex: "#10B981",
            iconName: "briefcase",
            sortOrder: 1,
            isDefault: false,
        )

        let swiftTag = Tag(
            id: UUID(),
            name: "SwiftUI",
            colorHex: "#F97316"
        )

        let designTag = Tag(
            id: UUID(),
            name: "Design",
            colorHex: "#EC4899"
        )

        let noteMemory = Memory(
            id: UUID(),
            title: "Ideas for next release",
            body: """
            • Improve timeline grouping
            • Add quick templates for recurring reminders
            • Experiment with AI powered suggestions
            """,
            statusRaw: "active",
            isPinned: true,
            createdAt: now,
            updatedAt: now,
            autoCompleteOnChecklistCompletion: false,
            space: workSpace
        )

        let reminderMemory = Memory(
            id: UUID(),
            title: "Send status update to Maya",
            body: "Include metrics and next week's plan.",
            statusRaw: "active",
            isPinned: false,
            priorityRaw: 2,
            createdAt: now,
            updatedAt: now,
            autoCompleteOnChecklistCompletion: false
        )

        let todoMemory = Memory(
            id: UUID(),
            title: "Weekend errands",
            body: "Finish before Sunday afternoon.",
            statusRaw: "active",
            isPinned: true,
            dueDate: calendar.date(byAdding: .day, value: 2, to: now),
            createdAt: now,
            updatedAt: now,
            autoCompleteOnChecklistCompletion: true,
            space: defaultSpace
        )

        let birthdayMemory = Memory(
            id: UUID(),
            title: "Celebrate Leo's birthday",
            body: "Pick up a gift and write a card.",
            statusRaw: "active",
            isPinned: false,
            priorityRaw: 1,
            createdAt: now,
            updatedAt: now,
            autoCompleteOnChecklistCompletion: false
        )

        modelContext.insert(defaultSpace)
        modelContext.insert(workSpace)
        modelContext.insert(swiftTag)
        modelContext.insert(designTag)
        modelContext.insert(noteMemory)
        modelContext.insert(reminderMemory)
        modelContext.insert(todoMemory)
        modelContext.insert(birthdayMemory)

        save()
    }
}
