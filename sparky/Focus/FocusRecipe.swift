//
//  FocusRecipe.swift
//  sparky
//
//  Resolved pomodoro parameters for Quick Focus and per-Memory Focus.
//

import Foundation

struct FocusRecipe: Equatable, Hashable, Sendable {
    var workDurationMinutes: Int
    var shortBreakDurationMinutes: Int
    var longBreakDurationMinutes: Int
    var pomodorosUntilLongBreak: Int
    var autoContinue: Bool

    static let workRange = 1...60
    static let breakRange = 1...60
    static let untilLongRange = 1...12

    init(
        workDurationMinutes: Int,
        shortBreakDurationMinutes: Int,
        longBreakDurationMinutes: Int,
        pomodorosUntilLongBreak: Int,
        autoContinue: Bool
    ) {
        self.workDurationMinutes = Self.clamp(workDurationMinutes, to: Self.workRange)
        self.shortBreakDurationMinutes = Self.clamp(shortBreakDurationMinutes, to: Self.breakRange)
        self.longBreakDurationMinutes = Self.clamp(longBreakDurationMinutes, to: Self.breakRange)
        self.pomodorosUntilLongBreak = Self.clamp(pomodorosUntilLongBreak, to: Self.untilLongRange)
        self.autoContinue = autoContinue
    }

    var workDurationSeconds: Int { workDurationMinutes * 60 }
    var shortBreakDurationSeconds: Int { shortBreakDurationMinutes * 60 }
    var longBreakDurationSeconds: Int { longBreakDurationMinutes * 60 }

    var summaryLabel: String {
        "\(workDurationMinutes)/\(shortBreakDurationMinutes)"
    }

    static func from(settings: FocusSettings) -> FocusRecipe {
        FocusRecipe(
            workDurationMinutes: settings.workDurationMinutes,
            shortBreakDurationMinutes: settings.shortBreakDurationMinutes,
            longBreakDurationMinutes: settings.longBreakDurationMinutes,
            pomodorosUntilLongBreak: settings.pomodorosUntilLongBreak,
            autoContinue: settings.autoContinue
        )
    }

    /// Returns nil when Focus is not enabled on the schedule.
    static func resolve(schedule: ScheduleConfig, settings: FocusSettings) -> FocusRecipe? {
        guard schedule.focusEnabled else { return nil }
        return resolveStored(
            work: schedule.focusWorkDurationMinutes,
            shortBreak: schedule.focusShortBreakDurationMinutes,
            longBreak: schedule.focusLongBreakDurationMinutes,
            untilLong: schedule.focusPomodorosUntilLongBreak,
            autoContinue: schedule.focusAutoContinue,
            settings: settings
        )
    }

    /// Returns nil when Focus is not enabled on the draft.
    static func resolve(draft: ScheduleConfigDraft, settings: FocusSettings) -> FocusRecipe? {
        guard draft.focusEnabled else { return nil }
        return resolveStored(
            work: draft.focusWorkDurationMinutes,
            shortBreak: draft.focusShortBreakDurationMinutes,
            longBreak: draft.focusLongBreakDurationMinutes,
            untilLong: draft.focusPomodorosUntilLongBreak,
            autoContinue: draft.focusAutoContinue,
            settings: settings
        )
    }

    /// Legacy rows store 0 durations; fill those from globals.
    private static func resolveStored(
        work: Int,
        shortBreak: Int,
        longBreak: Int,
        untilLong: Int,
        autoContinue: Bool,
        settings: FocusSettings
    ) -> FocusRecipe {
        let isLegacyUnset = work <= 0 || shortBreak <= 0 || longBreak <= 0 || untilLong <= 0
        return FocusRecipe(
            workDurationMinutes: work > 0 ? work : settings.workDurationMinutes,
            shortBreakDurationMinutes: shortBreak > 0 ? shortBreak : settings.shortBreakDurationMinutes,
            longBreakDurationMinutes: longBreak > 0 ? longBreak : settings.longBreakDurationMinutes,
            pomodorosUntilLongBreak: untilLong > 0 ? untilLong : settings.pomodorosUntilLongBreak,
            autoContinue: isLegacyUnset ? settings.autoContinue : autoContinue
        )
    }

    private static func clamp(_ value: Int, to range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
