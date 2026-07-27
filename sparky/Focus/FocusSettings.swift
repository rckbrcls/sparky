//
//  FocusSettings.swift
//  sparky
//
//  Global pomodoro defaults for Focus sessions.
//

import Foundation
import Combine

@MainActor
final class FocusSettings: ObservableObject {
    private enum Keys {
        static let workDurationMinutes = "focus.workDurationMinutes"
        static let shortBreakDurationMinutes = "focus.shortBreakDurationMinutes"
        static let longBreakDurationMinutes = "focus.longBreakDurationMinutes"
        static let pomodorosUntilLongBreak = "focus.pomodorosUntilLongBreak"
        static let autoContinue = "focus.autoContinue"
        static let notificationsEnabled = "focus.notificationsEnabled"
        static let soundsEnabled = "focus.soundsEnabled"
        static let focusCompletionSound = "focus.focusCompletionSound"
        static let breakCompletionSound = "focus.breakCompletionSound"
    }

    private static let defaultWorkDurationMinutes = 25
    private static let defaultShortBreakDurationMinutes = 5
    private static let defaultLongBreakDurationMinutes = 15
    private static let defaultPomodorosUntilLongBreak = 4
    private static let defaultAutoContinue = true
    private static let defaultNotificationsEnabled = true
    private static let defaultSoundsEnabled = true
    private static let defaultFocusCompletionSound = FocusSoundChoice.glass
    private static let defaultBreakCompletionSound = FocusSoundChoice.bell

    private let defaults: UserDefaults

    @Published var workDurationMinutes: Int {
        didSet {
            let clampedValue = min(
                max(workDurationMinutes, FocusRecipe.workRange.lowerBound),
                FocusRecipe.workRange.upperBound
            )
            guard clampedValue == workDurationMinutes else {
                workDurationMinutes = clampedValue
                return
            }
            defaults.set(workDurationMinutes, forKey: Keys.workDurationMinutes)
        }
    }

    @Published var shortBreakDurationMinutes: Int {
        didSet { defaults.set(shortBreakDurationMinutes, forKey: Keys.shortBreakDurationMinutes) }
    }

    @Published var longBreakDurationMinutes: Int {
        didSet { defaults.set(longBreakDurationMinutes, forKey: Keys.longBreakDurationMinutes) }
    }

    @Published var pomodorosUntilLongBreak: Int {
        didSet { defaults.set(pomodorosUntilLongBreak, forKey: Keys.pomodorosUntilLongBreak) }
    }

    @Published var autoContinue: Bool {
        didSet { defaults.set(autoContinue, forKey: Keys.autoContinue) }
    }

    @Published var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: Keys.notificationsEnabled) }
    }

    @Published var soundsEnabled: Bool {
        didSet { defaults.set(soundsEnabled, forKey: Keys.soundsEnabled) }
    }

    @Published var focusCompletionSound: FocusSoundChoice {
        didSet {
            defaults.set(
                focusCompletionSound.rawValue,
                forKey: Keys.focusCompletionSound
            )
        }
    }

    @Published var breakCompletionSound: FocusSoundChoice {
        didSet {
            defaults.set(
                breakCompletionSound.rawValue,
                forKey: Keys.breakCompletionSound
            )
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let work = defaults.integer(forKey: Keys.workDurationMinutes)
        let resolvedWork = work == 0 ? Self.defaultWorkDurationMinutes : work
        workDurationMinutes = min(
            max(resolvedWork, FocusRecipe.workRange.lowerBound),
            FocusRecipe.workRange.upperBound
        )

        let shortBreak = defaults.integer(forKey: Keys.shortBreakDurationMinutes)
        shortBreakDurationMinutes = shortBreak == 0 ? Self.defaultShortBreakDurationMinutes : shortBreak

        let longBreak = defaults.integer(forKey: Keys.longBreakDurationMinutes)
        longBreakDurationMinutes = longBreak == 0 ? Self.defaultLongBreakDurationMinutes : longBreak

        let untilLong = defaults.integer(forKey: Keys.pomodorosUntilLongBreak)
        pomodorosUntilLongBreak = untilLong == 0 ? Self.defaultPomodorosUntilLongBreak : untilLong

        if defaults.object(forKey: Keys.autoContinue) != nil {
            autoContinue = defaults.bool(forKey: Keys.autoContinue)
        } else {
            autoContinue = Self.defaultAutoContinue
        }

        if defaults.object(forKey: Keys.notificationsEnabled) != nil {
            notificationsEnabled = defaults.bool(forKey: Keys.notificationsEnabled)
        } else {
            notificationsEnabled = Self.defaultNotificationsEnabled
        }

        if defaults.object(forKey: Keys.soundsEnabled) != nil {
            soundsEnabled = defaults.bool(forKey: Keys.soundsEnabled)
        } else {
            soundsEnabled = Self.defaultSoundsEnabled
        }

        focusCompletionSound = FocusSoundChoice(
            rawValue: defaults.string(forKey: Keys.focusCompletionSound) ?? ""
        ) ?? Self.defaultFocusCompletionSound
        breakCompletionSound = FocusSoundChoice(
            rawValue: defaults.string(forKey: Keys.breakCompletionSound) ?? ""
        ) ?? Self.defaultBreakCompletionSound
    }

    var workDurationSeconds: Int { workDurationMinutes * 60 }
    var shortBreakDurationSeconds: Int { shortBreakDurationMinutes * 60 }
    var longBreakDurationSeconds: Int { longBreakDurationMinutes * 60 }

    func resetToDefaults() {
        workDurationMinutes = Self.defaultWorkDurationMinutes
        shortBreakDurationMinutes = Self.defaultShortBreakDurationMinutes
        longBreakDurationMinutes = Self.defaultLongBreakDurationMinutes
        pomodorosUntilLongBreak = Self.defaultPomodorosUntilLongBreak
        autoContinue = Self.defaultAutoContinue
        notificationsEnabled = Self.defaultNotificationsEnabled
        soundsEnabled = Self.defaultSoundsEnabled
        focusCompletionSound = Self.defaultFocusCompletionSound
        breakCompletionSound = Self.defaultBreakCompletionSound
    }
}
