import Foundation
import Testing
@testable import sparky

@MainActor
struct FocusTimerFeedbackTests {
    @Test func startPauseResumeAndEndEmitOnlyEffectiveEvents() {
        let fixture = makeFixture(suite: "FocusTimerFeedback.commands")

        fixture.timer.beginQuickSession()
        fixture.timer.start()
        fixture.timer.pause()
        fixture.timer.pause()
        fixture.timer.start()
        fixture.timer.endSession()
        fixture.timer.endSession()

        #expect(
            fixture.feedback.events
                == [.startOrResume, .pause, .startOrResume, .end]
        )
    }

    @Test func autoContinueCompletionDoesNotAddStartOrPause() {
        let fixture = makeFixture(
            suite: "FocusTimerFeedback.auto",
            autoContinue: true
        )
        fixture.timer.beginQuickSession()
        fixture.feedback.reset()

        fixture.timer.completePhaseNow()
        fixture.timer.completePhaseNow()

        #expect(
            fixture.feedback.events
                == [.focusComplete, .breakComplete]
        )
        #expect(fixture.timer.isRunning)
    }

    @Test func manualNextPhaseUsesCompletionThenOneStart() {
        let fixture = makeFixture(
            suite: "FocusTimerFeedback.manual",
            autoContinue: false
        )
        fixture.timer.beginQuickSession()
        fixture.feedback.reset()

        fixture.timer.completePhaseNow()

        #expect(fixture.feedback.events == [.focusComplete])
        #expect(fixture.timer.isWaitingForManualStart)
        #expect(!fixture.timer.isRunning)

        fixture.timer.startNextPhase()

        #expect(
            fixture.feedback.events
                == [.focusComplete, .startOrResume]
        )
    }

    @Test func nonEventMutationsRemainSilent() {
        let fixture = makeFixture(suite: "FocusTimerFeedback.silent")
        fixture.timer.beginQuickSession()
        fixture.feedback.reset()

        fixture.timer.extendCurrentPhase()
        fixture.settings.workDurationMinutes = 30
        fixture.timer.beginQuickSession()
        fixture.timer.resetCurrentSession()
        fixture.timer.reset()

        #expect(fixture.feedback.events.isEmpty)
    }

    @Test func sessionReplacementIsSilent() {
        let fixture = makeFixture(suite: "FocusTimerFeedback.replacement")
        fixture.timer.beginQuickSession()
        fixture.feedback.reset()

        fixture.timer.discardSessionForReplacement()
        fixture.timer.beginSession(
            memoryID: UUID(),
            memoryTitle: "Replacement",
            recipe: FocusRecipe.from(settings: fixture.settings)
        )

        #expect(fixture.feedback.events.isEmpty)
        #expect(fixture.timer.isRunning)
    }

    private func makeFixture(
        suite: String,
        autoContinue: Bool = true
    ) -> Fixture {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let settings = FocusSettings(defaults: defaults)
        settings.autoContinue = autoContinue
        let feedback = FocusFeedbackSpy()
        let timer = FocusTimer(settings: settings, feedback: feedback)
        return Fixture(
            settings: settings,
            feedback: feedback,
            timer: timer
        )
    }

    private struct Fixture {
        let settings: FocusSettings
        let feedback: FocusFeedbackSpy
        let timer: FocusTimer
    }
}
