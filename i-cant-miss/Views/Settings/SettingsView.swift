//
//  SettingsView.swift
//  i-cant-miss
//
//  Created by Codex on 15/10/25.
//

import SwiftUI

struct SettingsView: View {
    @Binding private var navigationPath: NavigationPath
    private let embedsInNavigationStack: Bool

    private enum Route: Hashable {
        case appearance
        case appIcon
        case dataManagement
    }

    @StateObject private var appIconManager = AppIconManager()

    init(navigationPath: Binding<NavigationPath>, embedsInNavigationStack: Bool = true) {
        _navigationPath = navigationPath
        self.embedsInNavigationStack = embedsInNavigationStack
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
            }
        }
        .listSectionSpacing(.compact)
        .contentMargins(.top, 0, for: .scrollContent)
        .listStyle(.plain)
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
        }
    }
}

private struct AppIconSettingsView: View {
    @ObservedObject var appIconManager: AppIconManager

    let columns = [
        GridItem(.adaptive(minimum: 80))
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(AppIcon.allCases) { icon in
                    Button {
                        appIconManager.changeIcon(to: icon)
                    } label: {
                        VStack(spacing: 8) {
                            Image(icon.previewImageName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(appIconManager.currentIcon == icon ? Color.accentColor : Color.clear, lineWidth: 3)
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
            .padding()
        }
        .navigationTitle("App Icon")
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
