//
//  NotificationScheduler.swift
//  i-cant-miss
//
//  Created by Codex on 13/10/25.
//

import Foundation
import UserNotifications

@MainActor
final class NotificationScheduler {
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

    func scheduleNotifications(for memory: MemoryModel) async {
        await requestAuthorizationIfNeeded()
        guard memory.status == .active else {
            await removeNotifications(for: memory.id)
            return
        }
        await removeNotifications(for: memory.id)

        let content = UNMutableNotificationContent()
        content.title = memory.title
        if let body = memory.body {
            content.body = body
        }
        content.sound = settings.notificationSoundEnabled ? .default : nil
        content.categoryIdentifier = "REMINDER_ACTIONS"

        var requests: [UNNotificationRequest] = []

        for trigger in memory.triggers {
            switch trigger.type {
            case .time:
                guard let fireDate = trigger.fireDate else { continue }
                let identifier = notificationIdentifier(memoryID: memory.id, triggerID: trigger.id)
                let triggerDate = UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate),
                                                                repeats: trigger.recurrenceRule != nil)
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: triggerDate)
                requests.append(request)
            case .dayOfWeek:
                let weekdayMask = trigger.weekdayMask
                for day in 1...7 {
                    let bit = Int16(1 << day)
                    guard weekdayMask & bit != 0 else { continue }
                    let identifier = notificationIdentifier(memoryID: memory.id, triggerID: trigger.id) + "-\(day)"
                    var components = DateComponents()
                    components.weekday = day
                    if let fireDate = trigger.fireDate {
                        let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: fireDate)
                        components.hour = timeComponents.hour
                        components.minute = timeComponents.minute
                    } else {
                        components.hour = 9
                        components.minute = 0
                    }
                    let request = UNNotificationRequest(identifier: identifier,
                                                        content: content,
                                                        trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true))
                    requests.append(request)
                }
            case .location, .person, .sequential:
                // Location, person, and sequential triggers rely on geofencing or manual events.
                continue
            }
        }

        do {
            try await center.add(requests: requests)
        } catch {
            print("Failed to schedule notifications: \(error.localizedDescription)")
        }
    }

    func removeNotifications(for memoryID: UUID) async {
        let identifiers = await pendingIdentifiers()
            .filter { $0.contains(memoryID.uuidString) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func refreshNotifications(memories: [MemoryModel]) async {
        await requestAuthorizationIfNeeded()
        let identifiers = await pendingIdentifiers()
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        for memory in memories {
            await scheduleNotifications(for: memory)
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
        "memory-\(memoryID.uuidString)-\(triggerID.uuidString)"
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
