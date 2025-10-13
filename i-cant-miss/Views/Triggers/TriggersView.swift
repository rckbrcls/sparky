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
                if viewModel.triggerTypeFolders.isEmpty {
                    ScrollView {
                        EmptyStateView(systemImage: "bolt.slash",
                                       title: "No triggers yet",
                                       message: "Add triggers to your reminders to see them organized here.")
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    List {
                        ForEach(viewModel.triggerTypeFolders) { folder in
                            NavigationLink(destination: TriggerListView(
                                folder: folder,
                                onEditReminder: onEditReminder
                            )) {
                                HStack(spacing: 12) {
                                    Image(systemName: folder.type.systemImage)
                                        .font(.title2)
                                        .foregroundStyle(.blue)
                                        .frame(width: 32)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(folder.type.label)
                                            .font(.headline)
                                        Text("\(folder.count) trigger\(folder.count == 1 ? "" : "s")")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "folder.fill")
                                        .foregroundStyle(.secondary)
                                        .font(.title3)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Triggers")
        }
        .onAppear {
            viewModel.refresh()
        }
    }
}

// MARK: - Trigger List View
struct TriggerListView: View {
    let folder: TriggersViewModel.TriggerTypeFolder
    let onEditReminder: (ReminderModel) -> Void
    
    var body: some View {
        List {
            ForEach(folder.items) { display in
                TriggerRowView(display: display)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onEditReminder(display.reminder)
                    }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(folder.type.label)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    let environment = AppEnvironment(persistence: PersistenceController.preview)
    environment.bootstrap()
    return TriggersView(environment: environment, onEditReminder: { _ in })
}
