import Foundation

enum MeCharacterMood: String, CaseIterable, Equatable {
    case sad
    case hopeful
    case happy
    case euphoric

    nonisolated static func streak(for value: Int) -> MeCharacterMood {
        switch max(value, 0) {
        case 0:
            return .sad
        case 1..<7:
            return .hopeful
        case 7..<30:
            return .happy
        default:
            return .euphoric
        }
    }

    nonisolated static func completed(for value: Int) -> MeCharacterMood {
        switch max(value, 0) {
        case 0:
            return .sad
        case 1..<25:
            return .hopeful
        case 25..<100:
            return .happy
        default:
            return .euphoric
        }
    }

    nonisolated var streakImageName: String {
        switch self {
        case .sad:
            return "MeStreakSad"
        case .hopeful:
            return "MeStreakHopeful"
        case .happy:
            return "MeStreakHappy"
        case .euphoric:
            return "MeStreakEuphoric"
        }
    }

    nonisolated var completedImageName: String {
        switch self {
        case .sad:
            return "MeCompletedSad"
        case .hopeful:
            return "MeCompletedHopeful"
        case .happy:
            return "MeCompletedHappy"
        case .euphoric:
            return "MeCompletedEuphoric"
        }
    }
}
