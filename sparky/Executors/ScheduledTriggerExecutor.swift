//
//  ScheduledTriggerExecutor.swift
//  sparky
//
//  Created by Codex on 13/10/25.
//

import Foundation
import UserNotifications

@MainActor
final class ScheduledTriggerExecutor {
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
                print("Notifications not granted.")
            }
            hasRequestedAuthorization = true
        } catch {
            print("Notification authorization failed: \(error.localizedDescription)")
        }
    }

    func requestAuthorization(force: Bool) async {
        if force {
            hasRequestedAuthorization = false
        }
        await requestAuthorizationIfNeeded()
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
                await unregisterAll(for: memory.id)
                continue
            }

            // Use the new scheduleConfig
            guard let config = memory.scheduleConfig, config.isActive else { continue }
            await registerScheduleConfig(config, for: memory)
        }
    }

    private func registerScheduleConfig(_ config: ScheduleConfig, for memory: Memory) async {
        let content = UNMutableNotificationContent()
        content.title = memory.title
        if let body = memory.body {
            content.body = body
        }
        content.sound = settings.notificationSoundEnabled ? .default : nil
        content.categoryIdentifier = "REMINDER_ACTIONS"

        var requests: [UNNotificationRequest] = []
        scheduleFromConfig(
            config: config,
            memoryID: memory.id,
            content: content,
            requests: &requests
        )

        do {
            try await center.add(requests: requests)
        } catch {
            print("Failed to schedule notifications: \(error.localizedDescription)")
        }
    }

    private func pendingIdentifiers() async -> [String] {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests.map(\.identifier))
            }
        }
    }

    private func notificationIdentifier(memoryID: UUID, configID: UUID) -> String {
        "memory-\(memoryID.uuidString)-schedule-\(configID.uuidString)"
    }

    private func scheduleFromConfig(
        config: ScheduleConfig,
        memoryID: UUID,
        content: UNMutableNotificationContent,
        requests: inout [UNNotificationRequest]
    ) {
        guard let fireDate = config.fireDate else { return }

        // If there's a weekdayMask, create notifications for each selected day
        if config.weekdayMask != 0 {
            for day in 1...7 {
                let bit = Int16(1 << day)
                guard config.weekdayMask & bit != 0 else { continue }
                let identifier = notificationIdentifier(memoryID: memoryID, configID: config.id) + "-\(day)"
                var components = DateComponents()
                components.weekday = day
                let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: fireDate)
                components.hour = timeComponents.hour
                components.minute = timeComponents.minute
                let request = UNNotificationRequest(
                    identifier: identifier,
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                )
                requests.append(request)
            }
        } else if config.recurrenceRule != nil {
            // If there's recurrence without weekdayMask, create recurring notification
            let identifier = notificationIdentifier(memoryID: memoryID, configID: config.id)
            let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            )
            requests.append(request)
        } else {
            // Simple case: just a date/time
            let identifier = notificationIdentifier(memoryID: memoryID, configID: config.id)
            let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            )
            requests.append(request)
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
