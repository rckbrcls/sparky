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
        static let notificationSoundEnabled = "settings.notificationSoundEnabled"
        static let notificationSoundName = "settings.notificationSoundName"
        static let onboardingCompleted = "settings.onboardingCompleted"
        static let userDisplayName = "settings.userDisplayName"
    }

    private let defaults: UserDefaults

    @Published var defaultTimelineFilter: MemoryTimelineFilter {
        didSet {
            defaults.set(defaultTimelineFilter.storageKey, forKey: Keys.timelineFilter)
        }
    }

    @Published var notificationSound: MemoryNotificationSound {
        didSet {
            defaults.set(notificationSound.rawValue, forKey: Keys.notificationSoundName)
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

        let sound = Self.resolvedNotificationSound(in: defaults)
        self.notificationSound = sound
        defaults.set(sound.rawValue, forKey: Keys.notificationSoundName)

        self.hasCompletedOnboarding = defaults.bool(forKey: Keys.onboardingCompleted)

        self.userDisplayName = defaults.string(forKey: Keys.userDisplayName) ?? ""
    }

    private static func resolvedNotificationSound(in defaults: UserDefaults) -> MemoryNotificationSound {
        if let stored = defaults.string(forKey: Keys.notificationSoundName),
           let choice = MemoryNotificationSound(rawValue: stored) {
            return choice
        }

        if defaults.object(forKey: Keys.notificationSoundEnabled) != nil,
           defaults.bool(forKey: Keys.notificationSoundEnabled) == false {
            return .none
        }

        return .systemDefault
    }
}
