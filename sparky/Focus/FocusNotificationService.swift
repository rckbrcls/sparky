//
//  FocusNotificationService.swift
//  sparky
//

import Foundation
import UserNotifications
import os

@MainActor
final class FocusNotificationService: FocusNotificationSending {
    nonisolated private static let logger = Logger(
        subsystem: "sparky",
        category: "FocusNotificationService"
    )

    private let center: UNUserNotificationCenter
    private let settings: FocusSettings

    init(
        settings: FocusSettings,
        center: UNUserNotificationCenter = .current()
    ) {
        self.settings = settings
        self.center = center
    }

    func sendCompletion(for event: FocusFeedbackEvent) throws {
        guard let request = makeRequest(for: event) else { return }

        center.add(request) { error in
            if let error {
                Self.logger.error(
                    "Focus notification failed: \(error.localizedDescription)"
                )
            }
        }
    }

    func makeRequest(for event: FocusFeedbackEvent) -> UNNotificationRequest? {
        guard settings.notificationsEnabled else { return nil }

        let title: String
        let body: String
        switch event {
        case .focusComplete:
            title = "Focus complete"
            body = "Time for a break."
        case .breakComplete:
            title = "Break over"
            body = "Ready for another focus block?"
        case .startOrResume, .pause, .end:
            return nil
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = nil

        return UNNotificationRequest(
            identifier: "focus-phase-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
    }
}
