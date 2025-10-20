//
//  TodoListDetailViewModel.swift
//  i-cant-miss
//
//  Created by Codex on 13/10/25.
//

import Foundation
import Combine

@MainActor
final class TodoListDetailViewModel: ObservableObject {
    @Published private(set) var list: TodoListModel?
    @Published private(set) var isPerformingAction = false
    @Published var errorMessage: String?

    private let environment: AppEnvironment
    private let listID: UUID
    private var cancellables = Set<AnyCancellable>()

    init(environment: AppEnvironment, listID: UUID) {
        self.environment = environment
        self.listID = listID
        bind()
        updateSnapshot()
    }

    func refresh() {
        Task {
            _ = await environment.todoService.refresh(force: true)
        }
    }

    func toggleCompletion(for item: TodoItemModel) {
        Task {
            do {
                try await environment.todoService.toggleItemCompletion(listID: listID, itemID: item.id)
                _ = await environment.todoService.refresh(force: true)
            } catch {
                errorMessage = "Could not update the item."
            }
        }
    }

    func delete(_ item: TodoItemModel) {
        Task {
            do {
                try await environment.todoService.deleteItem(listID: listID, itemID: item.id)
                _ = await environment.todoService.refresh(force: true)
            } catch {
                errorMessage = "Could not delete the item."
            }
        }
    }

    func addQuickItem(title: String, detail: String?) {
        Task {
            do {
                _ = try await environment.todoService.addQuickItem(to: listID, title: title, detail: detail)
                _ = await environment.todoService.refresh(force: true)
            } catch TodoService.TodoServiceError.validationFailed(let message) {
                errorMessage = message
            } catch {
                errorMessage = "Could not add the item."
            }
        }
    }

    func moveItems(from source: IndexSet, to destination: Int) {
        Task {
            do {
                try await environment.todoService.moveItems(listID: listID, fromOffsets: source, toOffset: destination)
                _ = await environment.todoService.refresh(force: true)
            } catch {
                errorMessage = "Could not reorder the items."
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
        list = environment.todoService.list(with: listID)
    }
}
