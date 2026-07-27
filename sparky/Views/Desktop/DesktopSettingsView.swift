#if os(macOS)

import SwiftUI

struct DesktopSettingsView: View {
    @ObservedObject var environment: AppEnvironment

    var body: some View {
        TabView {
            ThemeSettingsView()
                .tabItem {
                    Label("Appearance", systemImage: "circle.lefthalf.filled")
                }

            FocusSettingsView(settings: environment.focusSettings)
                .tabItem {
                    Label("Focus", systemImage: "timer")
                }

            DataManagementView()
                .tabItem {
                    Label("Data", systemImage: "externaldrive")
                }

            AdvancedSettingsView()
                .tabItem {
                    Label("Advanced", systemImage: "gearshape.2")
                }
        }
        .frame(width: 640, height: 520)
        .background(Color.Theme.secondaryBackground)
        .containerBackground(Color.Theme.secondaryBackground, for: .window)
        .toolbarBackground(Color.Theme.secondaryBackground, for: .windowToolbar)
        .toolbarBackgroundVisibility(.visible, for: .windowToolbar)
        .environmentObject(environment)
    }
}

#endif
