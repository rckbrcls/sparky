import Foundation
import UserNotifications

enum MemoryNotificationSound: String, CaseIterable, Identifiable {
    case none
    case systemDefault = "default"
    case glass
    case bell
    case chime
    case ping
    case pop

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none:
            "None"
        case .systemDefault:
            "Default"
        case .glass, .bell, .chime, .ping, .pop:
            rawValue.capitalized
        }
    }

    var canPreview: Bool {
        previewCue != nil
    }

    var previewCue: FocusSoundCue? {
        guard let choice = FocusSoundChoice(rawValue: rawValue) else { return nil }
        return .completion(choice)
    }

    var notificationSound: UNNotificationSound? {
        switch self {
        case .none:
            return nil
        case .systemDefault:
            return .default
        case .glass, .bell, .chime, .ping, .pop:
            return UNNotificationSound(
                named: UNNotificationSoundName(rawValue: Self.bundleSoundName(for: rawValue))
            )
        }
    }

    private static func bundleSoundName(for resource: String) -> String {
        if Bundle.main.url(
            forResource: resource,
            withExtension: "caf",
            subdirectory: "FocusSounds"
        ) != nil {
            return "FocusSounds/\(resource).caf"
        }
        return "\(resource).caf"
    }
}
