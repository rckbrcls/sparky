//
//  SettingsView.swift
//  i-cant-miss
//
//  Created by Codex on 15/10/25.
//

import SwiftUI
import UserNotifications
import CoreLocation
import UIKit

struct SettingsView: View {
    @ObservedObject private var settings: SettingsStore
    @ObservedObject private var geofenceManager: LocationTriggerExecutor
    private let environment: AppEnvironment
    @Binding private var navigationPath: NavigationPath
    private let embedsInNavigationStack: Bool

    private enum Route: Hashable {
        case reminders
        case notifications
        case location
        case appIcon
    }

    @StateObject private var appIconManager = AppIconManager()

    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var isRequestingNotifications = false
    @State private var isRequestingLocation = false

    init(environment: AppEnvironment, navigationPath: Binding<NavigationPath>, embedsInNavigationStack: Bool = true) {
        self.environment = environment
        _settings = ObservedObject(wrappedValue: environment.settings)
        _geofenceManager = ObservedObject(wrappedValue: environment.geofenceManager)
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
        .task {
            await refreshNotificationStatus()
        }
        .onChange(of: settings.preferAlwaysOnLocationAccess) { _, newValue in
            requestLocationAuthorization(always: newValue)
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
                    NavigationLink(value: Route.reminders) {
                        EmptyView()
                    }
                    .opacity(0)

                    SettingsRow(
                        iconName: "checklist",
                        title: "Reminders"
                    )
                }
                .listRowInsets(.init(top: 8, leading: 20, bottom: 8, trailing: 20))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                ZStack {
                    NavigationLink(value: Route.appIcon) {
                        EmptyView()
                    }
                    .opacity(0)

                    SettingsRow(
                        iconName: "square.dashed", // Placeholder, maybe use the current icon?
                        title: "App Icon"
                    )
                }
                .listRowInsets(.init(top: 8, leading: 20, bottom: 8, trailing: 20))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                ZStack {
                    NavigationLink(value: Route.notifications) {
                        EmptyView()
                    }
                    .opacity(0)

                    SettingsRow(
                        iconName: "bell.badge",
                        title: "Notifications"
                    )
                }
                .listRowInsets(.init(top: 8, leading: 20, bottom: 8, trailing: 20))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                ZStack {
                    NavigationLink(value: Route.location) {
                        EmptyView()
                    }
                    .opacity(0)

                    SettingsRow(
                        iconName: "location.circle",
                        title: "Location & Geofencing"
                    )
                }
                .listRowInsets(.init(top: 8, leading: 20, bottom: 8, trailing: 20))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .listSectionSpacing(.compact)
        .contentMargins(.top, 0, for: .scrollContent)
        .listStyle(.plain)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height:  70)
        }
    }

    @ViewBuilder
    private func destinationView(for destination: Route) -> some View {
        switch destination {
        case .reminders:
            ReminderSettingsView(settings: settings)
        case .notifications:
            NotificationSettingsView(
                settings: settings,
                notificationStatus: $notificationStatus,
                isRequestingNotifications: $isRequestingNotifications,
                requestAuthorization: { await requestNotificationAuthorization() }
            )
        case .location:
            LocationSettingsView(
                settings: settings,
                geofenceManager: geofenceManager,
                isRequestingLocation: $isRequestingLocation,
                requestAuthorization: requestLocationAuthorization
            )
        case .appIcon:
            AppIconSettingsView(appIconManager: appIconManager)
        }
    }
}

// MARK: - Detail Views

private struct ReminderSettingsView: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        Form {
            Section {
                Picker("Timeline default filter", selection: $settings.defaultTimelineFilter) {
                    ForEach(MemoryTimelineFilter.allCases, id: \.self) { filter in
                        Text(filter.displayTitle).tag(filter)
                    }
                }

                Stepper(value: $settings.defaultSnoozeMinutes, in: 5...180, step: 5) {
                    Text("Snooze duration: \(durationDescription(minutes: settings.defaultSnoozeMinutes))")
                }
                .accessibilityLabel("Default snooze duration")

                Stepper(value: $settings.defaultPostponeMinutes, in: 15...720, step: 15) {
                    Text("Postpone duration: \(durationDescription(minutes: settings.defaultPostponeMinutes))")
                }
                .accessibilityLabel("Default postpone duration")
            } footer: {
                Text("These defaults affect new reminders and quick actions in the timeline.")
            }
        }
        .navigationTitle("Reminders")
    }
}

