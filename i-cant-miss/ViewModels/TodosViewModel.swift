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
            _ = await environment.todoService.refresh(force: force)
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

    private func bind() {
        environment.todoService.$lists
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateSnapshot()
            }
            .store(in: &cancellables)
    }

    private func updateSnapshot() {
        let lists = environment.todoService.lists
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
