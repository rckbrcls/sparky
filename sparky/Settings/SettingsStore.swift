//
//  SettingsStore.swift
//  sparky
//
//  Created by Codex on 15/10/25.
//

import Foundation
import Combine

@MainActor
final class SettingsStore: ObservableObject {
    private enum Keys {
        static let timelineFilter = "settings.defaultTimelineFilter"
        static let notificationSound = "settings.notificationSoundEnabled"
        static let onboardingCompleted = "settings.onboardingCompleted"
        static let userDisplayName = "settings.userDisplayName"
    }

    private let defaults: UserDefaults

    @Published var defaultTimelineFilter: MemoryTimelineFilter {
        didSet {
            defaults.set(defaultTimelineFilter.storageKey, forKey: Keys.timelineFilter)
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

        if defaults.object(forKey: Keys.notificationSound) == nil {
            defaults.set(true, forKey: Keys.notificationSound)
        }
        self.notificationSoundEnabled = defaults.bool(forKey: Keys.notificationSound)

        self.hasCompletedOnboarding = defaults.bool(forKey: Keys.onboardingCompleted)

        self.userDisplayName = defaults.string(forKey: Keys.userDisplayName) ?? ""
    }
}
