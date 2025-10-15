//
//  TimelineView.swift
//  i-cant-miss
//
//  Created by Codex on 13/10/25.
//

import SwiftUI

struct TimelineView: View {
    @StateObject private var viewModel: TimelineViewModel
    @ObservedObject private var settings: SettingsStore
    let environment: AppEnvironment
    let onCreateReminder: () -> Void
    let onEditReminder: (ReminderModel) -> Void
    @State private var showTriggers = false
    @State private var showFilterSheet = false
    private let accentColor = Color("AccentColor")

    init(environment: AppEnvironment,
         onCreateReminder: @escaping () -> Void,
         onEditReminder: @escaping (ReminderModel) -> Void) {
        self.environment = environment
        self.onCreateReminder = onCreateReminder
        self.onEditReminder = onEditReminder
        _settings = ObservedObject(wrappedValue: environment.settings)
        _viewModel = StateObject(wrappedValue: TimelineViewModel(environment: environment))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.reminders.isEmpty {
                    EmptyStateView(
                        systemImage: viewModel.filter.iconName,
                        title: emptyStateTitle,
                        message: emptyStateMessage
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(viewModel.reminders) { reminder in
                            ReminderRowView(reminder: reminder)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    onEditReminder(reminder)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        viewModel.delete(reminder)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                    Button {
                                        viewModel.complete(reminder)
                                    } label: {
                                        Label("Complete", systemImage: "checkmark.circle")
                                    }
                                    .tint(.green)
                                }
                                .contextMenu {
                                    Button("Complete", systemImage: "checkmark.circle") {
                                        viewModel.complete(reminder)
                                    }
                                    Button(snoozeLabel, systemImage: "zzz") {
                                        viewModel.snooze(reminder, minutes: settings.defaultSnoozeMinutes)
                                    }
                                    Button(postponeLabel, systemImage: "clock.arrow.circlepath") {
                                        viewModel.postpone(reminder, minutes: settings.defaultPostponeMinutes)
                                    }
                                    Button("Archive", systemImage: "archivebox") {
                                        viewModel.archive(reminder)
                                    }
                                    Divider()
                                    Button("Delete", systemImage: "trash", role: .destructive) {
                                        viewModel.delete(reminder)
                                    }
                                }
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(.compact)
            .scrollDismissesKeyboard(.interactively)
            .refreshable {
                viewModel.refresh(force: true)
            }
            .navigationTitle("Timeline")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showTriggers = true }) {
                        Image(systemName: "bolt.fill")
                    }
                    .tint(accentColor)
                    .accessibilityLabel("Triggers")
                }

