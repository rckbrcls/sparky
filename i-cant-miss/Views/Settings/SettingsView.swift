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
    @ObservedObject private var geofenceManager: GeofenceManager
    private let environment: AppEnvironment

    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var isRequestingNotifications = false
    @State private var isRequestingLocation = false

    init(environment: AppEnvironment) {
        self.environment = environment
        _settings = ObservedObject(wrappedValue: environment.settings)
        _geofenceManager = ObservedObject(wrappedValue: environment.geofenceManager)
    }

    var body: some View {
        NavigationStack {
            Form {
                reminderSection
                notificationSection
                locationSection
            }
            .navigationTitle("Settings")
        }
        .task {
            await refreshNotificationStatus()
        }
        .onChange(of: settings.preferAlwaysOnLocationAccess) { _, newValue in
            requestLocationAuthorization(always: newValue)
        }
    }

    private var reminderSection: some View {
        Section {
            Picker("Timeline default filter", selection: $settings.defaultTimelineFilter) {
                ForEach(ReminderService.TimelineFilter.allCases, id: \.self) { filter in
                    Text(filter.displayTitle).tag(filter)
                }
            }

            Picker("Default reminder priority", selection: $settings.defaultReminderPriority) {
                ForEach(ReminderPriority.allCases, id: \.self) { priority in
                    Label(priority.displayName, systemImage: priority.iconName)
                        .tag(priority)
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
        } header: {
            Text("Reminders")
        } footer: {
            Text("These defaults affect new reminders and quick actions in the timeline.")
        }
    }

    private var notificationSection: some View {
        Section {
            Toggle("Play sound for reminder alerts", isOn: $settings.notificationSoundEnabled)

            HStack {
                Text("Status")
                Spacer()
                Text(notificationStatus.displayName)
                    .foregroundStyle(.secondary)
            }

            Button(role: .none) {
                Task {
                    await requestNotificationAuthorization()
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
        } header: {
            Text("Notifications")
        } footer: {
            Text("Notification permissions control badges, sounds and alerts for your reminders.")
        }
    }

    private var locationSection: some View {
        Section {
            Toggle("Prefer always-on location access", isOn: $settings.preferAlwaysOnLocationAccess)

            HStack {
                Text("Authorization")
                Spacer()
                Text(geofenceManager.authorizationStatus.displayName)
                    .foregroundStyle(.secondary)
            }

            Button(role: .none) {
                requestLocationAuthorization(always: settings.preferAlwaysOnLocationAccess)
            } label: {
                HStack {
                    if isRequestingLocation {
                        ProgressView()
                    }
                    Text("Request Location Access")
                }
            }
            .disabled(isRequestingLocation)
        } header: {
            Text("Location & Geofencing")
        } footer: {
            Text("Location-based triggers work best with always-on access, but you can opt for when-in-use if you prefer.")
        }
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

    func durationDescription(minutes: Int) -> String {
        guard minutes >= 60, minutes % 60 == 0 else {
            return "\(minutes) min"
        }
        let hours = minutes / 60
        return "\(hours) hour" + (hours == 1 ? "" : "s")
    }
}

// MARK: - Helpers

private extension ReminderService.TimelineFilter {
    var displayTitle: String {
        switch self {
        case .all: return "All"
        case .overdue: return "Overdue"
        case .today: return "Today"
        case .upcoming: return "Upcoming"
        case .thisWeek: return "This Week"
        case .byPriority: return "Priority"
        case .byTriggerType: return "Type"
        case .recurring: return "Recurring"
        case .noTriggers: return "No Triggers"
        }
    }
}

private extension ReminderPriority {
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
}

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
    return SettingsView(environment: environment)
}
