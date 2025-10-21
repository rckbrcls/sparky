//
//  TodoEditorView.swift
//  i-cant-miss
//
//  Created by Codex on 13/10/25.
//

import SwiftUI

struct TodoEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: TodoEditorViewModel
    let environment: AppEnvironment

    @State private var hasDueDate: Bool
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case title
        case notes
    }

    init(environment: AppEnvironment, existingList: TodoListModel?) {
        self.environment = environment
        _viewModel = StateObject(wrappedValue: TodoEditorViewModel(environment: environment, list: existingList))
        _hasDueDate = State(initialValue: existingList?.dueDate != nil)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Details") {
                    TextField("Title", text: $viewModel.title)
                        .textInputAutocapitalization(.words)
                        .focused($focusedField, equals: .title)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .notes
                        }

                    TextField("Notes (optional)", text: $viewModel.notes, axis: .vertical)
                        .lineLimit(2...6)
                        .focused($focusedField, equals: .notes)
                        .submitLabel(.done)
                }

                Section("Schedule") {
                    Toggle("Set due date", isOn: $hasDueDate)
                        .onChange(of: hasDueDate) { _, newValue in
                            if newValue {
                                viewModel.dueDate = viewModel.dueDate ?? Calendar.current.startOfDay(for: Date())
                            } else {
                                viewModel.dueDate = nil
                            }
                        }

                    if hasDueDate {
                        DatePicker(
                            "Due date",
                            selection: Binding<Date>(
                                get: {
                                    viewModel.dueDate ?? Calendar.current.startOfDay(for: Date())
                                },
                                set: { newValue in
                                    viewModel.dueDate = newValue
                                }
                            ),
                            displayedComponents: .date
                        )
                    }
                }

                Section("Options") {
                    Toggle("Pin list", isOn: $viewModel.isPinned)
                    if !viewModel.isNewList {
                        Toggle("Mark as archived", isOn: $viewModel.isArchived)
                    }

                    Picker("Folder", selection: $viewModel.selectedFolderID) {
                        Text("No folder").tag(UUID?.none)
                        ForEach(todoFolders, id: \.id) { folder in
                            Text(folder.name).tag(Optional(folder.id))
                        }
                    }
                }

                Section("Items") {
                    if viewModel.items.isEmpty {
                        Text("Add items to track progress on this to-do list.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach($viewModel.items) { $item in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .center) {
                                    TextField("Item title", text: $item.title)
                                        .textInputAutocapitalization(.sentences)
                                        .font(.body)

                                    Toggle(isOn: Binding(
                                        get: { item.isCompleted },
                                        set: { newValue in
                                            item.isCompleted = newValue
                                            item.completedAt = newValue ? (item.completedAt ?? Date()) : nil
                                        }
                                    )) {
                                        Text("")
                                    }
                                    .labelsHidden()
                                    .toggleStyle(.switch)
                                }

                                TextField("Details (optional)", text: $item.detail, axis: .vertical)
                                    .lineLimit(1...3)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .onDelete(perform: viewModel.removeItems)
                        .onMove(perform: viewModel.moveItems)
                    }

                    Button {
                        withAnimation {
                            viewModel.addItem()
                        }
                    } label: {
                        Label("Add item", systemImage: "plus.circle")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(viewModel.isNewList ? "New To-do" : "Edit To-do")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", role: .cancel) {
                        dismiss()
                    }
                }

                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if !viewModel.items.isEmpty {
                        EditButton()
                    }

                    Button {
                        Task {
                            let success = await viewModel.save()
                            if success { dismiss() }
                        }
                    } label: {
                        if viewModel.isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
            .alert("Cannot save",
                   isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { _ in viewModel.errorMessage = nil }
                   )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
        .onAppear {
            viewModel.loadData()
            hasDueDate = viewModel.dueDate != nil
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private var todoFolders: [FolderModel] {
        var folders = environment.folderService.folders(for: .todos)

        if let selectedID = viewModel.selectedFolderID,
           let selected = environment.folderService.folders.first(where: { $0.id == selectedID }),
           !folders.contains(where: { $0.id == selected.id }) {
            folders.append(selected)
            folders.sort { $0.sortOrder < $1.sortOrder }
        }

        return folders
    }
}

#Preview {
    let environment = AppEnvironment(persistence: PersistenceController.preview)
    environment.bootstrap()
    return TodoEditorView(environment: environment, existingList: environment.todoService.lists.first)
}
