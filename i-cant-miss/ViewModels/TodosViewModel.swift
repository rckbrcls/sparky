//
//  TodosViewModel.swift
//  i-cant-miss
//
//  Created by Codex on 13/10/25.
//

import Foundation
import Combine

@MainActor
final class TodosViewModel: ObservableObject {
    @Published private(set) var pinnedLists: [TodoListModel] = []
    @Published private(set) var regularLists: [TodoListModel] = []
    @Published private(set) var archivedLists: [TodoListModel] = []
    @Published private(set) var allLists: [TodoListModel] = []
    @Published private(set) var folders: [FolderModel] = []
    @Published var showArchived: Bool = false {
        didSet {
            updateSnapshot()
        }
    }
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let environment: AppEnvironment
    private var cancellables = Set<AnyCancellable>()

    init(environment: AppEnvironment) {
        self.environment = environment
        bind()
        updateSnapshot()
    }

    func refresh(force: Bool) {
        guard !environment.isBootstrapping, !isLoading else { return }

        Task {
            isLoading = true
            defer { isLoading = false }
            async let todosRefresh = environment.todoService.refresh(force: force)
            async let foldersRefresh = environment.folderService.refreshFolders(force: force)
            _ = await (todosRefresh, foldersRefresh)
        }
    }

    func list(with id: UUID) -> TodoListModel? {
        environment.todoService.list(with: id)
    }

    func delete(_ list: TodoListModel) {
        Task {
            do {
                try await environment.todoService.deleteList(id: list.id)
                _ = await environment.todoService.refresh(force: true)
            } catch {
                errorMessage = "Could not delete the todo list."
            }
        }
    }

    func togglePin(for list: TodoListModel) {
        Task {
            do {
                _ = try await environment.todoService.togglePin(listID: list.id)
                _ = await environment.todoService.refresh(force: true)
            } catch {
                errorMessage = "Could not update the pin status."
            }
        }
    }

    func archive(_ list: TodoListModel) {
        Task {
            do {
                _ = try await environment.todoService.setArchived(true, listID: list.id)
                _ = await environment.todoService.refresh(force: true)
            } catch {
                errorMessage = "Could not archive the todo list."
            }
        }
    }

    func restore(_ list: TodoListModel) {
        Task {
            do {
                _ = try await environment.todoService.setArchived(false, listID: list.id)
                _ = await environment.todoService.refresh(force: true)
            } catch {
                errorMessage = "Could not restore the todo list."
            }
        }
    }

    func dismissError() {
        errorMessage = nil
    }

    func lists(in folder: FolderModel) -> [TodoListModel] {
        allLists.filter { $0.folder?.id == folder.id }
    }

    func createFolder(
        name: String,
        colorHex: String,
        iconName: String,
        showInReminders: Bool,
        showInNotes: Bool,
        showInTodos: Bool
    ) {
        Task {
            _ = try? await environment.folderService.createFolder(
                name: name,
                colorHex: colorHex,
                iconName: iconName,
                isDefault: false,
                showInReminders: showInReminders,
                showInNotes: showInNotes,
                showInTodos: showInTodos
            )
            async let folders = environment.folderService.refreshFolders(force: true)
            async let todos = environment.todoService.refresh(force: true)
            _ = await (folders, todos)
        }
    }

    func updateFolder(
        _ folder: FolderModel,
        name: String,
        colorHex: String?,
        iconName: String?,
        showInReminders: Bool,
        showInNotes: Bool,
        showInTodos: Bool
    ) {
        Task {
            var updatedFolder = folder
            updatedFolder.name = name
            updatedFolder.colorHex = colorHex
            updatedFolder.iconName = iconName
            updatedFolder.showInReminders = showInReminders
            updatedFolder.showInNotes = showInNotes
            updatedFolder.showInTodos = showInTodos

            _ = try? await environment.folderService.updateFolder(updatedFolder)
            async let folders = environment.folderService.refreshFolders(force: true)
            async let todos = environment.todoService.refresh(force: true)
            _ = await (folders, todos)
        }
    }

    func deleteFolder(_ folder: FolderModel) {
        Task {
            _ = try? await environment.folderService.deleteFolder(id: folder.id)
            async let folders = environment.folderService.refreshFolders(force: true)
            async let todos = environment.todoService.refresh(force: true)
            _ = await (folders, todos)
        }
    }

    func pinnedLists(in folder: FolderModel) -> [TodoListModel] {
        sortLists(lists(in: folder).filter { !$0.isArchived && $0.isPinned })
    }

    func regularLists(in folder: FolderModel) -> [TodoListModel] {
        sortLists(lists(in: folder).filter { !$0.isArchived && !$0.isPinned })
    }

    func archivedLists(in folder: FolderModel) -> [TodoListModel] {
        sortLists(lists(in: folder).filter(\.isArchived))
    }

    func sortedLists(_ lists: [TodoListModel]) -> [TodoListModel] {
        sortLists(lists)
    }

    private func bind() {
        environment.todoService.$lists
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateSnapshot()
            }
            .store(in: &cancellables)

        environment.folderService.$folders
            .receive(on: RunLoop.main)
            .sink { [weak self] folders in
                self?.folders = folders.filter(\.showInTodos)
            }
            .store(in: &cancellables)

        folders = environment.folderService.folders(for: .todos)
    }

    private func updateSnapshot() {
        let lists = environment.todoService.lists
        allLists = lists
        pinnedLists = sortLists(lists.filter { !$0.isArchived && $0.isPinned })
        regularLists = sortLists(lists.filter { !$0.isArchived && !$0.isPinned })
        archivedLists = sortLists(lists.filter(\.isArchived))
    }

    private func sortLists(_ lists: [TodoListModel]) -> [TodoListModel] {
        lists.sorted { lhs, rhs in
            if let lhsDue = lhs.dueDate, let rhsDue = rhs.dueDate, lhsDue != rhsDue {
                return lhsDue < rhsDue
            }
            if lhs.dueDate != nil && rhs.dueDate == nil {
                return true
            }
            if lhs.dueDate == nil && rhs.dueDate != nil {
                return false
            }
            if lhs.completionRate != rhs.completionRate {
                return lhs.completionRate < rhs.completionRate
            }
            return lhs.updatedAt > rhs.updatedAt
        }
    }
}
