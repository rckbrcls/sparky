import Foundation

protocol FocusNotificationSending: AnyObject {
    func sendCompletion(for event: FocusFeedbackEvent) throws
}
