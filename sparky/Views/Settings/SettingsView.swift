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

    private enum Route: Hashable {
        case appearance
        case appIcon
        case dataManagement
        case advanced
        case focus
    }

    @StateObject private var appIconManager = AppIconManager()

    init(
        navigationPath: Binding<NavigationPath>,
        embedsInNavigationStack: Bool = true,
        focusSettings: FocusSettings? = nil
    ) {
        _navigationPath = navigationPath
        self.embedsInNavigationStack = embedsInNavigationStack
        self.focusSettings = focusSettings
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
            Text("Settings")
                .appLargeTitleStyle()
                .listRowInsets(.init(top: 0, leading: 20, bottom: 0, trailing: 20))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

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

                ZStack {
                    NavigationLink(value: Route.dataManagement) {
                        EmptyView()
                    }
                    .opacity(0)

                    SettingsRow(
                        iconName: "arrow.up.arrow.down",
                        title: "Data Management"
                    )
                }
                .listRowInsets(.init(top: 6, leading: 20, bottom: 6, trailing: 20))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                if focusSettings != nil {
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
        case .dataManagement:
            DataManagementView()
        case .advanced:
            AdvancedSettingsView()
        case .focus:
            if let focusSettings {
                FocusSettingsView(settings: focusSettings)
            } else {
                EmptyView()
            }
        }
    }
}

private struct AppIconSettingsView: View {
    @ObservedObject var appIconManager: AppIconManager

    let columns = [
        GridItem(.adaptive(minimum: 80))
    ]

    var body: some View {
        List {
            Text("App Icon")
                .appLargeTitleStyle()
                .listRowInsets(.init(top: 0, leading: 20, bottom: 0, trailing: 20))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

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
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(
                                                appIconManager.currentIcon == icon ? Color.blue : Color.Theme.border,
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
                    }
                }
                .padding(12)
                .cardStyle()
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
        .alert("Failed to Change Icon", isPresented: $appIconManager.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            if let error = appIconManager.error {
                Text(error.localizedDescription)
            }
        }
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
