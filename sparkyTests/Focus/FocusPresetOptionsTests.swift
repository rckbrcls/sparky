//
//  FocusPresetOptionsTests.swift
//  sparkyTests
//

import Testing
@testable import sparky

@MainActor
struct FocusPresetOptionsTests {
    @Test func exposesApprovedPresetCatalog() {
        #expect(FocusPresetOptions.workMinutes == [5, 10, 15, 20, 25, 30, 45, 60])
        #expect(FocusPresetOptions.shortBreakMinutes == [5, 10, 15])
        #expect(FocusPresetOptions.longBreakMinutes == [15, 20, 30, 45])
        #expect(FocusPresetOptions.pomodorosUntilLongBreak == [2, 3, 4, 5, 6])
    }

    @Test func choicesPreserveAUniqueLegacyValue() {
        let choices = FocusPresetOptions.choices(
            including: 7,
            presets: FocusPresetOptions.shortBreakMinutes
        )

        #expect(choices == [5, 7, 10, 15])
    }

    @Test func choicesDoNotDuplicateAnExistingPreset() {
        let choices = FocusPresetOptions.choices(
            including: 25,
            presets: FocusPresetOptions.workMinutes
        )

        #expect(choices == FocusPresetOptions.workMinutes)
    }
}
