//
//  Color+Theme.swift
//  sparky
//
//  Created by Claude on 30/01/26.
//

import SwiftUI

// MARK: - Semantic Colors Extension
extension Color {

    // MARK: - Backgrounds

    /// Primary background color for the app
    static let themeBackground = Color("Background")

    /// Secondary background for cards and elevated elements
    static let themeSecondaryBackground = Color("SecondaryBackground")

    /// Tertiary background for nested elements
    static let themeTertiaryBackground = Color("TertiaryBackground")

    /// Background for grouped content (like settings sections)
    static let themeGroupedBackground = Color("GroupedBackground")

    // MARK: - Text Colors

    /// Primary text color for main content
    static let themeTextPrimary = Color("TextPrimary")

    /// Secondary text color for subtitles and descriptions
    static let themeTextSecondary = Color("TextSecondary")

    /// Tertiary text color for hints and placeholders
    static let themeTextTertiary = Color("TextTertiary")

    // MARK: - UI Elements

    /// Color for separators and dividers
    static let themeSeparator = Color("DividerColor")

    /// Color for borders and outlines
    static let themeBorder = Color("Border")

    // MARK: - Semantic Colors

    /// Success color for positive feedback
    static let themeSuccess = Color("Success")

    /// Warning color for alerts and cautions
    static let themeWarning = Color("Warning")

    /// Destructive color for delete and dangerous actions
    static let themeDestructive = Color("Destructive")
}

// MARK: - Theme Namespace
extension Color {
    /// Namespace for all theme colors
    enum Theme {
        // Backgrounds
        static let background = Color.themeBackground
        static let secondaryBackground = Color.themeSecondaryBackground
        static let tertiaryBackground = Color.themeTertiaryBackground
        static let groupedBackground = Color.themeGroupedBackground

        // Text
        static let textPrimary = Color.themeTextPrimary
        static let textSecondary = Color.themeTextSecondary
        static let textTertiary = Color.themeTextTertiary

        // UI Elements
        static let separator = Color.themeSeparator
        static let border = Color.themeBorder

        // Semantic
        static let success = Color.themeSuccess
        static let warning = Color.themeWarning
        static let destructive = Color.themeDestructive
    }
}
