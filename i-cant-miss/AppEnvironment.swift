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
    let reminderService: ReminderService
    let noteService: NoteService
    let notificationScheduler: NotificationScheduler
    let geofenceManager: GeofenceManager

    init(persistence: PersistenceController) {
        self.persistence = persistence
        self.folderService = FolderService(persistence: persistence)
        self.reminderService = ReminderService(persistence: persistence)
        self.noteService = NoteService(persistence: persistence, folderService: folderService)
        self.notificationScheduler = NotificationScheduler()
        self.geofenceManager = GeofenceManager()

        reminderService.notificationScheduler = notificationScheduler
        reminderService.geofenceManager = geofenceManager
        geofenceManager.notificationScheduler = notificationScheduler
    }

    func bootstrap() {
        Task {
            await folderService.refreshFolders(force: true)
            await folderService.refreshTags(force: true)
            await reminderService.refresh(force: true)
            await noteService.refresh(force: true)
            await notificationScheduler.requestAuthorizationIfNeeded()
        }
    }
}
