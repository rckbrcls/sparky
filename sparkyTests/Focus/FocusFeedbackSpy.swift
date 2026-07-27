@testable import sparky

@MainActor
final class FocusFeedbackSpy: FocusFeedbackHandling {
    private(set) var events: [FocusFeedbackEvent] = []
    private(set) var previewedSounds: [FocusSoundChoice] = []

    func handle(_ event: FocusFeedbackEvent) {
        events.append(event)
    }

    func preview(_ sound: FocusSoundChoice) {
        previewedSounds.append(sound)
    }

    func reset() {
        events.removeAll()
        previewedSounds.removeAll()
    }
}
