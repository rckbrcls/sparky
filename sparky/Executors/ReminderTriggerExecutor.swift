//
//  ReminderTriggerExecutor.swift
//  sparky
//

import Foundation
import UserNotifications
import os

@MainActor
final class ReminderTriggerExecutor: TriggerExecutorProtocol {
    private static let logger = Logger(subsystem: "sparky", category: "ReminderTriggerExecutor")

    private let center = UNUserNotificationCenter.current()
    private var hasRequestedAuthorization = false
    private let settings: SettingsStore

    /// Limits how many one-time reminder notifications are staged in advance.
    /// iOS has a pending notification cap, so we keep a small rolling window.
    private let maxFutureOccurrences = 8

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

    func register(config: ReminderConfig, for memory: Memory) async {
        await requestAuthorizationIfNeeded()

        guard config.isActive,
              memory.status == .active,
              memory.hasPrimaryTrigger else {
            await unregister(triggerID: config.id, for: memory.id)
            return
        }

        await unregister(triggerID: config.id, for: memory.id)

        guard let startedAt = resolveStartDate(for: memory, config: config) else {
            return
        }

        let content = buildContent(for: memory)
        var requests: [UNNotificationRequest] = []

        scheduleRequests(
            config: config,
            memoryID: memory.id,
            startedAt: startedAt,
            content: content,
            requests: &requests
        )

        guard !requests.isEmpty else { return }

        do {
            try await center.add(requests: requests)
        } catch {
            Self.logger.error("Failed to schedule reminder notifications: \(error.localizedDescription)")
        }
    }

    func unregister(triggerID: UUID, for memoryID: UUID) async {
        let prefix = notificationIdentifier(memoryID: memoryID, triggerID: triggerID)
        let identifiers = await pendingIdentifiers().filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func unregisterAll(for memoryID: UUID) async {
        let prefix = "memory-\(memoryID.uuidString)-reminder-"
        let identifiers = await pendingIdentifiers().filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func sync(memories: [Memory]) async {
        await requestAuthorizationIfNeeded()

        let reminderPendingIDs = await pendingIdentifiers().filter { $0.contains("-reminder-") }
        center.removePendingNotificationRequests(withIdentifiers: reminderPendingIDs)

        for memory in memories {
            guard memory.status == .active,
                  let config = memory.reminderConfig,
                  config.isActive else {
                continue
            }
            await register(config: config, for: memory)
        }
    }

    private func resolveStartDate(for memory: Memory, config: ReminderConfig) -> Date? {
        if let startedAt = config.startedAt {
            return startedAt
        }

        guard let schedule = memory.scheduleConfig,
              schedule.isActive,
              let fireDate = schedule.fireDate else {
            return nil
        }

        config.startedAt = fireDate
        config.startedBy = .schedule
        return fireDate
    }

    private func buildContent(for memory: Memory) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = memory.title
        if let body = memory.body, !body.isEmpty {
            content.body = body
        } else {
            content.body = "This memory is still pending."
        }
        content.sound = settings.notificationSoundEnabled ? .default : nil
        content.categoryIdentifier = "REMINDER_ACTIONS"
        content.threadIdentifier = memory.id.uuidString
        content.userInfo = ["memoryID": memory.id.uuidString]
        return content
    }

    private func scheduleRequests(
        config: ReminderConfig,
        memoryID: UUID,
        startedAt: Date,
        content: UNMutableNotificationContent,
        requests: inout [UNNotificationRequest]
    ) {
        let interval = config.secondsInterval
        guard interval > 0 else { return }

        let now = Date()
        let elapsed = max(0, now.timeIntervalSince(startedAt))
        var nextOccurrenceIndex = max(1, Int(floor(elapsed / interval)) + 1)

        if let repeatCount = config.repeatCount, repeatCount <= 0 {
            return
        }

        let maxIndex = config.repeatCount
        let baseIdentifier = notificationIdentifier(memoryID: memoryID, triggerID: config.id)

        var added = 0
        while added < maxFutureOccurrences {
            if let maxIndex, nextOccurrenceIndex > maxIndex { break }

            let fireDate = startedAt.addingTimeInterval(TimeInterval(nextOccurrenceIndex) * interval)
            if fireDate <= now {
                nextOccurrenceIndex += 1
                continue
            }

            let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let request = UNNotificationRequest(
                identifier: "\(baseIdentifier)-occ\(nextOccurrenceIndex)",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            )
            requests.append(request)

            nextOccurrenceIndex += 1
            added += 1
        }
    }

    private func pendingIdentifiers() async -> [String] {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests.map(\.identifier))
            }
        }
    }

    private func notificationIdentifier(memoryID: UUID, triggerID: UUID) -> String {
        "memory-\(memoryID.uuidString)-reminder-\(triggerID.uuidString)"
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
