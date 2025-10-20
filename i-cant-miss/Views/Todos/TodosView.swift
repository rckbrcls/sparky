//
//  TodosView.swift
//  i-cant-miss
//
//  Created by Codex on 13/10/25.
//

import SwiftUI

struct TodosView: View {
    @StateObject private var viewModel: TodosViewModel
    let environment: AppEnvironment
    let onCreateList: () -> Void
    let onEditList: (TodoListModel) -> Void

    init(environment: AppEnvironment,
         onCreateList: @escaping () -> Void,
         onEditList: @escaping (TodoListModel) -> Void) {
        self.environment = environment
        self.onCreateList = onCreateList
        self.onEditList = onEditList
        _viewModel = StateObject(wrappedValue: TodosViewModel(environment: environment))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.pinnedLists.isEmpty &&
                    viewModel.regularLists.isEmpty &&
                    (!viewModel.showArchived || viewModel.archivedLists.isEmpty) {
                    EmptyStateView(
                        systemImage: "checklist",
                        title: "Stay on top of your tasks",
                        message: "Create to-do lists to group anything that should not slip through the cracks."
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
                } else {
                    List {
                        if !viewModel.pinnedLists.isEmpty {
                            Section("Pinned") {
                                ForEach(viewModel.pinnedLists) { list in
                                    listRow(list)
                                }
                            }
                        }

                        Section(viewModel.pinnedLists.isEmpty ? "Lists" : "More Lists") {
                            ForEach(viewModel.regularLists) { list in
                                listRow(list)
                            }
                        }

                        if viewModel.showArchived && !viewModel.archivedLists.isEmpty {
                            Section("Archived") {
                                ForEach(viewModel.archivedLists) { list in
                                    archivedRow(list)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("To-dos")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Toggle("Show archived", isOn: $viewModel.showArchived)
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                    .tint(Color("AccentColor"))
                    .accessibilityLabel("Filter to-dos")
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: onCreateList) {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.glassProminent)
                    .tint(Color("AccentColor"))
                    .accessibilityLabel("Create to-do list")
                }

                ToolbarItem(placement: .bottomBar) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                    }
                }
            }
            .refreshable {
                viewModel.refresh(force: true)
            }
        }
        .onAppear {
            viewModel.refresh(force: false)
        }
        .alert("Action failed",
               isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { _ in viewModel.dismissError() }
               )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private func listRow(_ list: TodoListModel) -> some View {
        NavigationLink(destination: detailView(for: list)) {
            TodoListRowView(
                list: list,
                onTogglePin: { viewModel.togglePin(for: list) }
            )
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                viewModel.delete(list)
            } label: {
                Label("Delete", systemImage: "trash")
            }

            Button {
                viewModel.archive(list)
            } label: {
                Label("Archive", systemImage: "archivebox")
            }
            .tint(.orange)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                viewModel.togglePin(for: list)
            } label: {
                Label(list.isPinned ? "Unpin" : "Pin", systemImage: list.isPinned ? "pin.slash" : "pin")
            }
            .tint(Color("AccentColor"))
        }
        .contextMenu {
            Button(list.isPinned ? "Unpin" : "Pin", systemImage: list.isPinned ? "pin.slash" : "pin") {
                viewModel.togglePin(for: list)
            }

            Button("Archive", systemImage: "archivebox") {
                viewModel.archive(list)
            }

            Divider()

            Button("Delete", systemImage: "trash", role: .destructive) {
                viewModel.delete(list)
            }
        }
    }

    private func archivedRow(_ list: TodoListModel) -> some View {
        NavigationLink(destination: detailView(for: list)) {
            TodoListRowView(
                list: list,
                onTogglePin: { viewModel.togglePin(for: list) }
            )
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button {
                viewModel.restore(list)
            } label: {
                Label("Restore", systemImage: "arrow.uturn.backward")
            }
            .tint(.green)

            Button(role: .destructive) {
                viewModel.delete(list)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .contextMenu {
            Button("Restore", systemImage: "arrow.uturn.backward") {
                viewModel.restore(list)
            }

            Divider()

            Button("Delete", systemImage: "trash", role: .destructive) {
                viewModel.delete(list)
            }
        }
    }

    @ViewBuilder
    private func detailView(for list: TodoListModel) -> some View {
        TodoListDetailView(environment: environment,
                           list: list,
                           onEditList: onEditList)
    }
}

#Preview {
    let environment = AppEnvironment(persistence: PersistenceController.preview)
    environment.bootstrap()
    return TodosView(environment: environment, onCreateList: {}, onEditList: { _ in })
}
