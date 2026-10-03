//
//  MCPSettingsView.swift
//  sparky
//

import SwiftUI

struct MCPSettingsView: View {
    @EnvironmentObject private var environment: AppEnvironment
    private let embedsInNavigationStack: Bool
    @State private var showsLogs = false

    init(embedsInNavigationStack: Bool = true) {
        self.embedsInNavigationStack = embedsInNavigationStack
    }

    var body: some View {
        if embedsInNavigationStack {
            NavigationStack { content }
        } else {
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        #if os(iOS)
        phoneContent
        #else
        macContent
        #endif
    }

    #if os(iOS)
    private var phoneContent: some View {
        ScrollView {
            RemoteMCPSettingsSection(service: environment.remoteSync) {
                showsLogs = true
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 24)
        }
        .scrollContentBackground(.hidden)
        .background(Color.Theme.secondaryBackground.ignoresSafeArea())
        .navigationTitle("MCP")
        .inlinePhoneNavigationTitle()
        .navigationDestination(isPresented: $showsLogs) {
            RemoteSyncLogScreen(service: environment.remoteSync)
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 70)
        }
    }
    #endif

    private var macContent: some View {
        SettingsPane {
            RemoteMCPSettingsSection(service: environment.remoteSync)
                .cardStyle()
        }
        .navigationTitle("MCP")
        .inlinePhoneNavigationTitle()
    }
}
