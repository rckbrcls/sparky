//
//  DataController.swift
//  sparky
//
//  SwiftData container and context management
//

import Foundation
import SwiftData
import os

@MainActor
final class DataController: Sendable {
    static let shared = DataController()

    static let preview: DataController = {
        let controller = DataController(inMemory: true)
        controller.seedPreviewData()
        return controller
    }()

    private static let logger = Logger(subsystem: "sparky", category: "DataController")

    let container: ModelContainer
    let modelContext: ModelContext

    init(inMemory: Bool = false) {
        let schema = Schema([
            Mind.self,
            Memory.self,
            Tag.self,
            CheckItemModel.self,
            ScheduleConfig.self,
            LocationConfig.self,
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
        } catch {
            Self.logger.critical("Failed to create ModelContainer: \(error.localizedDescription). Falling back to in-memory store.")
            let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            // If even the fallback fails, there is nothing we can do.
            // swiftlint:disable:next force_try
            container = try! ModelContainer(for: schema, configurations: [fallbackConfig])
        }

        modelContext = container.mainContext
        modelContext.autosaveEnabled = true
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

        let personalMind = Mind(
            id: UUID(),
            name: "Personal",
            colorHex: "#4F46E5",
            iconName: "person",
            sortOrder: 0,
            isDefault: true
        )

        let workMind = Mind(
            id: UUID(),
            name: "Work",
            colorHex: "#10B981",
            iconName: "briefcase",
            sortOrder: 1,
            isDefault: false
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
            mind: workMind
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
            mind: personalMind
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

        modelContext.insert(personalMind)
        modelContext.insert(workMind)
        modelContext.insert(swiftTag)
        modelContext.insert(designTag)
        modelContext.insert(noteMemory)
        modelContext.insert(reminderMemory)
        modelContext.insert(todoMemory)
        modelContext.insert(birthdayMemory)

        save()
    }
}
