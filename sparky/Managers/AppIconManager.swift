
import SwiftUI
import Combine
import os
#if canImport(UIKit)
import UIKit
#endif

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
    private static let logger = Logger(subsystem: "sparky", category: "AppIconManager")

    @Published private(set) var currentIcon: AppIcon = .primary
    @Published var error: Error?
    @Published var showError = false

    init() {
        #if os(iOS)
        if let iconName = UIApplication.shared.alternateIconName,
           let icon = AppIcon(rawValue: iconName) {
            self.currentIcon = icon
        } else {
            self.currentIcon = .primary
        }
        #else
        self.currentIcon = .primary
        #endif
    }

    func changeIcon(to icon: AppIcon) {
        #if os(iOS)
        Self.logger.debug("Requesting change to: \(icon.rawValue), current: \(self.currentIcon.rawValue)")

        guard icon != currentIcon else {
            Self.logger.debug("Icon is already set to \(icon.rawValue). Ignoring.")
            return
        }

        Task {
            do {
                let iconName = icon.iconName
                Self.logger.debug("Calling setAlternateIconName with: \(String(describing: iconName))")
                try await UIApplication.shared.setAlternateIconName(iconName)
                Self.logger.info("Icon changed to: \(icon.rawValue)")
                self.currentIcon = icon
            } catch {
                Self.logger.error("Error changing app icon: \(error.localizedDescription)")
                self.error = error
                self.showError = true
            }
        }
        #endif
    }
}
