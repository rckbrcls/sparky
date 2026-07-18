//
//  FocusRecipeTests.swift
//  sparkyTests
//

import Foundation
import Testing
@testable import sparky

@MainActor
struct FocusRecipeTests {

    @Test func fromSettingsCopiesGlobals() {
        let settings = FocusSettings(defaults: UserDefaults(suiteName: "FocusRecipeTests.fromSettings")!)
        settings.resetToDefaults()
        settings.workDurationMinutes = 30
        settings.shortBreakDurationMinutes = 7
        settings.longBreakDurationMinutes = 20
        settings.pomodorosUntilLongBreak = 3
        settings.autoContinue = false

        let recipe = FocusRecipe.from(settings: settings)
        #expect(recipe.workDurationMinutes == 30)
        #expect(recipe.shortBreakDurationMinutes == 7)
        #expect(recipe.longBreakDurationMinutes == 20)
        #expect(recipe.pomodorosUntilLongBreak == 3)
        #expect(recipe.autoContinue == false)
        #expect(recipe.workDurationSeconds == 1800)
    }

    @Test func resolveLegacyUsesGlobals() {
        let settings = FocusSettings(defaults: UserDefaults(suiteName: "FocusRecipeTests.legacy")!)
        settings.resetToDefaults()
        settings.workDurationMinutes = 40
        settings.autoContinue = false

        let schedule = ScheduleConfig(focusEnabled: true)
        let recipe = FocusRecipe.resolve(schedule: schedule, settings: settings)
        #expect(recipe != nil)
        #expect(recipe?.workDurationMinutes == 40)
        #expect(recipe?.autoContinue == false)
    }

    @Test func resolveCustomUsesStored() {
        let settings = FocusSettings(defaults: UserDefaults(suiteName: "FocusRecipeTests.custom")!)
        settings.resetToDefaults()
        settings.workDurationMinutes = 25

        let schedule = ScheduleConfig(
            focusEnabled: true,
            focusWorkDurationMinutes: 15,
            focusShortBreakDurationMinutes: 3,
            focusLongBreakDurationMinutes: 10,
            focusPomodorosUntilLongBreak: 2,
            focusAutoContinue: false
        )
        let recipe = FocusRecipe.resolve(schedule: schedule, settings: settings)
        #expect(recipe?.workDurationMinutes == 15)
        #expect(recipe?.shortBreakDurationMinutes == 3)
        #expect(recipe?.longBreakDurationMinutes == 10)
        #expect(recipe?.pomodorosUntilLongBreak == 2)
        #expect(recipe?.autoContinue == false)
    }

    @Test func resolveDisabledReturnsNil() {
        let settings = FocusSettings(defaults: UserDefaults(suiteName: "FocusRecipeTests.disabled")!)
        let schedule = ScheduleConfig(focusEnabled: false, focusWorkDurationMinutes: 15)
        #expect(FocusRecipe.resolve(schedule: schedule, settings: settings) == nil)
    }

    @Test func clampsOutOfRangeValues() {
        let recipe = FocusRecipe(
            workDurationMinutes: 999,
            shortBreakDurationMinutes: 0,
            longBreakDurationMinutes: -5,
            pomodorosUntilLongBreak: 100,
            autoContinue: true
        )
        #expect(recipe.workDurationMinutes == 60)
        #expect(recipe.shortBreakDurationMinutes == 1)
        #expect(recipe.longBreakDurationMinutes == 1)
        #expect(recipe.pomodorosUntilLongBreak == 12)
    }
}
