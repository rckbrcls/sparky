//
//  FocusNotificationService.swift
//  sparky
//

import Foundation
import UserNotifications
import os

@MainActor
final class FocusNotificationService {
    nonisolated private static let logger = Logger(subsystem: "sparky", category: "FocusNotificationService")
    private let center = UNUserNotificationCenter.current()
    private let settings: SettingsStore

    init(settings: SettingsStore) {
        self.settings = settings
    }

    func sendWorkComplete() {
        send(title: "Focus complete", body: "Time for a break.")
    }

    func sendBreakComplete() {
        send(title: "Break over", body: "Ready for another focus block?")
    }

    private func send(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = settings.notificationSoundEnabled ? .default : nil

        let request = UNNotificationRequest(
            identifier: "focus-phase-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        center.add(request) { error in
            if let error {
                Self.logger.error("Focus notification failed: \(error.localizedDescription)")
            }
        }
    }
}
