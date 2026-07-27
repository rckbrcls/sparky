import Foundation

protocol FocusFeedbackHandling: AnyObject {
    func handle(_ event: FocusFeedbackEvent)
    func preview(_ sound: FocusSoundChoice)
}

final class NoOpFocusFeedbackHandler: FocusFeedbackHandling {
    func handle(_ event: FocusFeedbackEvent) {}
    func preview(_ sound: FocusSoundChoice) {}
}
