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
        List {
            Text("Appearance")
                .appLargeTitleStyle()
                .listRowInsets(.init(top: 0, leading: 20, bottom: 0, trailing: 20))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            Section {
                ForEach(AppTheme.allCases) { theme in
                    themeRow(theme)
                }
            }
            .listRowInsets(.init(top: 6, leading: 20, bottom: 6, trailing: 20))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
        .compactPhoneListSections()
        .contentMargins(.top, 0, for: .scrollContent)
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.Theme.secondaryBackground.ignoresSafeArea())
        .inlinePhoneNavigationTitle()
    }

    private func themeRow(_ theme: AppTheme) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                themeManager.setTheme(theme)
            }
        } label: {
            HStack(spacing: 16) {
                Image(systemName: theme.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 24, height: 24, alignment: .center)

                VStack(alignment: .leading, spacing: 2) {
                    Text(theme.displayName)
                        .foregroundStyle(.primary)
                    Text(themeDescription(for: theme))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if themeManager.currentTheme == theme {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .cardStyle()
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
