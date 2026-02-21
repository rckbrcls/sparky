//
//  ThemeManager.swift
//  sparky
//
//  Created by Claude on 30/01/26.
//

import SwiftUI
import Combine

// MARK: - App Theme Enum
enum AppTheme: String, CaseIterable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Theme Manager
@MainActor
final class ThemeManager: ObservableObject {

    // MARK: - Singleton
    static let shared = ThemeManager()

    // MARK: - Storage Key
    private enum Keys {
        static let appTheme = "settings.appTheme"
    }

    // MARK: - Properties
    private let defaults: UserDefaults

    @Published var currentTheme: AppTheme {
        didSet {
            defaults.set(currentTheme.rawValue, forKey: Keys.appTheme)
            updateAppearance()
        }
    }

    // MARK: - Initialization
    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let storedTheme = defaults.string(forKey: Keys.appTheme) ?? AppTheme.system.rawValue
        self.currentTheme = AppTheme(rawValue: storedTheme) ?? .system
    }

    // MARK: - Public Methods

    /// Sets the theme and persists it
    func setTheme(_ theme: AppTheme) {
        currentTheme = theme
    }

    /// Returns the ColorScheme to use, or nil for system default
    var preferredColorScheme: ColorScheme? {
        currentTheme.colorScheme
    }

    /// Updates the window appearance for scenes that need it
    func updateAppearance() {
        // This is handled automatically by SwiftUI's preferredColorScheme
        // but can be extended for UIKit integration if needed
    }
}

// MARK: - View Modifier for Theme
struct ThemeModifier: ViewModifier {
    @ObservedObject var themeManager = ThemeManager.shared

    func body(content: Content) -> some View {
        content
            .preferredColorScheme(themeManager.preferredColorScheme)
    }
}

extension View {
    /// Applies the app's theme preference to the view hierarchy
    func withAppTheme() -> some View {
        modifier(ThemeModifier())
    }
}

// MARK: - Environment Key for Theme
private struct ThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme = .system
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}
