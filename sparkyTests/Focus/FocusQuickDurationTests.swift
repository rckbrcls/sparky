//
//  FocusQuickDurationTests.swift
//  sparkyTests
//

import Foundation
import Testing
@testable import sparky

@MainActor
struct FocusQuickDurationTests {

    private func makeTimer(suite: String) -> FocusTimer {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let settings = FocusSettings(defaults: defaults)
        settings.workDurationMinutes = 25
        settings.shortBreakDurationMinutes = 5
        settings.longBreakDurationMinutes = 15
        settings.pomodorosUntilLongBreak = 4
        settings.autoContinue = true
        return FocusTimer(settings: settings, notifications: FocusNotificationService(settings: SettingsStore()))
    }

    @Test func beginQuickSessionNilUsesGlobalWork() {
        let timer = makeTimer(suite: "FocusQuickDuration.nil")
        timer.beginQuickSession(workDurationMinutes: nil)
        #expect(timer.remainingSeconds == 25 * 60)
        #expect(timer.activeRecipe?.workDurationMinutes == 25)
        #expect(timer.activeRecipe?.shortBreakDurationMinutes == 5)
        timer.endSession()
    }

    @Test func beginQuickSessionOverrideFifteenMinutes() {
        let timer = makeTimer(suite: "FocusQuickDuration.15")
        timer.beginQuickSession(workDurationMinutes: 15)
        #expect(timer.isSessionActive)
        #expect(timer.phase == .work)
        #expect(timer.remainingSeconds == 15 * 60)
        #expect(timer.activeRecipe?.workDurationMinutes == 15)
        #expect(timer.activeRecipe?.shortBreakDurationMinutes == 5)
        #expect(timer.activeMemoryID == nil)
        timer.endSession()
    }

    @Test func beginQuickSessionUsesCompleteLocalRecipeSnapshot() {
        let timer = makeTimer(suite: "FocusQuickDuration.recipe")
        let recipe = FocusRecipe(
            workDurationMinutes: 30,
            shortBreakDurationMinutes: 10,
            longBreakDurationMinutes: 45,
            pomodorosUntilLongBreak: 6,
            autoContinue: false
        )

        timer.beginQuickSession(recipe: recipe)
        timer.settings.shortBreakDurationMinutes = 5
        timer.settings.longBreakDurationMinutes = 15
        timer.settings.pomodorosUntilLongBreak = 4
        timer.settings.autoContinue = true

        #expect(timer.activeRecipe == recipe)
        #expect(timer.remainingSeconds == 30 * 60)
        #expect(timer.activeRecipe?.shortBreakDurationMinutes == 10)
        #expect(timer.activeRecipe?.longBreakDurationMinutes == 45)
        #expect(timer.activeRecipe?.pomodorosUntilLongBreak == 6)
        #expect(timer.activeRecipe?.autoContinue == false)
        timer.endSession()
    }

    @Test func beginQuickSessionClampsZeroToOne() {
        let timer = makeTimer(suite: "FocusQuickDuration.clampLow")
        timer.beginQuickSession(workDurationMinutes: 0)
        #expect(timer.remainingSeconds == 1 * 60)
        #expect(timer.activeRecipe?.workDurationMinutes == 1)
        timer.endSession()
    }

    @Test func beginQuickSessionClampsHighTo60() {
        let timer = makeTimer(suite: "FocusQuickDuration.clampHigh")
        timer.beginQuickSession(workDurationMinutes: 999)
        #expect(timer.remainingSeconds == 60 * 60)
        #expect(timer.activeRecipe?.workDurationMinutes == 60)
        timer.endSession()
    }

    @Test func globalWorkDefaultClampsHighTo60() {
        let timer = makeTimer(suite: "FocusQuickDuration.settingsClampHigh")
        timer.settings.workDurationMinutes = 999

        #expect(timer.settings.workDurationMinutes == 60)
    }
}
