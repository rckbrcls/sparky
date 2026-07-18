//
//  FocusPresetOptions.swift
//  sparky
//
//  Shared discrete choices for global, Quick Focus, and Memory recipes.
//

import Foundation

enum FocusPresetOptions {
    static let workMinutes = [5, 10, 15, 20, 25, 30, 45, 60]
    static let shortBreakMinutes = [5, 10, 15]
    static let longBreakMinutes = [15, 20, 30, 45]
    static let pomodorosUntilLongBreak = [2, 3, 4, 5, 6]

    static func choices(including currentValue: Int, presets: [Int]) -> [Int] {
        Array(Set(presets + [currentValue])).sorted()
    }

    static func durationLabel(_ minutes: Int) -> String {
        "\(minutes) min"
    }

    static func sessionLabel(_ count: Int) -> String {
        "\(count) \(count == 1 ? "session" : "sessions")"
    }
}
