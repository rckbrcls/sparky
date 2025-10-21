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

    private static let defaultFolderColorHex = "#6366F1"
    private static let defaultFolderIconName = "folder.fill"

    @State private var showingCreateFolder = false
    @State private var newFolderName = ""
    @State private var newFolderIcon = Self.defaultFolderIconName
    @State private var newFolderColor = Self.defaultFolderColorHex
    @State private var editingFolder: FolderModel?
    @State private var editFolderName = ""
    @State private var editFolderIcon = Self.defaultFolderIconName
    @State private var editFolderColor = Self.defaultFolderColorHex

    private let accentColor = Color("AccentColor")
    private let gridColumns = Array(repeating: GridItem(.flexible()), count: 4)
    private let folderIcons = [
        "folder.fill",
        "folder.badge.person.crop",
        "briefcase.fill",
        "house.fill",
        "heart.fill",
        "star.fill",
        "flag.fill",
        "book.fill",
        "lightbulb.fill",
        "cart.fill"
    ]
    private let iconDisplayNames: [String: String] = [
        "folder.fill": "Folder",
        "folder.badge.person.crop": "Shared Folder",
        "briefcase.fill": "Briefcase",
        "house.fill": "House",
        "heart.fill": "Heart",
        "star.fill": "Star",
        "flag.fill": "Flag",
        "book.fill": "Book",
        "lightbulb.fill": "Idea",
        "cart.fill": "Shopping"
    ]

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
            List {
                NavigationLink {
                    AllTodoListsView(
                        environment: environment,
                        viewModel: viewModel,
                        onCreateList: onCreateList,
                        onEditList: onEditList
                    )
                } label: {
                    allTodosRow
                }

                ForEach(viewModel.folders) { folder in
                    NavigationLink {
                        FolderTodoListsView(
                            environment: environment,
                            viewModel: viewModel,
                            folder: folder,
                            onCreateList: onCreateList,
                            onEditList: onEditList
                        )
                    } label: {
                        folderRow(for: folder)
                    }
                    .contextMenu {
                        Button {
                            prepareFolderEditing(with: folder)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            viewModel.deleteFolder(folder)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button {
                            prepareFolderEditing(with: folder)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(accentColor)

                        Button(role: .destructive) {
                            viewModel.deleteFolder(folder)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("To-dos")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        resetNewFolderInputs()
                        showingCreateFolder = true
                    } label: {
                        Image(systemName: "folder.badge.plus")
                    }
                    .tint(accentColor)
                    .accessibilityLabel("Create Folder")
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: onCreateList) {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.glassProminent)
                    .tint(accentColor)
                    .accessibilityLabel("Create To-do List")
                }
            }
        }
        .sheet(isPresented: $showingCreateFolder) {
            createFolderSheet
        }
        .sheet(item: $editingFolder) { folder in
            editFolderSheet(for: folder)
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
}

private extension TodosView {
    var allTodosRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "square.grid.2x2.fill")
                .font(.title2)
                .frame(width: 32)
                .foregroundStyle(accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("All To-dos")
                    .font(.headline)
                Text("\(viewModel.allLists.count) list\(viewModel.allLists.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    func folderRow(for folder: FolderModel) -> some View {
        let lists = viewModel.lists(in: folder)
        let iconColor = Color(hex: folder.colorHex ?? Self.defaultFolderColorHex) ?? accentColor

        return HStack(spacing: 12) {
            Image(systemName: folder.iconName ?? Self.defaultFolderIconName)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(folder.name)
                    .font(.headline)
                Text("\(lists.count) list\(lists.count == 1 ? "" : "s")")
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

    var createFolderSheet: some View {
        NavigationStack {
            Form {
                Section("Folder Details") {
                    TextField("Folder Name", text: $newFolderName)
                }

                Section("Icon") {
                    iconSelectionGrid(selection: $newFolderIcon)
                }

                Section("Color") {
                    colorSelectionGrid(selectedHex: $newFolderColor)
                }
            }
            .navigationTitle("New Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        resetNewFolderInputs()
                        showingCreateFolder = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let trimmedName = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmedName.isEmpty else { return }
                        viewModel.createFolder(
                            name: trimmedName,
                            colorHex: newFolderColor,
                            iconName: newFolderIcon
                        )
                        resetNewFolderInputs()
                        showingCreateFolder = false
                    }
                    .disabled(newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    func editFolderSheet(for folder: FolderModel) -> some View {
        NavigationStack {
            Form {
                Section("Folder Details") {
                    TextField("Folder Name", text: $editFolderName)
                }

                Section("Icon") {
                    iconSelectionGrid(selection: $editFolderIcon)
                }

                Section("Color") {
                    colorSelectionGrid(selectedHex: $editFolderColor)
                }
            }
            .navigationTitle("Edit Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        resetEditFolderForm()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let editingFolder {
                            let trimmedName = editFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmedName.isEmpty else { return }
                            viewModel.updateFolder(
                                editingFolder,
                                name: trimmedName,
                                colorHex: editFolderColor,
                                iconName: editFolderIcon
                            )
                        }
                        resetEditFolderForm()
                    }
                    .disabled(editFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    func iconSelectionGrid(selection: Binding<String>) -> some View {
        LazyVGrid(columns: gridColumns, spacing: 12) {
            ForEach(folderIcons, id: \.self) { icon in
                Button {
                    selection.wrappedValue = icon
                } label: {
                    ZStack {
                        Circle()
                            .fill(selection.wrappedValue == icon ? accentColor.opacity(0.18) : Color(.systemGray6))
                            .frame(width: 50, height: 50)

                        Image(systemName: icon)
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(selection.wrappedValue == icon ? accentColor : Color.primary)
                    }
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(iconAccessibilityLabel(for: icon)))
            }
        }
        .padding(.vertical, 8)
    }

    func colorSelectionGrid(selectedHex: Binding<String>) -> some View {
        LazyVGrid(columns: gridColumns, spacing: 12) {
            ForEach(Color.PresetColors.all) { presetColor in
                Button {
                    selectedHex.wrappedValue = presetColor.hex
                } label: {
                    ZStack {
                        Circle()
                            .fill(presetColor.color)
                            .frame(width: 50, height: 50)

                        if selectedHex.wrappedValue == presetColor.hex {
                            Circle()
                                .strokeBorder(.white, lineWidth: 3)
                                .frame(width: 50, height: 50)
                                .shadow(radius: 2)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
    }

    func prepareFolderEditing(with folder: FolderModel) {
        editFolderName = folder.name
        let icon = folder.iconName ?? Self.defaultFolderIconName
        editFolderIcon = folderIcons.contains(icon) ? icon : Self.defaultFolderIconName
        editFolderColor = folder.colorHex ?? Self.defaultFolderColorHex
        editingFolder = folder
    }

    func resetNewFolderInputs() {
        newFolderName = ""
        newFolderIcon = Self.defaultFolderIconName
        newFolderColor = Self.defaultFolderColorHex
    }

    func resetEditFolderForm() {
        editingFolder = nil
        editFolderName = ""
        editFolderIcon = Self.defaultFolderIconName
        editFolderColor = Self.defaultFolderColorHex
    }

    func iconAccessibilityLabel(for icon: String) -> String {
        iconDisplayNames[icon] ?? icon.replacingOccurrences(of: ".", with: " ")
    }
}

// MARK: - All Todo Lists View
struct AllTodoListsView: View {
    let environment: AppEnvironment
    @ObservedObject var viewModel: TodosViewModel
    let onCreateList: () -> Void
    let onEditList: (TodoListModel) -> Void
    private let accentColor = Color("AccentColor")

    var body: some View {
        Group {
            if viewModel.pinnedLists.isEmpty &&
                viewModel.regularLists.isEmpty &&
                (!viewModel.showArchived || viewModel.archivedLists.isEmpty) {
                ScrollView {
                    EmptyStateView(
                        systemImage: "checklist",
                        title: "No To-do Lists",
                        message: "Create a list to keep your tasks organized."
                    )
                    .frame(maxWidth: .infinity)
                }
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
        .navigationTitle("All To-dos")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Menu {
                    Toggle("Show archived", isOn: $viewModel.showArchived)
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
                .tint(accentColor)
                .accessibilityLabel("Filter to-dos")
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: onCreateList) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.glassProminent)
                .tint(accentColor)
                .accessibilityLabel("Create To-do List")
            }
        }
        .refreshable {
            viewModel.refresh(force: true)
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
            .tint(accentColor)
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

    private func detailView(for list: TodoListModel) -> some View {
        TodoListDetailView(environment: environment,
                           list: list,
                           onEditList: onEditList)
    }
}

// MARK: - Folder Todo Lists View
struct FolderTodoListsView: View {
    let environment: AppEnvironment
    @ObservedObject var viewModel: TodosViewModel
    let folder: FolderModel
    let onCreateList: () -> Void
    let onEditList: (TodoListModel) -> Void
    private let accentColor = Color("AccentColor")

    @State private var searchText = ""

    var filteredLists: [TodoListModel] {
        let baseLists = viewModel.lists(in: folder)
        guard !searchText.isEmpty else { return baseLists }
        let query = searchText.lowercased()
        return baseLists.filter { list in
            list.title.lowercased().contains(query) ||
            (list.notes?.lowercased().contains(query) ?? false)
        }
    }

    var body: some View {
        let pinned = viewModel.sortedLists(filteredLists.filter { !$0.isArchived && $0.isPinned })
        let regular = viewModel.sortedLists(filteredLists.filter { !$0.isArchived && !$0.isPinned })
        let archived = viewModel.sortedLists(filteredLists.filter(\.isArchived))

        Group {
            if pinned.isEmpty && regular.isEmpty && (!viewModel.showArchived || archived.isEmpty) {
                ScrollView {
                    EmptyStateView(
                        systemImage: "checkmark.rectangle",
                        title: "No Lists",
                        message: searchText.isEmpty ? "Create a list in this folder to get started." : "No lists match your search."
                    )
                    .frame(maxWidth: .infinity)
                }
            } else {
                List {
                    if !pinned.isEmpty {
                        Section("Pinned") {
                            ForEach(pinned) { list in
                                listRow(list)
                            }
                        }
                    }

                    Section(pinned.isEmpty ? "Lists" : "More Lists") {
                        ForEach(regular) { list in
                            listRow(list)
                        }
                    }

                    if viewModel.showArchived && !archived.isEmpty {
                        Section("Archived") {
                            ForEach(archived) { list in
                                archivedRow(list)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(folder.name)
        .searchable(text: $searchText)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Menu {
                    Toggle("Show archived", isOn: $viewModel.showArchived)
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
                .tint(accentColor)
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: onCreateList) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.glassProminent)
                .tint(accentColor)
                .accessibilityLabel("Create To-do List")
            }
        }
        .refreshable {
            viewModel.refresh(force: true)
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
            .tint(accentColor)
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
