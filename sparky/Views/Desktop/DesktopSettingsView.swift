#if os(macOS)

import SwiftUI

struct DesktopSettingsView: View {
    @ObservedObject var environment: AppEnvironment

    private enum Pane: String, CaseIterable, Identifiable {
        case appearance = "Appearance"
        case focus = "Focus"
        case mcp = "MCP"
        case advanced = "Advanced"

        var id: String { rawValue }

        var symbol: String {
            switch self {
            case .appearance: "circle.lefthalf.filled"
            case .focus: "timer"
            case .mcp: "server.rack"
            case .advanced: "gearshape.2"
            }
        }
    }

    @State private var selection: Pane = .appearance

    var body: some View {
        ZStack {
            paneContent
                .frame(width: 640, height: 520)

            // Native toolbar tabs only. The panes live outside the TabView because scroll
            // views hosted inside it stack an extra scroll-edge blur on every tab switch.
            TabView(selection: $selection) {
                ForEach(Pane.allCases) { pane in
                    Color.clear
                        .tabItem { Label(pane.rawValue, systemImage: pane.symbol) }
                        .tag(pane)
                }
            }
            .frame(width: 1, height: 1)
            .opacity(0)
            .allowsHitTesting(false)
        }
        .background(Color.Theme.secondaryBackground)
        .containerBackground(Color.Theme.secondaryBackground, for: .window)
        .environmentObject(environment)
    }

    @ViewBuilder
    private var paneContent: some View {
        switch selection {
        case .appearance:
            ThemeSettingsView()
        case .focus:
            FocusSettingsView(
                settings: environment.focusSettings,
                feedback: environment.focusFeedbackService
            )
        case .mcp:
            MCPSettingsView()
        case .advanced:
            AdvancedSettingsView()
        }
    }
}

#endif
