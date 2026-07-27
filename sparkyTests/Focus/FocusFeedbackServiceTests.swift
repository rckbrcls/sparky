import Foundation
import Testing
@testable import sparky

@MainActor
struct FocusFeedbackServiceTests {
    @Test func fourToggleCombinationsRemainIndependent() {
        for soundsEnabled in [false, true] {
            for notificationsEnabled in [false, true] {
                let fixture = makeFixture(
                    suite: "FocusFeedback.matrix.\(soundsEnabled).\(notificationsEnabled)"
                )
                fixture.settings.soundsEnabled = soundsEnabled
                fixture.settings.notificationsEnabled = notificationsEnabled

                fixture.service.handle(.focusComplete)

                #expect(fixture.sound.cues.count == (soundsEnabled ? 1 : 0))
                #expect(
                    fixture.notifications.events.count
                        == (notificationsEnabled ? 1 : 0)
                )
            }
        }
    }

    @Test func completionEventsUseTheirSelectedSoundsExactlyOnce() {
        let fixture = makeFixture(suite: "FocusFeedback.selected")
        fixture.settings.focusCompletionSound = .ping
        fixture.settings.breakCompletionSound = .pop

        fixture.service.handle(.focusComplete)
        fixture.service.handle(.breakComplete)

        #expect(
            fixture.sound.cues
                == [.completion(.ping), .completion(.pop)]
        )
        #expect(
            fixture.notifications.events
                == [.focusComplete, .breakComplete]
        )
    }

    @Test func lifecycleEventsPlayOnlyFixedCues() {
        let fixture = makeFixture(suite: "FocusFeedback.lifecycle")

        fixture.service.handle(.startOrResume)
        fixture.service.handle(.pause)
        fixture.service.handle(.end)

        #expect(fixture.sound.cues == [.start, .pause, .end])
        #expect(fixture.notifications.events.isEmpty)
    }

    @Test func previewUsesSelectionWithoutNotification() {
        let fixture = makeFixture(suite: "FocusFeedback.preview")

        fixture.service.preview(.chime)

        #expect(fixture.sound.cues == [.completion(.chime)])
        #expect(fixture.notifications.events.isEmpty)

        fixture.settings.soundsEnabled = false
        fixture.service.preview(.bell)
        #expect(fixture.sound.cues == [.completion(.chime)])
    }

    @Test func AdapterFailuresDoNotBlockOtherFeedback() {
        let fixture = makeFixture(suite: "FocusFeedback.failures")
        fixture.sound.shouldThrow = true

        fixture.service.handle(.focusComplete)

        #expect(fixture.notifications.events == [.focusComplete])

        fixture.sound.shouldThrow = false
        fixture.notifications.shouldThrow = true
        fixture.service.handle(.breakComplete)

        #expect(fixture.sound.cues == [.completion(.bell)])
    }

    private func makeFixture(suite: String) -> Fixture {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let settings = FocusSettings(defaults: defaults)
        let sound = SoundSpy()
        let notifications = NotificationSpy()
        let service = FocusFeedbackService(
            settings: settings,
            soundPlayer: sound,
            notificationSender: notifications
        )
        return Fixture(
            settings: settings,
            sound: sound,
            notifications: notifications,
            service: service
        )
    }

    private struct Fixture {
        let settings: FocusSettings
        let sound: SoundSpy
        let notifications: NotificationSpy
        let service: FocusFeedbackService
    }

    private final class SoundSpy: FocusSoundPlaying {
        var cues: [FocusSoundCue] = []
        var shouldThrow = false

        func play(_ cue: FocusSoundCue) throws {
            if shouldThrow {
                throw TestError.adapterFailure
            }
            cues.append(cue)
        }
    }

    private final class NotificationSpy: FocusNotificationSending {
        var events: [FocusFeedbackEvent] = []
        var shouldThrow = false

        func sendCompletion(for event: FocusFeedbackEvent) throws {
            if shouldThrow {
                throw TestError.adapterFailure
            }
            events.append(event)
        }
    }

    private enum TestError: Error {
        case adapterFailure
    }
}
