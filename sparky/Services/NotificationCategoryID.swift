//
//  NotificationCategoryID.swift
//  sparky
//

import Foundation
import UserNotifications

enum NotificationCategoryID {
    static let reminderActions = "REMINDER_ACTIONS"
    static let scheduleFocusActions = "SCHEDULE_FOCUS_ACTIONS"
}

enum NotificationActionID {
    static let startFocus = "START_FOCUS"
}

enum NotificationUserInfoKey {
    static let memoryID = "memoryID"
    static let focusEnabled = "focusEnabled"
}

@MainActor
enum NotificationCategoryRegistrar {
    static func registerAll() {
        let openMemory = UNNotificationCategory(
            identifier: NotificationCategoryID.reminderActions,
            actions: [],
            intentIdentifiers: [],
            options: []
        )

        let startFocus = UNNotificationAction(
            identifier: NotificationActionID.startFocus,
            title: "Start Focus",
            options: [.foreground]
        )

        let scheduleFocus = UNNotificationCategory(
            identifier: NotificationCategoryID.scheduleFocusActions,
            actions: [startFocus],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([openMemory, scheduleFocus])
    }
}
