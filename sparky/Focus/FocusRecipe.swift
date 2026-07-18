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
    static func resolve(schedule: ScheduleConfig) -> FocusRecipe? {
        guard schedule.focusEnabled,
              schedule.focusWorkDurationMinutes > 0,
              schedule.focusShortBreakDurationMinutes > 0,
              schedule.focusLongBreakDurationMinutes > 0,
              schedule.focusPomodorosUntilLongBreak > 0 else {
            return nil
        }
        return FocusRecipe(
            workDurationMinutes: schedule.focusWorkDurationMinutes,
            shortBreakDurationMinutes: schedule.focusShortBreakDurationMinutes,
            longBreakDurationMinutes: schedule.focusLongBreakDurationMinutes,
            pomodorosUntilLongBreak: schedule.focusPomodorosUntilLongBreak,
            autoContinue: schedule.focusAutoContinue
        )
    }

    /// Returns nil when Focus is not enabled on the draft.
    static func resolve(draft: ScheduleConfigDraft) -> FocusRecipe? {
        guard draft.focusEnabled, draft.hasConcreteFocusRecipe else { return nil }
        return FocusRecipe(
            workDurationMinutes: draft.focusWorkDurationMinutes,
            shortBreakDurationMinutes: draft.focusShortBreakDurationMinutes,
            longBreakDurationMinutes: draft.focusLongBreakDurationMinutes,
            pomodorosUntilLongBreak: draft.focusPomodorosUntilLongBreak,
            autoContinue: draft.focusAutoContinue
        )
    }

    private static func clamp(_ value: Int, to range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
