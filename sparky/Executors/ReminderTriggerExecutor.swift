//
//  ReminderTriggerExecutor.swift
//  sparky
//

import Foundation
import UserNotifications
import os

enum ReminderOwnerKind: String {
    case schedule
    case location
}

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

    func unregister(triggerID: UUID, for memoryID: UUID) async {
        let identifiers = await pendingIdentifiers().filter {
            $0.contains(memoryID.uuidString) && $0.contains(triggerID.uuidString) && $0.contains("-reminder-")
        }
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
            guard memory.status == .active else { continue }
            await registerNestedReminders(for: memory)
        }
    }

    private func registerNestedReminders(for memory: Memory) async {
        if let schedule = memory.scheduleConfig, schedule.hasActiveReminder {
            await register(
                owner: .schedule,
                configID: schedule.id,
                policy: schedule.reminder,
                memory: memory,
                resolveStart: {
                    if let startedAt = schedule.reminderStartedAt {
                        return startedAt
                    }
                    guard let fireDate = schedule.fireDate else { return nil }
                    schedule.reminderStartedAt = fireDate
                    return fireDate
                }
            )
        }

        if let location = memory.locationConfig, location.hasActiveReminder {
            await register(
                owner: .location,
                configID: location.id,
                policy: location.reminder,
                memory: memory,
                resolveStart: {
                    // Location follow-ups only start after the geofence actually fires.
                    location.reminderStartedAt
                }
            )
        }
    }

    private func register(
        owner: ReminderOwnerKind,
        configID: UUID,
        policy: NestedReminderPolicy,
        memory: Memory,
        resolveStart: () -> Date?
    ) async {
        await requestAuthorizationIfNeeded()
        await unregister(triggerID: configID, for: memory.id)

        guard policy.isActive, memory.status == .active else { return }
        guard let startedAt = resolveStart() else { return }

        let content = buildContent(for: memory)
        var requests: [UNNotificationRequest] = []

        scheduleRequests(
            owner: owner,
            configID: configID,
            policy: policy,
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

    private func buildContent(for memory: Memory) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = memory.title
        if let body = memory.body, !body.isEmpty {
            content.body = body
        } else {
            content.body = "This memory is still pending."
        }
        content.sound = settings.notificationSoundEnabled ? .default : nil
        content.categoryIdentifier = NotificationCategoryID.reminderActions
        content.threadIdentifier = memory.id.uuidString
        content.userInfo = ["memoryID": memory.id.uuidString]
        return content
    }

    private func scheduleRequests(
        owner: ReminderOwnerKind,
        configID: UUID,
        policy: NestedReminderPolicy,
        memoryID: UUID,
        startedAt: Date,
        content: UNMutableNotificationContent,
        requests: inout [UNNotificationRequest]
    ) {
        let interval = policy.secondsInterval
        guard interval > 0 else { return }

        let now = Date()
        let elapsed = max(0, now.timeIntervalSince(startedAt))
        var nextOccurrenceIndex = max(1, Int(floor(elapsed / interval)) + 1)

        if let repeatCount = policy.repeatCount, repeatCount <= 0 {
            return
        }

        let maxIndex = policy.repeatCount
        let baseIdentifier = notificationIdentifier(memoryID: memoryID, owner: owner, configID: configID)

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

    private func notificationIdentifier(memoryID: UUID, owner: ReminderOwnerKind, configID: UUID) -> String {
        "memory-\(memoryID.uuidString)-reminder-\(owner.rawValue)-\(configID.uuidString)"
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
