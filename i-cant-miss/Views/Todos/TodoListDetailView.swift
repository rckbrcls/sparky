//
//  TodoListDetailView.swift
//  i-cant-miss
//
//  Created by Codex on 13/10/25.
//

import SwiftUI

struct TodoListDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: TodoListDetailViewModel
    private let initialList: TodoListModel
    let environment: AppEnvironment
    let onEditList: (TodoListModel) -> Void

    @State private var showingAddItemSheet = false
    @State private var newItemTitle = ""
    @State private var newItemDetail = ""

    init(environment: AppEnvironment,
         list: TodoListModel,
         onEditList: @escaping (TodoListModel) -> Void) {
        self.environment = environment
        self.initialList = list
        self.onEditList = onEditList
        _viewModel = StateObject(wrappedValue: TodoListDetailViewModel(environment: environment, listID: list.id))
    }

    var body: some View {
        let list = viewModel.list ?? initialList
        let items = list.items.sorted { $0.sortOrder < $1.sortOrder }

        List {
            summarySection(for: list)

            Section("Items") {
                if items.isEmpty {
                    Label("No items yet", systemImage: "rectangle.and.pencil.and.ellipsis")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(items) { item in
                        TodoItemRowView(
                            item: item,
                            onToggle: { viewModel.toggleCompletion(for: item) }
                        )
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                viewModel.delete(item)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .onMove { source, destination in
                        viewModel.moveItems(from: source, to: destination)
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            guard index < items.count else { continue }
                            viewModel.delete(items[index])
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(list.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if !items.isEmpty {
                    EditButton()
                }
            }

            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    let latest = viewModel.list ?? initialList
                    onEditList(latest)
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .accessibilityLabel("Edit list")

                Button {
                    showingAddItemSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add item")
            }
        }
        .refreshable {
            viewModel.refresh()
        }
        .sheet(isPresented: $showingAddItemSheet) {
            addItemSheet
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

    private func summarySection(for list: TodoListModel) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                ProgressView(value: list.completionRate, total: 1.0) {
                    Text("Progress")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } currentValueLabel: {
                    Text("\(Int(round(list.completionRate * 100)))% complete")
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                if let notes = list.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notes")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(notes)
                            .font(.body)
                    }
                }

                if let dueDate = list.dueDate {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Due")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(dueDate, format: Date.FormatStyle(date: .abbreviated, time: .omitted))
                            .font(.body)
                            .foregroundStyle(dueDateColor(for: dueDate))
                    }
                }

                if let folder = list.folder {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Folder")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 6) {
                            Image(systemName: folder.iconName ?? "folder.fill")
                                .foregroundStyle(Color(hex: folder.colorHex ?? "#6366F1") ?? .accentColor)
                            Text(folder.name)
                                .font(.body)
                        }
                    }
                }

                HStack(spacing: 12) {
                    if list.isPinned {
                        Label("Pinned", systemImage: "pin.fill")
                            .font(.footnote)
                            .foregroundStyle(Color("AccentColor"))
                    }

                    if list.isArchived {
                        Label("Archived", systemImage: "archivebox")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if list.pendingItemCount > 0 {
                        Label("\(list.pendingItemCount) remaining", systemImage: "circlebadge")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else if !list.items.isEmpty {
                        Label("All items complete", systemImage: "checkmark.circle")
                            .font(.footnote)
                            .foregroundStyle(.green)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var addItemSheet: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("Title", text: $newItemTitle)
                        .textInputAutocapitalization(.sentences)
                    TextField("Details (optional)", text: $newItemDetail, axis: .vertical)
                        .lineLimit(1...4)
                }
            }
            .navigationTitle("New Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        resetNewItemInputs()
                        showingAddItemSheet = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        viewModel.addQuickItem(title: newItemTitle, detail: newItemDetail)
                        resetNewItemInputs()
                        showingAddItemSheet = false
                    }
                    .disabled(newItemTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func resetNewItemInputs() {
        newItemTitle = ""
        newItemDetail = ""
    }

    private func dueDateColor(for date: Date) -> Color {
        if date < Date() {
            return .red
        }
        if date < Date().addingTimeInterval(86400 * 2) {
            return .orange
        }
        return .primary
    }
}

#Preview {
    let environment = AppEnvironment(persistence: PersistenceController.preview)
    environment.bootstrap()
    let sampleList = environment.todoService.lists.first ?? TodoListModel(
        id: UUID(),
        title: "Sample List",
        notes: "Example notes go here.",
        dueDate: Date(),
        isPinned: true,
        isArchived: false,
        createdAt: Date(),
        updatedAt: Date(),
        userOrder: 0,
        items: []
    )

    return NavigationStack {
        TodoListDetailView(environment: environment, list: sampleList) { _ in }
    }
}
