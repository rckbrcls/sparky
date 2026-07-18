//
//  FocusTimerTests.swift
//  sparkyTests
//

import Foundation
import Testing
@testable import sparky

@MainActor
struct FocusTimerTests {

    private func makeTimer(suite: String, autoContinue: Bool = true) -> FocusTimer {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let settings = FocusSettings(defaults: defaults)
        settings.workDurationMinutes = 25
        settings.shortBreakDurationMinutes = 5
        settings.longBreakDurationMinutes = 15
        settings.pomodorosUntilLongBreak = 4
        settings.autoContinue = autoContinue
        return FocusTimer(settings: settings, notifications: FocusNotificationService(settings: SettingsStore()))
    }

    @Test func beginQuickSessionUsesGlobalWorkDuration() {
        let timer = makeTimer(suite: "FocusTimerTests.quick")
        timer.beginQuickSession()
        #expect(timer.isSessionActive)
        #expect(timer.activeMemoryID == nil)
        #expect(timer.phase == .work)
        #expect(timer.remainingSeconds == 25 * 60)
        #expect(timer.isRunning)
        timer.endSession()
    }

    @Test func beginSessionUsesRecipeWorkDuration() {
        let timer = makeTimer(suite: "FocusTimerTests.recipe")
        let recipe = FocusRecipe(
            workDurationMinutes: 12,
            shortBreakDurationMinutes: 3,
            longBreakDurationMinutes: 9,
            pomodorosUntilLongBreak: 2,
            autoContinue: true
        )
        let id = UUID()
        timer.beginSession(memoryID: id, memoryTitle: "Deep work", recipe: recipe)
        #expect(timer.activeMemoryID == id)
        #expect(timer.activeMemoryTitle == "Deep work")
        #expect(timer.remainingSeconds == 12 * 60)
        #expect(timer.activeRecipe == recipe)
        timer.endSession()
    }

    @Test func sameMemoryBeginIsNoOpWhileActive() {
        let timer = makeTimer(suite: "FocusTimerTests.same")
        let id = UUID()
        let recipe = FocusRecipe.from(settings: timer.settings)
        timer.beginSession(memoryID: id, memoryTitle: "A", recipe: recipe)
        timer.pause()
        let remaining = timer.remainingSeconds
        timer.beginSession(memoryID: id, memoryTitle: "A", recipe: recipe)
        #expect(timer.remainingSeconds == remaining)
        timer.endSession()
    }

    @Test func autoContinueOffWaitsForManualStart() {
        let timer = makeTimer(suite: "FocusTimerTests.manual")
        let recipe = FocusRecipe(
            workDurationMinutes: 1,
            shortBreakDurationMinutes: 1,
            longBreakDurationMinutes: 1,
            pomodorosUntilLongBreak: 2,
            autoContinue: false
        )
        timer.beginSession(memoryID: UUID(), memoryTitle: "Manual", recipe: recipe)
        timer.completePhaseNow()
        #expect(timer.phase == .break)
        #expect(timer.isWaitingForManualStart)
        #expect(!timer.isRunning)
        #expect(timer.completedPomodoros == 1)
        timer.endSession()
    }
}
