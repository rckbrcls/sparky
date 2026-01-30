
import SwiftUI
import Combine

enum AppIcon: String, CaseIterable, Identifiable {
    case primary = "AppIcon"
    case box = "AppIcon-box"
    case think = "AppIcon-think"

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .primary: return "Default"
        case .box: return "Box"
        case .think: return "Think"
        }
    }

    var iconName: String? {
        switch self {
        case .primary: return nil
        default: return rawValue
        }
    }

    // Helper to get the preview image name (matching the asset catalog)
    var previewImageName: String {
        switch self {
        case .primary: return "memory"
        case .box: return "box"
        case .think: return "think"
        }
    }
}

@MainActor
final class AppIconManager: ObservableObject {
    @Published private(set) var currentIcon: AppIcon = .primary
    @Published var error: Error?
    @Published var showError = false

    init() {
        if let iconName = UIApplication.shared.alternateIconName,
           let icon = AppIcon(rawValue: iconName) {
            self.currentIcon = icon
        } else {
            self.currentIcon = .primary
        }
    }

    func changeIcon(to icon: AppIcon) {
        print(" [AppIconManager] Requesting change to: \(icon.rawValue)")
        print(" [AppIconManager] Current icon: \(currentIcon.rawValue)")
        print(" [AppIconManager] Supports alternate icons: \(UIApplication.shared.supportsAlternateIcons)")

        guard icon != currentIcon else {
            print(" [AppIconManager] Icon is already set to \(icon.rawValue). Ignoring.")
            return
        }

        Task {
            do {
                let iconName = icon.iconName
                print(" [AppIconManager] Calling setAlternateIconName with: \(String(describing: iconName))")
                try await UIApplication.shared.setAlternateIconName(iconName)
                print(" [AppIconManager] Success! Icon changed to: \(icon.rawValue)")
                self.currentIcon = icon
            } catch {
                print(" [AppIconManager] Error changing app icon: \(error)")
                print(" [AppIconManager] Localized Error: \(error.localizedDescription)")
                self.error = error
                self.showError = true
            }
        }
    }
}
