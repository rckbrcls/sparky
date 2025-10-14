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

    func scheduleNotifications(for reminder: ReminderModel) async {
        await requestAuthorizationIfNeeded()
        guard reminder.status == .active else {
            await removeNotifications(for: reminder.id)
            return
        }
        await removeNotifications(for: reminder.id)

        let content = UNMutableNotificationContent()
        content.title = reminder.title
        if let notes = reminder.notes {
            content.body = notes
        }
        content.sound = settings.notificationSoundEnabled ? .default : nil
        content.categoryIdentifier = "REMINDER_ACTIONS"

        var requests: [UNNotificationRequest] = []

        for trigger in reminder.triggers {
            switch trigger.type {
            case .time:
                guard let fireDate = trigger.fireDate else { continue }
                let identifier = notificationIdentifier(reminderID: reminder.id, triggerID: trigger.id)
                let triggerDate = UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate),
                                                                repeats: trigger.recurrenceRule != nil)
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: triggerDate)
                requests.append(request)
            case .importantDate:
                guard let fireDate = trigger.fireDate ?? reminder.importantDate?.date else { continue }
                let identifier = notificationIdentifier(reminderID: reminder.id, triggerID: trigger.id)
                let components = Calendar.current.dateComponents([.month, .day, .hour, .minute], from: fireDate)
                let request = UNNotificationRequest(identifier: identifier,
                                                    content: content,
                                                    trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true))
                requests.append(request)

                if let leadTimes = reminder.importantDate?.leadTimes {
                    for lead in leadTimes {
                        let date = fireDate.addingTimeInterval(-lead.offset)
                        guard date > Date() else { continue }
                        let leadIdentifier = identifier + "-lead-\(lead.id.uuidString)"
                        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
                        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                        let request = UNNotificationRequest(identifier: leadIdentifier, content: content, trigger: trigger)
                        requests.append(request)
                    }
                }
            case .dayOfWeek:
                let weekdayMask = trigger.weekdayMask
                for day in 1...7 {
                    let bit = Int16(1 << day)
                    guard weekdayMask & bit != 0 else { continue }
                    let identifier = notificationIdentifier(reminderID: reminder.id, triggerID: trigger.id) + "-\(day)"
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
            case .location, .person:
                // Location and person triggers rely on geofencing or manual events.
                continue
            }
        }

        do {
            try await center.add(requests: requests)
        } catch {
            print("Failed to schedule notifications: \(error.localizedDescription)")
        }
    }

    func removeNotifications(for reminderID: UUID) async {
        let identifiers = await pendingIdentifiers()
            .filter { $0.contains(reminderID.uuidString) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func refreshNotifications(reminders: [ReminderModel]) async {
        await requestAuthorizationIfNeeded()
        let identifiers = await pendingIdentifiers()
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        for reminder in reminders {
            await scheduleNotifications(for: reminder)
        }
    }

    private func pendingIdentifiers() async -> [String] {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests.map(\.identifier))
            }
        }
    }

    private func notificationIdentifier(reminderID: UUID, triggerID: UUID) -> String {
        "reminder-\(reminderID.uuidString)-\(triggerID.uuidString)"
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
