import Foundation

enum FocusFeedbackEvent: Equatable {
    case startOrResume
    case pause
    case end
    case focusComplete
    case breakComplete

    var isCompletion: Bool {
        self == .focusComplete || self == .breakComplete
    }
}
