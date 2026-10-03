//
//  ScheduledTriggerExecutor.swift
//  sparky
//
//  Created by Codex on 13/10/25.
//

import Foundation
import UserNotifications
import os

@MainActor
final class ScheduledTriggerExecutor: TriggerExecutorProtocol {
    private static let logger = Logger(subsystem: "sparky", category: "ScheduledTriggerExecutor")
    private let center = UNUserNotificationCenter.current()
    private var hasRequestedAuthorization = false
    private let settings: SettingsStore

    init(settings: SettingsStore) {
        self.settings = settings
    }

    func requestAuthorizationIfNeeded() async {
        guard !hasRequestedAuthorization else { return }
        let options: UNAuthorizationOptions = [.alert, .badge, .sound]
        do {
            let granted = try await center.requestAuthorization(options: options)
            if !granted {
                Self.logger.info("Notification authorization not granted by user.")
            }
            hasRequestedAuthorization = true
        } catch {
            Self.logger.error("Notification authorization failed: \(error.localizedDescription)")
        }
    }

    func requestAuthorization(force: Bool) async {
        if force {
            hasRequestedAuthorization = false
        }
        await requestAuthorizationIfNeeded()
    }

    func register(config: ScheduleConfig, for memory: Memory) async {
        await requestAuthorizationIfNeeded()
        guard config.isActive, memory.status == .active else {
            await unregister(triggerID: config.id, for: memory.id)
            return
        }

        await unregister(triggerID: config.id, for: memory.id)

        let requests = ScheduledTriggerPlanner.plans(
            for: memory,
            now: Date(),
            calendar: .current
        ).map(makeRequest)

        do {
            try await center.add(requests: requests)
        } catch {
            Self.logger.error("Failed to schedule notifications: \(error.localizedDescription)")
        }
    }

    func unregister(triggerID: UUID, for memoryID: UUID) async {
        let identifiers = await pendingIdentifiers()
            .filter { $0.contains(memoryID.uuidString) && $0.contains(triggerID.uuidString) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func unregisterAll(for memoryID: UUID) async {
        let identifiers = await pendingIdentifiers()
            .filter { $0.contains(memoryID.uuidString) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func sync(memories: [Memory]) async {
        await requestAuthorizationIfNeeded()
        let identifiers = await pendingIdentifiers()
        center.removePendingNotificationRequests(withIdentifiers: identifiers)

        for memory in memories {
            guard memory.status == .active else {
                continue
            }

            if let config = memory.scheduleConfig, config.isActive {
                await register(config: config, for: memory)
            }
        }
    }

    private func makeRequest(from plan: ScheduledNotificationPlan) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = plan.title
        if let body = plan.body {
            content.body = body
        }
        content.sound = settings.notificationSound.notificationSound
        content.categoryIdentifier = plan.categoryIdentifier
        content.threadIdentifier = plan.memoryID.uuidString
        content.userInfo = [
            NotificationUserInfoKey.memoryID: plan.memoryID.uuidString,
            NotificationUserInfoKey.focusEnabled: plan.focusEnabled
        ]
        return UNNotificationRequest(
            identifier: plan.identifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: plan.dateComponents, repeats: plan.repeats)
        )
    }

    private func pendingIdentifiers() async -> [String] {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests.map(\.identifier))
            }
        }
    }

}

private extension UNUserNotificationCenter {
    func add(requests: [UNNotificationRequest]) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for request in requests {
                group.addTask {
                    try await self.add(request)
                }
            }
            try await group.waitForAll()
        }
    }

    func add(_ request: UNNotificationRequest) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            add(request) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}