private struct NotificationSettingsView: View {
    @ObservedObject var settings: SettingsStore
    @Binding var notificationStatus: UNAuthorizationStatus
    @Binding var isRequestingNotifications: Bool

    let requestAuthorization: () async -> Void

    var body: some View {
        Form {
            Section {
                Toggle("Play sound for reminder alerts", isOn: $settings.notificationSoundEnabled)

                Button(role: .none) {
                    Task {
                        await requestAuthorization()
                    }
                } label: {
                    HStack {
                        if isRequestingNotifications {
                            ProgressView()
                        }
                        Text("Request Notification Permission")
                    }
                }
                .disabled(isRequestingNotifications)

                Button("Open System Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            } footer: {
                Text("Notification permissions control badges, sounds and alerts for your reminders.")
            }
        }
        .navigationTitle("Notifications")
    }
}

private struct LocationSettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var geofenceManager: LocationTriggerExecutor
    @Binding var isRequestingLocation: Bool

    let requestAuthorization: (Bool) -> Void

    var body: some View {
        Form {
            Section {
                Toggle("Prefer always-on location access", isOn: $settings.preferAlwaysOnLocationAccess)

                Button(role: .none) {
                    requestAuthorization(settings.preferAlwaysOnLocationAccess)
                } label: {
                    HStack {
                        if isRequestingLocation {
                            ProgressView()
                        }
                        Text("Request Location Access")
                    }
                }
                .disabled(isRequestingLocation)
            } footer: {
                Text("Location-based triggers work best with always-on access, but you can opt for when-in-use if you prefer.")
            }
        }
        .navigationTitle("Location & Geofencing")
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

// MARK: - Actions

private extension SettingsView {
    func refreshNotificationStatus() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        await MainActor.run {
            notificationStatus = settings.authorizationStatus
        }
    }

    @MainActor
    func requestNotificationAuthorization() async {
        guard !isRequestingNotifications else { return }
        isRequestingNotifications = true
        defer { isRequestingNotifications = false }
        await environment.notificationScheduler.requestAuthorization(force: true)
        await refreshNotificationStatus()
    }

    @MainActor
    func requestLocationAuthorization(always: Bool) {
        guard !isRequestingLocation else { return }
        isRequestingLocation = true
        defer { isRequestingLocation = false }
        environment.geofenceManager.requestAuthorization(always: always)
    }

}

// MARK: - Shared Helpers

private func durationDescription(minutes: Int) -> String {
    guard minutes >= 60, minutes % 60 == 0 else {
        return "\(minutes) min"
    }
    let hours = minutes / 60
    return "\(hours) hour" + (hours == 1 ? "" : "s")
}

// MARK: - Extensions


private extension UNAuthorizationStatus {
    var displayName: String {
        switch self {
        case .notDetermined: return "Not determined"
        case .denied: return "Denied"
        case .authorized: return "Authorized"
        case .provisional: return "Provisional"
        case .ephemeral: return "Ephemeral"
        @unknown default: return "Unknown"
        }
    }
}

private extension CLAuthorizationStatus {
    var displayName: String {
        switch self {
        case .notDetermined: return "Not determined"
        case .restricted: return "Restricted"
        case .denied: return "Denied"
        case .authorizedAlways: return "Always"
        case .authorizedWhenInUse: return "When in use"
        @unknown default: return "Unknown"
        }
    }
}

#Preview {
    let environment = AppEnvironment(persistence: PersistenceController.preview)
    environment.bootstrap()
    return SettingsView(
        environment: environment,
        navigationPath: .constant(NavigationPath())
    )
}