                ToolbarItem(placement: .principal) {
                    Button {
                        showFilterSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: viewModel.filter.iconName)
                                .font(.subheadline)
                            Text(viewModel.filter.title)
                                .font(.headline)
                            if viewModel.reminders.count > 0 {
                                Text("(\(viewModel.reminders.count))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                        .foregroundColor(.primary)
                    }
                    .buttonStyle(.glass)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Menu {
                            Section("Quick Actions") {
                                Button(action: { viewModel.refresh(force: true) }) {
                                    Label("Refresh", systemImage: "arrow.clockwise")
                                }
                                .tint(accentColor)
                            }

                            Section("Filter Options") {
                                Button(action: {
                                    withAnimation {
                                        viewModel.toggleShowCompleted()
                                    }
                                }) {
                                    Label(
                                        viewModel.showCompleted ? "Hide Completed" : "Show Completed",
                                        systemImage: viewModel.showCompleted ? "eye.slash" : "eye"
                                    )
                                }
                                .tint(accentColor)
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .tint(accentColor)

                        Button(action: onCreateReminder) {
                            Image(systemName: "plus")
                        }
                        .tint(accentColor)
                        .accessibilityLabel("Create Reminder")
                    }
                }
            }
        }
        .sheet(isPresented: $showTriggers) {
            TriggersView(environment: environment,
                         onEditReminder: onEditReminder)
        }
        .sheet(isPresented: $showFilterSheet) {
            NavigationStack {
                List {
                    Section("Time") {
                        filterButton(.today)
                        filterButton(.overdue)
                        filterButton(.thisWeek)
                        filterButton(.upcoming)
                    }

                    Section("Organization") {
                        filterButton(.byPriority)
                        filterButton(.byTriggerType)
                    }

                    Section("Special") {
                        filterButton(.recurring)
                        filterButton(.noTriggers)
                    }

                    Section {
                        filterButton(.all)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .navigationTitle("Filters")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
                            showFilterSheet = false
                        }
                    }
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(.glass)
            .presentationCornerRadius(32)
        }
        .alert("Something went wrong", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { _ in viewModel.dismissError() }
        ), actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            Text(viewModel.errorMessage ?? "")
        })
        .onAppear {
            viewModel.refresh(force: false)
        }
    }

    private var filterPicker: some View {
        Picker("Filter", selection: $viewModel.filter) {
            ForEach(ReminderService.TimelineFilter.allCases, id: \.self) { filter in
                Text(filter.title)
                    .tag(filter)
            }
        }
    }

    private var emptyStateTitle: String {
        switch viewModel.filter {
        case .all:
            return "No Reminders Yet"
        case .overdue:
            return "All Clear!"
        case .today:
            return "Nothing for Today"
        case .upcoming:
            return "No Upcoming Reminders"
        case .thisWeek:
            return "Free Week Ahead"
        case .byPriority:
            return "No Prioritized Items"
        case .byTriggerType:
            return "No Reminders"
        case .recurring:
            return "No Recurring Reminders"
        case .noTriggers:
            return "All Reminders Have Triggers"
        }
    }

    private var emptyStateMessage: String {
        switch viewModel.filter {
        case .all:
            return "Create a reminder to get started."
        case .overdue:
            return "You're all caught up! No overdue reminders."
        case .today:
            return "You have no reminders scheduled for today."
        case .upcoming:
            return "No reminders scheduled for the future."
        case .thisWeek:
            return "You have no reminders for this week."
        case .byPriority:
            return "Create reminders with different priorities."
        case .byTriggerType:
            return "Create reminders to see them organized by type."
        case .recurring:
            return "No reminders are set to repeat."
        case .noTriggers:
            return "All your reminders have active triggers."
        }
    }

    private var snoozeLabel: String {
        formattedDuration(prefix: "Snooze", minutes: settings.defaultSnoozeMinutes)
    }

    private var postponeLabel: String {
        formattedDuration(prefix: "Postpone", minutes: settings.defaultPostponeMinutes)
    }

    private func formattedDuration(prefix: String, minutes: Int) -> String {
        guard minutes >= 60, minutes % 60 == 0 else {
            return "\(prefix) \(minutes) min"
        }
        let hours = minutes / 60
        return "\(prefix) \(hours) hour" + (hours == 1 ? "" : "s")
    }

    @ViewBuilder
    private func filterButton(_ filter: ReminderService.TimelineFilter) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.filter = filter
            }
            showFilterSheet = false
        }) {
            HStack {
                Label(filter.title, systemImage: filter.iconName)
                Spacer()
                let count = viewModel.count(for: filter)
                if count > 0 {
                    Text("\(count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if viewModel.filter == filter {
                    Image(systemName: "checkmark")
                        .foregroundColor(accentColor)
                }
            }
        }
    }
}

private extension ReminderService.TimelineFilter {
    var title: String {
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

    var iconName: String {
        switch self {
        case .all: return "list.bullet"
        case .overdue: return "exclamationmark.triangle"
        case .today: return "calendar"
        case .upcoming: return "calendar.badge.clock"
        case .thisWeek: return "calendar.day.timeline.leading"
        case .byPriority: return "exclamationmark.3"
        case .byTriggerType: return "tag"
        case .recurring: return "arrow.clockwise"
        case .noTriggers: return "bell.slash"
        }
    }
}

#Preview {
    let environment = AppEnvironment(persistence: PersistenceController.preview)
    environment.bootstrap()
    return TimelineView(environment: environment, onCreateReminder: {}, onEditReminder: { _ in })
        .environmentObject(environment)
}
