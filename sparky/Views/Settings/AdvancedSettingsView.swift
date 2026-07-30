//
//  AdvancedSettingsView.swift
//  sparky
//
//  Created by Claude on 20/02/26.
//

import SwiftUI

struct AdvancedSettingsView: View {
    @EnvironmentObject private var environment: AppEnvironment

    @State private var showClearCacheConfirmation = false
    @State private var showCacheClearErrorAlert = false
    @State private var showResetOnboardingConfirmation = false
    @State private var showCacheClearedAlert = false
    @State private var showOnboardingResetAlert = false
    @State private var isClearingCache = false

    var body: some View {
        List {
            Section {
                VStack(spacing: 0) {
                    onboardingRow

                    Divider()
                        .padding(.leading, 52)
                        .padding(.trailing, 12)

                    cacheRow

                    Divider()
                        .padding(.leading, 52)
                        .padding(.trailing, 12)

                    debugInfoRow
                }
                .cardStyle()
            }
            .listRowInsets(.init(top: 6, leading: 20, bottom: 0, trailing: 20))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
        .compactPhoneListSections()
        .contentMargins(.top, 0, for: .scrollContent)
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.Theme.secondaryBackground.ignoresSafeArea())
        .navigationTitle("Advanced")
        .inlinePhoneNavigationTitle()
        .alert("Clear Cache", isPresented: $showClearCacheConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                Task { await clearCache() }
            }
        } message: {
            Text("This will delete all attachment files (photos, audio, links, files). This action cannot be undone.")
        }
        .alert("Reset Onboarding", isPresented: $showResetOnboardingConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetOnboarding()
            }
        } message: {
            Text("The onboarding tutorial will be shown again next time you open the app.")
        }
        .alert("Cache Cleared", isPresented: $showCacheClearedAlert) {
            Button("OK") { }
        } message: {
            Text("All attachment files have been removed.")
        }
        .alert("Failed to Clear Cache", isPresented: $showCacheClearErrorAlert) {
            Button("OK") { }
        } message: {
            Text("The attachment files could not be removed.")
        }
        .alert("Onboarding Reset", isPresented: $showOnboardingResetAlert) {
            Button("OK") { }
        } message: {
            Text("The onboarding tutorial will appear when you reopen the app.")
        }
    }
}

// MARK: - Rows

private extension AdvancedSettingsView {
    var onboardingRow: some View {
        Button {
            showResetOnboardingConfirmation = true
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 24, height: 24, alignment: .center)

                Text("Reset Onboarding")
                    .foregroundStyle(.primary)

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    var cacheRow: some View {
        Button {
            showClearCacheConfirmation = true
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "trash")
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 24, height: 24, alignment: .center)

                Text("Clear Attachments Cache")
                    .foregroundStyle(.primary)

                if isClearingCache {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isClearingCache)
    }

    var debugInfoRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                Image(systemName: "info.circle")
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 24, height: 24, alignment: .center)

                Text("App Info")
                    .foregroundStyle(.primary)
            }

            VStack(spacing: 8) {
                debugRow(label: "Version", value: appVersion)
                debugRow(label: "Build", value: buildNumber)
                debugRow(label: "Device", value: deviceModel)
                debugRow(label: "iOS", value: systemVersion)
            }
            .padding(.leading, 40)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
    }

    func debugRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.monospaced())
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - Actions

private extension AdvancedSettingsView {
    func clearCache() async {
        isClearingCache = true
        do {
            try await environment.attachmentStore.deleteAllAttachments()
            showCacheClearedAlert = true
        } catch {
            showCacheClearErrorAlert = true
        }
        isClearingCache = false
    }

    func resetOnboarding() {
        environment.settings.hasCompletedOnboarding = false
        showOnboardingResetAlert = true
    }
}

// MARK: - Device Info

private extension AdvancedSettingsView {
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        let identifier = mirror.children.reduce("") { result, element in
            guard let value = element.value as? Int8, value != 0 else { return result }
            return result + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }

    var systemVersion: String {
        ProcessInfo.processInfo.operatingSystemVersionString
    }
}

#Preview {
    NavigationStack {
        AdvancedSettingsView()
            .environmentObject(AppEnvironment(dataController: .preview))
    }
}
