import Foundation
import os

@MainActor
final class FocusFeedbackService: FocusFeedbackHandling {
    nonisolated private static let logger = Logger(
        subsystem: "sparky",
        category: "FocusFeedbackService"
    )

    private let settings: FocusSettings
    private let soundPlayer: FocusSoundPlaying
    private let notificationSender: FocusNotificationSending

    init(
        settings: FocusSettings,
        soundPlayer: FocusSoundPlaying,
        notificationSender: FocusNotificationSending
    ) {
        self.settings = settings
        self.soundPlayer = soundPlayer
        self.notificationSender = notificationSender
    }

    func handle(_ event: FocusFeedbackEvent) {
        if settings.soundsEnabled {
            play(cue(for: event))
        }

        if settings.notificationsEnabled, event.isCompletion {
            do {
                try notificationSender.sendCompletion(for: event)
            } catch {
                Self.logger.error(
                    "Focus notification dispatch failed: \(error.localizedDescription)"
                )
            }
        }
    }

    func preview(_ sound: FocusSoundChoice) {
        guard settings.soundsEnabled else { return }
        play(.completion(sound))
    }

    private func cue(for event: FocusFeedbackEvent) -> FocusSoundCue {
        switch event {
        case .startOrResume:
            return .start
        case .pause:
            return .pause
        case .end:
            return .end
        case .focusComplete:
            return .completion(settings.focusCompletionSound)
        case .breakComplete:
            return .completion(settings.breakCompletionSound)
        }
    }

    private func play(_ cue: FocusSoundCue) {
        do {
            try soundPlayer.play(cue)
        } catch {
            Self.logger.error(
                "Focus sound dispatch failed: \(error.localizedDescription)"
            )
        }
    }
}
