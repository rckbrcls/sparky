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

    /// Maximum number of future one-time occurrences to schedule
    /// when a recurrence interval > 1 is used.
    private let maxFutureOccurrences = 5

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

        let content = buildContent(for: memory)

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

    // MARK: - Notification Content

    private func buildContent(for memory: Memory) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = memory.title
        if let body = memory.body, !body.isEmpty {
            content.body = body
        }
        content.sound = settings.notificationSoundEnabled ? .default : nil
        content.categoryIdentifier = "REMINDER_ACTIONS"
        content.threadIdentifier = memory.id.uuidString
        content.userInfo = ["memoryID": memory.id.uuidString]
        return content
    }

    // MARK: - Scheduling Logic

    private func scheduleFromConfig(
        config: ScheduleConfig,
        memoryID: UUID,
        content: UNMutableNotificationContent,
        requests: inout [UNNotificationRequest]
    ) {
        guard let fireDate = config.fireDate else { return }

        if config.weekdayMask != 0 {
            scheduleWeekday(config: config, fireDate: fireDate, memoryID: memoryID, content: content, requests: &requests)
        } else if let recurrence = config.recurrenceRule {
            scheduleRecurring(config: config, recurrence: recurrence, fireDate: fireDate, memoryID: memoryID, content: content, requests: &requests)
        } else {
            scheduleOneTime(config: config, fireDate: fireDate, memoryID: memoryID, content: content, requests: &requests)
        }
    }

    /// Weekday-based recurring notifications (e.g. every Mon/Wed/Fri at 9:00).
    private func scheduleWeekday(
        config: ScheduleConfig,
        fireDate: Date,
        memoryID: UUID,
        content: UNMutableNotificationContent,
        requests: inout [UNNotificationRequest]
    ) {
        let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: fireDate)

        for day in 1...7 {
            let bit = Int16(1 << day)
            guard config.weekdayMask & bit != 0 else { continue }

            let identifier = notificationIdentifier(memoryID: memoryID, triggerID: config.id) + "-wd\(day)"
            var components = DateComponents()
            components.weekday = day
            components.hour = timeComponents.hour
            components.minute = timeComponents.minute

            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            )
            requests.append(request)
        }
    }

    /// Recurring notifications based on a `RecurrenceRule`.
    private func scheduleRecurring(
        config: ScheduleConfig,
        recurrence: RecurrenceRule,
        fireDate: Date,
        memoryID: UUID,
        content: UNMutableNotificationContent,
        requests: inout [UNNotificationRequest]
    ) {
        let baseIdentifier = notificationIdentifier(memoryID: memoryID, triggerID: config.id)
        let interval = recurrence.interval

        // Minutely / Hourly: use time-interval trigger (handles any interval natively).
        switch recurrence.frequency {
        case .minutely:
            let seconds = max(60, TimeInterval(interval * 60))
            let request = UNNotificationRequest(
                identifier: baseIdentifier,
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: true)
            )
            requests.append(request)
            return

        case .hourly:
            let seconds = TimeInterval(interval * 3600)
            let request = UNNotificationRequest(
                identifier: baseIdentifier,
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: true)
            )
            requests.append(request)
            return

        default:
            break
        }

        // When occurrence count is set, we must use individual one-time notifications
        // since iOS repeating triggers can't enforce a max count.
        if recurrence.occurrenceCount != nil {
            scheduleFutureOccurrences(
                config: config,
                recurrence: recurrence,
                baseIdentifier: baseIdentifier,
                content: content,
                requests: &requests
            )
        } else if interval == 1 {
            // Daily+ with interval == 1: use repeating calendar trigger with minimal components.
            let components = calendarComponents(for: recurrence.frequency, from: fireDate)
            let request = UNNotificationRequest(
                identifier: baseIdentifier,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            )
            requests.append(request)
        } else {
            // Interval > 1: schedule the next N occurrences as one-time notifications.
            // The app re-syncs on every launch and periodically, so new ones will be added.
            scheduleFutureOccurrences(
                config: config,
                recurrence: recurrence,
                baseIdentifier: baseIdentifier,
                content: content,
                requests: &requests
            )
        }
    }

    /// One-time (non-recurring) notification.
    private func scheduleOneTime(
        config: ScheduleConfig,
        fireDate: Date,
        memoryID: UUID,
        content: UNMutableNotificationContent,
        requests: inout [UNNotificationRequest]
    ) {
        guard fireDate > Date() else { return }

        let identifier = notificationIdentifier(memoryID: memoryID, triggerID: config.id)
        let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        )
        requests.append(request)
    }

    // MARK: - Helpers

    /// Returns the minimal `DateComponents` needed for a repeating calendar trigger
    /// to fire at the correct cadence for the given frequency.
    private func calendarComponents(for frequency: RecurrenceFrequency, from date: Date) -> DateComponents {
        let calendar = Calendar.current
        var components = DateComponents()
        let time = calendar.dateComponents([.hour, .minute], from: date)

        switch frequency {
        case .daily:
            components.hour = time.hour
            components.minute = time.minute

        case .weekly:
            components.weekday = calendar.component(.weekday, from: date)
            components.hour = time.hour
            components.minute = time.minute

        case .monthly:
            components.day = calendar.component(.day, from: date)
            components.hour = time.hour
            components.minute = time.minute

        case .yearly:
            components.month = calendar.component(.month, from: date)
            components.day = calendar.component(.day, from: date)
            components.hour = time.hour
            components.minute = time.minute

        case .minutely, .hourly:
            // Handled by UNTimeIntervalNotificationTrigger; should not reach here.
            components.hour = time.hour
            components.minute = time.minute
        }

        return components
    }

    /// Schedules up to `maxFutureOccurrences` one-time notifications for recurrences
    /// with interval > 1 (e.g. every 2 weeks, every 3 months).
    private func scheduleFutureOccurrences(
        config: ScheduleConfig,
        recurrence: RecurrenceRule,
        baseIdentifier: String,
        content: UNMutableNotificationContent,
        requests: inout [UNNotificationRequest]
    ) {
        let now = Date()
        var reference = now

        let effectiveEnd: Date? = {
            if let fireDate = config.fireDate {
                return config.effectiveEndDate(fireDate: fireDate, recurrence: recurrence)
            }
            return recurrence.endDate
        }()

        for index in 0..<maxFutureOccurrences {
            guard let nextDate = config.nextFireDate(after: reference) else { break }
            if let effectiveEnd, nextDate > effectiveEnd { break }

            let identifier = "\(baseIdentifier)-occ\(index)"
            let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: nextDate)
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            )
            requests.append(request)
            reference = nextDate.addingTimeInterval(1)
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
