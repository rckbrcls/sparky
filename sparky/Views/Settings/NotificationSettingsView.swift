#if os(macOS)

import AppKit
import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @ObservedObject var settings: SettingsStore
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.scenePhase) private var scenePhase

    @State private var permission: PermissionState = .notRequested
    @State private var isRequestingPermission = false

    var body: some View {
        SettingsPane {
            VStack(spacing: 12) {
                VStack(spacing: 0) {
                    cardSectionLabel("Permission")

                    cardDivider

                    permissionRow
                }
                .cardStyle()

                VStack(spacing: 0) {
                    cardSectionLabel("Memory reminders")

                    cardDivider

                    soundPicker
                }
                .cardStyle()
            }
        }
        .navigationTitle("Notifications")
        .task { await refreshPermission() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await refreshPermission() }
        }
        .onChange(of: settings.notificationSound) { _, _ in
            Task {
                await environment.triggerExecutorCoordinator.sync(
                    memories: environment.memoryService.memories
                )
            }
        }
    }

    private var soundPicker: some View {
        HStack(spacing: 12) {
            Text("Sound")

            Spacer()

            Picker("Sound", selection: $settings.notificationSound) {
                ForEach(MemoryNotificationSound.allCases) { sound in
                    Text(sound.title)
                        .tag(sound)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .tint(Color.Theme.textPrimary)
            .fixedSize()

            Button("Test") {
                guard let cue = settings.notificationSound.previewCue else { return }
                try? environment.focusSoundService.play(cue)
            }
            .disabled(!settings.notificationSound.canPreview)
            .foregroundStyle(Color.Theme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
    }

    private var permissionRow: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("System permission")
                    .foregroundStyle(.primary)

                Text(permission.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(permission.actionTitle) {
                performPermissionAction()
            }
            .disabled(isRequestingPermission)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
    }

    private var cardDivider: some View {
        Divider()
            .padding(.horizontal, 12)
    }

    private func cardSectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
    }

    private func performPermissionAction() {
        switch permission {
        case .notRequested:
            Task {
                isRequestingPermission = true
                await environment.triggerExecutorCoordinator.scheduled.requestAuthorization(force: true)
                await refreshPermission()
                isRequestingPermission = false
            }
        case .allowed, .denied:
            openSystemNotificationSettings()
        }
    }

    private func refreshPermission() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        permission = PermissionState(authorizationStatus: settings.authorizationStatus)
    }

    private func openSystemNotificationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}

private enum PermissionState {
    case notRequested
    case allowed
    case denied

    init(authorizationStatus: UNAuthorizationStatus) {
        switch authorizationStatus {
        case .notDetermined:
            self = .notRequested
        case .denied:
            self = .denied
        case .authorized, .provisional, .ephemeral:
            self = .allowed
        @unknown default:
            self = .denied
        }
    }

    var label: String {
        switch self {
        case .notRequested: "Not requested"
        case .allowed: "Allowed"
        case .denied: "Denied"
        }
    }

    var actionTitle: String {
        switch self {
        case .notRequested: "Allow Notifications"
        case .allowed, .denied: "Open System Settings"
        }
    }
}

#endif
