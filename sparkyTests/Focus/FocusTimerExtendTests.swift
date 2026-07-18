//
//  FocusTimerExtendTests.swift
//  sparkyTests
//

import Foundation
import Testing
@testable import sparky

@MainActor
struct FocusTimerExtendTests {

    private func makeTimer(suite: String, autoContinue: Bool = true) -> FocusTimer {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let settings = FocusSettings(defaults: defaults)
        settings.workDurationMinutes = 25
        settings.shortBreakDurationMinutes = 5
        settings.longBreakDurationMinutes = 15
        settings.pomodorosUntilLongBreak = 2
        settings.autoContinue = autoContinue
        return FocusTimer(settings: settings, notifications: FocusNotificationService(settings: SettingsStore()))
    }

    @Test func extendWhileRunningAddsSixtySeconds() {
        let timer = makeTimer(suite: "FocusExtend.running")
        timer.beginQuickSession(workDurationMinutes: 10)
        let beforeRemaining = timer.remainingSeconds
        let beforeEnd = timer.phaseEndsAt
        #expect(timer.canExtendPhase)

        timer.extendCurrentPhase(byMinutes: 1)

        #expect(timer.remainingSeconds == beforeRemaining + 60)
        if let beforeEnd, let afterEnd = timer.phaseEndsAt {
            #expect(afterEnd.timeIntervalSince(beforeEnd) == 60)
        } else {
            Issue.record("Expected phaseEndsAt before and after extend")
        }
        // Progress should not jump above 1
        #expect(timer.progress >= 0 && timer.progress <= 1)
        timer.endSession()
    }

    @Test func extendWhilePausedAddsRemainingOnly() {
        let timer = makeTimer(suite: "FocusExtend.paused")
        timer.beginQuickSession(workDurationMinutes: 10)
        timer.pause()
        let before = timer.remainingSeconds
        #expect(timer.phaseEndsAt == nil)
        #expect(timer.canExtendPhase)

        timer.extendCurrentPhase(byMinutes: 1)

        #expect(timer.remainingSeconds == before + 60)
        #expect(timer.phaseEndsAt == nil)
        timer.endSession()
    }

    @Test func extendWhileIdleIsNoOp() {
        let timer = makeTimer(suite: "FocusExtend.idle")
        #expect(!timer.canExtendPhase)
        let before = timer.remainingSeconds
        timer.extendCurrentPhase(byMinutes: 1)
        #expect(timer.remainingSeconds == before)
    }

    @Test func extendWhileWaitingForManualStartIsNoOp() {
        let timer = makeTimer(suite: "FocusExtend.waiting", autoContinue: false)
        let recipe = FocusRecipe(
            workDurationMinutes: 1,
            shortBreakDurationMinutes: 1,
            longBreakDurationMinutes: 1,
            pomodorosUntilLongBreak: 2,
            autoContinue: false
        )
        timer.beginSession(memoryID: UUID(), memoryTitle: "Wait", recipe: recipe)
        timer.completePhaseNow()
        #expect(timer.isWaitingForManualStart)
        #expect(!timer.canExtendPhase)

        let before = timer.remainingSeconds
        timer.extendCurrentPhase(byMinutes: 1)
        #expect(timer.remainingSeconds == before)
        timer.endSession()
    }

    @Test func phaseWindowSetOnConfigure() {
        let timer = makeTimer(suite: "FocusExtend.window")
        timer.beginQuickSession(workDurationMinutes: 5)
        #expect(timer.phaseStartedAt != nil)
        #expect(timer.displayStartDate != nil)
        #expect(timer.displayEndDate != nil)
        timer.endSession()
        #expect(timer.phaseStartedAt == nil)
    }
}
