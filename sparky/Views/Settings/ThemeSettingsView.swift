//
//  ThemeSettingsView.swift
//  sparky
//
//  Created by Claude on 30/01/26.
//

import SwiftUI

struct ThemeSettingsView: View {
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(AppTheme.allCases) { theme in
                    ThemeOptionRow(
                        theme: theme,
                        isSelected: themeManager.currentTheme == theme
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            themeManager.setTheme(theme)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Appearance")
    }
}

private struct ThemeOptionRow: View {
    let theme: AppTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.Theme.tertiaryBackground)
                        .frame(width: 44, height: 44)

                    Image(systemName: theme.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(isSelected ? .accent : .secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(theme.displayName)
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color.Theme.textPrimary)

                    Text(themeDescription(for: theme))
                        .font(.caption)
                        .foregroundStyle(Color.Theme.textSecondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.accent)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.Theme.secondaryBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.Theme.border, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func themeDescription(for theme: AppTheme) -> String {
        switch theme {
        case .system:
            return "Follows your device settings"
        case .light:
            return "Always use light appearance"
        case .dark:
            return "Always use dark appearance"
        }
    }
}

#Preview {
    NavigationStack {
        ThemeSettingsView()
            .environmentObject(ThemeManager.shared)
    }
}
