//
//  SettingsView.swift
//  sparky
//
//  Created by Codex on 15/10/25.
//

import SwiftUI

struct SettingsView: View {
    @Binding private var navigationPath: NavigationPath
    private let embedsInNavigationStack: Bool
    private let focusSettings: FocusSettings?
    private let focusFeedback: FocusFeedbackHandling?

    private enum Route: Hashable {
        case appearance
        case appIcon
        case advanced
        case focus
    }

    @StateObject private var appIconManager = AppIconManager()

    init(
        navigationPath: Binding<NavigationPath>,
        embedsInNavigationStack: Bool = true,
        focusSettings: FocusSettings? = nil,
        focusFeedback: FocusFeedbackHandling? = nil
    ) {
        _navigationPath = navigationPath
        self.embedsInNavigationStack = embedsInNavigationStack
        self.focusSettings = focusSettings
        self.focusFeedback = focusFeedback
    }

    var body: some View {
        Group {
            if embedsInNavigationStack {
                NavigationStack(path: $navigationPath) {
                    settingsList
                        .navigationDestination(for: Route.self) { destination in
                            destinationView(for: destination)
                        }
                }
            } else {
                settingsList
                    .navigationDestination(for: Route.self) { destination in
                        destinationView(for: destination)
                    }
            }
        }
    }
}

private extension SettingsView {
    var settingsList: some View {
        List {
            Section {
                ZStack {
                    NavigationLink(value: Route.appearance) {
                        EmptyView()
                    }
                    .opacity(0)

                    SettingsRow(
                        iconName: "circle.lefthalf.filled",
                        title: "Appearance"
                    )
                }
                .listRowInsets(.init(top: 6, leading: 20, bottom: 6, trailing: 20))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                if PlatformCapabilities.current.supportsAlternateAppIcon {
                    ZStack {
                        NavigationLink(value: Route.appIcon) {
                            EmptyView()
                        }
                        .opacity(0)

                        SettingsRow(
                            iconName: "square.dashed",
                            title: "App Icon"
                        )
                    }
                    .listRowInsets(.init(top: 6, leading: 20, bottom: 6, trailing: 20))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                if focusSettings != nil, focusFeedback != nil {
                    ZStack {
                        NavigationLink(value: Route.focus) {
                            EmptyView()
                        }
                        .opacity(0)

                        SettingsRow(
                            iconName: "timer",
                            title: "Focus"
                        )
                    }
                    .listRowInsets(.init(top: 6, leading: 20, bottom: 6, trailing: 20))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                ZStack {
                    NavigationLink(value: Route.advanced) {
                        EmptyView()
                    }
                    .opacity(0)

                    SettingsRow(
                        iconName: "gearshape.2",
                        title: "Advanced"
                    )
                }
                .listRowInsets(.init(top: 6, leading: 20, bottom: 6, trailing: 20))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .compactPhoneListSections()
        .contentMargins(.top, 0, for: .scrollContent)
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.Theme.secondaryBackground.ignoresSafeArea())
        .navigationTitle("Settings")
        .inlinePhoneNavigationTitle()
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 70)
        }
    }

    @ViewBuilder
    private func destinationView(for destination: Route) -> some View {
        switch destination {
        case .appearance:
            ThemeSettingsView()
        case .appIcon:
            AppIconSettingsView(appIconManager: appIconManager)
        case .advanced:
            AdvancedSettingsView()
        case .focus:
            if let focusSettings, let focusFeedback {
                FocusSettingsView(
                    settings: focusSettings,
                    feedback: focusFeedback
                )
            } else {
                EmptyView()
            }
        }
    }
}

private struct AppIconSettingsView: View {
    @ObservedObject var appIconManager: AppIconManager
    @Environment(\.colorScheme) private var colorScheme

    let columns = [
        GridItem(.adaptive(minimum: 80))
    ]

    var body: some View {
        List {
            Section {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(AppIcon.allCases) { icon in
                        Button {
                            appIconManager.changeIcon(to: icon)
                        } label: {
                            VStack(spacing: 8) {
                                Image(icon.previewImageName)
                                    .renderingMode(.original)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 80, height: 80)
                                    .clipShape(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .stroke(
                                                appIconManager.currentIcon == icon
                                                    ? Color.Theme.textPrimary
                                                    : Color.Theme.elementBorder,
                                                lineWidth: appIconManager.currentIcon == icon ? 3 : 1
                                            )
                                    )
                                    .shadow(radius: 2)

                                Text(icon.displayTitle)
                                    .font(.caption)
                                    .foregroundStyle(appIconManager.currentIcon == icon ? .primary : .secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(
                            appIconManager.currentIcon == icon ? .isSelected : []
                        )
                    }
                }
                .padding(12)
                .background {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(iconListBackground)
                        .stroke(Color.Theme.elementBorder, lineWidth: 1)
                        .shadow(
                            color: .black.opacity(0.06),
                            radius: 24,
                            x: 3,
                            y: 3
                        )
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
        .navigationTitle("App Icon")
        .inlinePhoneNavigationTitle()
        .alert("Failed to Change Icon", isPresented: $appIconManager.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            if let error = appIconManager.error {
                Text(error.localizedDescription)
            }
        }
    }

    private var iconListBackground: Color {
        colorScheme == .dark
            ? Color.Theme.background
            : Color.Theme.tertiaryBackground
    }
}

private struct SettingsRow: View {
    let iconName: String
    let title: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: iconName)
                .font(.system(size: 20, weight: .semibold))
                .frame(width: 24, height: 24, alignment: .center)

            Text(title)
                .foregroundStyle(.primary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .cardStyle()
    }
}

#Preview {
    SettingsView(navigationPath: .constant(NavigationPath()), embedsInNavigationStack: true)
}
