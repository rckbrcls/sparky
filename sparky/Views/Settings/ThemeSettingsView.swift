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
        SettingsPane {
            VStack(spacing: 0) {
                ForEach(AppTheme.allCases) { theme in
                    themeRow(theme)

                    if theme != AppTheme.allCases.last {
                        Divider()
                            .padding(.leading, 52)
                            .padding(.trailing, 12)
                    }
                }
            }
            .cardStyle()
        }
        .navigationTitle("Appearance")
        .inlinePhoneNavigationTitle()
    }

    private func themeRow(_ theme: AppTheme) -> some View {
        Button {
            themeManager.setTheme(theme)
        } label: {
            HStack(spacing: 16) {
                Image(systemName: theme.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 24, height: 24, alignment: .center)

                Text(theme.displayName)
                    .foregroundStyle(.primary)

                Spacer()

                if themeManager.currentTheme == theme {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        ThemeSettingsView()
            .environmentObject(ThemeManager.shared)
    }
}
