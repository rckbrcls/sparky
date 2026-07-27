import Foundation

enum FocusSoundCue: Equatable {
    case start
    case pause
    case end
    case completion(FocusSoundChoice)

    var resourceName: String {
        switch self {
        case .start:
            return "start"
        case .pause:
            return "pause"
        case .end:
            return "end"
        case let .completion(sound):
            return sound.rawValue
        }
    }
}

protocol FocusSoundPlaying: AnyObject {
    func play(_ cue: FocusSoundCue) throws
}
