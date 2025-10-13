//
//  TriggersView.swift
//  i-cant-miss
//
//  Created by Codex on 13/10/25.
//

import SwiftUI

struct TriggersView: View {
    @StateObject private var viewModel: TriggersViewModel
    let environment: AppEnvironment
    let onEditReminder: (ReminderModel) -> Void

    init(environment: AppEnvironment,
         onEditReminder: @escaping (ReminderModel) -> Void) {
        self.environment = environment
        self.onEditReminder = onEditReminder
        _viewModel = StateObject(wrappedValue: TriggersViewModel(environment: environment))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.groups.isEmpty {
                    ScrollView {
                        EmptyStateView(systemImage: "bolt.slash",
                                       title: "No triggers yet",
                                       message: "Add triggers to your reminders to see them organized here.")
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    List {
                        ForEach(viewModel.groups) { group in
                            Section(group.id.label) {
                                ForEach(group.items) { display in
                                    TriggerRowView(display: display)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            onEditReminder(display.reminder)
                                        }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Triggers")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("All Triggers") {
                            viewModel.selectedType = nil
                        }
                        Divider()
                        ForEach(ReminderTriggerType.allCases) { type in
                            Button(type.label) {
                                viewModel.selectedType = type
                            }
                        }
                    } label: {
                        Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
            }
        }
        .onAppear {
            viewModel.refresh()
        }
    }
}

#Preview {
    let environment = AppEnvironment(persistence: PersistenceController.preview)
    environment.bootstrap()
    return TriggersView(environment: environment, onEditReminder: { _ in })
}
