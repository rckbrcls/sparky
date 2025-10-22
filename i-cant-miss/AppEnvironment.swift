//
//  AppEnvironment.swift
//  i-cant-miss
//
//  Created by Codex on 13/10/25.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class AppEnvironment: ObservableObject {
    let persistence: PersistenceController
    let folderService: FolderService
    let spaceService: SpaceService
    let reminderService: ReminderService
    let noteService: NoteService
    let todoService: TodoService
    let memoryService: MemoryService
    let notificationScheduler: NotificationScheduler
    let geofenceManager: GeofenceManager
    let settings: SettingsStore

    @Published var isBootstrapping = true
    @Published var hasBootstrapped = false

    init(persistence: PersistenceController) {
        self.persistence = persistence
        self.settings = SettingsStore()

        // Initialize services - they will load data synchronously in their init
        self.folderService = FolderService(persistence: persistence)
        self.spaceService = SpaceService(persistence: persistence)
        self.reminderService = ReminderService(persistence: persistence, folderService: folderService)
        self.noteService = NoteService(persistence: persistence, folderService: folderService)
        self.todoService = TodoService(persistence: persistence, folderService: folderService)
        self.memoryService = MemoryService(persistence: persistence, spaceService: spaceService)
        self.notificationScheduler = NotificationScheduler(settings: settings)
        self.geofenceManager = GeofenceManager()

        reminderService.notificationScheduler = notificationScheduler
        reminderService.geofenceManager = geofenceManager
        memoryService.notificationScheduler = notificationScheduler
        memoryService.geofenceManager = geofenceManager
        geofenceManager.notificationScheduler = notificationScheduler

        // Mark initialization as complete
        self.isBootstrapping = false
    }

    func bootstrap() {
        guard !hasBootstrapped else { return }

        Task {
            isBootstrapping = true

            // Perform a force refresh to ensure data is up-to-date
            async let foldersTask = folderService.refreshFolders(force: true)
            async let tagsTask = folderService.refreshTags(force: true)
            async let spacesTask = spaceService.refresh(force: true)
            async let remindersTask = reminderService.refresh(force: true)
            async let notesTask = noteService.refresh(force: true)
            async let todosTask = todoService.refresh(force: true)
            async let memoriesTask = memoryService.refresh(force: true)

            _ = await (foldersTask, tagsTask, spacesTask, remindersTask, notesTask, todosTask, memoriesTask)

            await notificationScheduler.requestAuthorizationIfNeeded()

            hasBootstrapped = true
            isBootstrapping = false
        }
    }
}
