//
//  FocusSessionReplaceTests.swift
//  sparkyTests
//

import Foundation
import Testing
@testable import sparky

@MainActor
struct FocusSessionReplaceTests {

    private func makeTimer(suite: String) -> FocusTimer {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let settings = FocusSettings(defaults: defaults)
        settings.resetToDefaults()
        return FocusTimer(settings: settings, notifications: FocusNotificationService(settings: SettingsStore()))
    }

    @Test func wouldReplaceQuickVsMemory() {
        let timer = makeTimer(suite: "FocusReplace.quickMemory")
        timer.beginQuickSession()
        #expect(timer.wouldReplaceSession(withMemoryID: UUID()))
        #expect(!timer.wouldReplaceSession(withMemoryID: nil))
        timer.endSession()
    }

    @Test func wouldReplaceDifferentMemories() {
        let timer = makeTimer(suite: "FocusReplace.diff")
        let a = UUID()
        let b = UUID()
        let recipe = FocusRecipe.from(settings: timer.settings)
        timer.beginSession(memoryID: a, memoryTitle: "A", recipe: recipe)
        #expect(timer.wouldReplaceSession(withMemoryID: b))
        #expect(!timer.wouldReplaceSession(withMemoryID: a))
        timer.endSession()
    }

    @Test func wouldNotReplaceWhenIdle() {
        let timer = makeTimer(suite: "FocusReplace.idle")
        #expect(!timer.wouldReplaceSession(withMemoryID: nil))
        #expect(!timer.wouldReplaceSession(withMemoryID: UUID()))
    }
}
