//
//  MCPSettingsView.swift
//  sparky
//

import SwiftUI

struct MCPSettingsView: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        NavigationStack {
            SettingsPane {
                RemoteMCPSettingsSection(service: environment.remoteSync)
                    .cardStyle()
            }
            .navigationTitle("MCP")
            .inlinePhoneNavigationTitle()
        }
    }
}
