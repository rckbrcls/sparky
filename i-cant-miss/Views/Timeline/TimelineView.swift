//
//  TimelineView.swift
//  i-cant-miss
//
//  Created by Codex on 13/10/25.
//

import SwiftUI

struct TimelineView: View {
    @StateObject private var viewModel: TimelineViewModel
    let environment: AppEnvironment
    let onCreateReminder: () -> Void
    let onEditReminder: (ReminderModel) -> Void

    init(environment: AppEnvironment,
         onCreateReminder: @escaping () -> Void,
         onEditReminder: @escaping (ReminderModel) -> Void) {
        self.environment = environment
        self.onCreateReminder = onCreateReminder
        self.onEditReminder = onEditReminder
        _viewModel = StateObject(wrappedValue: TimelineViewModel(environment: environment))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    filterPicker
                        .pickerStyle(.segmented)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 4, trailing: 0))
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
                            .contextMenu {
                                Button("Complete", systemImage: "checkmark.circle") {
                                    viewModel.complete(reminder)
                                }
                                Button("Snooze 15 min", systemImage: "zzz") {
                                    viewModel.snooze(reminder, minutes: 15)
                                }
                                Button("Postpone 1 hr", systemImage: "clock.arrow.circlepath") {
                                    viewModel.postpone(reminder, hours: 1)
                                }
                                Button("Archive", systemImage: "archivebox") {
                                    viewModel.archive(reminder)
                                }
                            }
                            .listRowSeparator(index == viewModel.reminders.count - 1 ? .hidden : .visible, edges: .bottom)
                            .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
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
                        Image(systemName: "plus.circle.fill")
                    }
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
