//
//  SettingsStore.swift
//  i-cant-miss
//
//  Created by Codex on 15/10/25.
//

import Foundation
import Combine

@MainActor
final class SettingsStore: ObservableObject {
    private enum Keys {
        static let timelineFilter = "settings.defaultTimelineFilter"
        static let snoozeMinutes = "settings.defaultSnoozeMinutes"
        static let postponeMinutes = "settings.defaultPostponeMinutes"
        static let notificationSound = "settings.notificationSoundEnabled"
        static let locationAlways = "settings.locationAuthorizationAlways"
        static let onboardingCompleted = "settings.onboardingCompleted"
        static let userDisplayName = "settings.userDisplayName"
    }

    private let defaults: UserDefaults

    @Published var defaultTimelineFilter: MemoryTimelineFilter {
        didSet {
            defaults.set(defaultTimelineFilter.storageKey, forKey: Keys.timelineFilter)
        }
    }

    @Published var defaultSnoozeMinutes: Int {
        didSet {
            let clamped = SettingsStore.clamp(minutes: defaultSnoozeMinutes, fallback: 15)
            if clamped != defaultSnoozeMinutes {
                defaultSnoozeMinutes = clamped
                return
            }
            defaults.set(clamped, forKey: Keys.snoozeMinutes)
        }
    }

    @Published var defaultPostponeMinutes: Int {
        didSet {
            let clamped = SettingsStore.clamp(minutes: defaultPostponeMinutes, fallback: 60)
            if clamped != defaultPostponeMinutes {
                defaultPostponeMinutes = clamped
                return
            }
            defaults.set(clamped, forKey: Keys.postponeMinutes)
        }
    }

    @Published var notificationSoundEnabled: Bool {
        didSet {
            defaults.set(notificationSoundEnabled, forKey: Keys.notificationSound)
        }
    }

    @Published var userDisplayName: String {
        didSet {
            defaults.set(userDisplayName, forKey: Keys.userDisplayName)
        }
    }

    @Published var preferAlwaysOnLocationAccess: Bool {
        didSet {
            defaults.set(preferAlwaysOnLocationAccess, forKey: Keys.locationAlways)
        }
    }

    @Published var hasCompletedOnboarding: Bool {
        didSet {
            defaults.set(hasCompletedOnboarding, forKey: Keys.onboardingCompleted)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let storedFilter = defaults.string(forKey: Keys.timelineFilter) ?? MemoryTimelineFilter.today.storageKey
        let filter = MemoryTimelineFilter(storageKey: storedFilter) ?? .today
        self.defaultTimelineFilter = filter

        let snoozeMinutes = defaults.object(forKey: Keys.snoozeMinutes) as? Int ?? 15
        self.defaultSnoozeMinutes = SettingsStore.clamp(minutes: snoozeMinutes, fallback: 15)

        let postponeMinutes = defaults.object(forKey: Keys.postponeMinutes) as? Int ?? 60
        self.defaultPostponeMinutes = SettingsStore.clamp(minutes: postponeMinutes, fallback: 60)

        if defaults.object(forKey: Keys.notificationSound) == nil {
            defaults.set(true, forKey: Keys.notificationSound)
        }
        self.notificationSoundEnabled = defaults.bool(forKey: Keys.notificationSound)

        if defaults.object(forKey: Keys.locationAlways) == nil {
            defaults.set(false, forKey: Keys.locationAlways)
        }
        self.preferAlwaysOnLocationAccess = defaults.bool(forKey: Keys.locationAlways)

        self.hasCompletedOnboarding = defaults.bool(forKey: Keys.onboardingCompleted)

        self.userDisplayName = defaults.string(forKey: Keys.userDisplayName) ?? ""
    }

    private static func clamp(minutes: Int, fallback: Int) -> Int {
        let sanitized = max(1, min(minutes, 24 * 60))
        return minutes <= 0 ? fallback : sanitized
    }
}
