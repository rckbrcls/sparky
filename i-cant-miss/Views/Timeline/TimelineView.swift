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
            List {
                Section {
                    filterPicker
                        .pickerStyle(.segmented)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 2, trailing: 0))
                        .listRowBackground(Color(.systemGroupedBackground))
                        .listRowSeparator(.hidden)
                }

                if viewModel.reminders.isEmpty {
                    EmptyStateView(systemImage: "bell.slash",
                                   title: "Stay on top of things",
                                   message: "Create a reminder to populate your timeline.")
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(Array(viewModel.reminders.enumerated()), id: \.element.id) { index, reminder in
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: onCreateReminder) {
                        Image(systemName: "plus")
                    }
                    .tint(.accentColor)
                    .accessibilityLabel("Create Reminder")
                }
            }
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
}

private extension ReminderService.TimelineFilter {
    var title: String {
        switch self {
        case .all: return "All"
        case .overdue: return "Overdue"
        case .today: return "Today"
        case .upcoming: return "Upcoming"
        }
    }
}

#Preview {
    let environment = AppEnvironment(persistence: PersistenceController.preview)
    environment.bootstrap()
    return TimelineView(environment: environment, onCreateReminder: {}, onEditReminder: { _ in })
        .environmentObject(environment)
}
