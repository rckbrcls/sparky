//
//  TodoEditorViewModel.swift
//  i-cant-miss
//
//  Created by Codex on 13/10/25.
//

import Foundation
import Combine

@MainActor
final class TodoEditorViewModel: ObservableObject {
    struct EditableItem: Identifiable, Hashable {
        let id: UUID
        var title: String
        var detail: String
        var isCompleted: Bool
        var createdAt: Date
        var completedAt: Date?
    }

    @Published var title: String = ""
    @Published var notes: String = ""
    @Published var dueDate: Date?
    @Published var isPinned: Bool = false
    @Published var isArchived: Bool = false
    @Published var items: [EditableItem] = []
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?
    @Published var selectedFolderID: UUID?

    private let environment: AppEnvironment
    private let existingListID: UUID?

    init(environment: AppEnvironment, list: TodoListModel?) {
        self.environment = environment
        self.existingListID = list?.id

        if let listID = list?.id,
           let freshList = environment.todoService.fetchListWithItems(id: listID) {
            apply(list: freshList)
        } else if let list {
            apply(list: list)
        } else {
            // Start with a single empty item to encourage quick entry
            items = [EditableItem(id: UUID(),
                                  title: "",
                                  detail: "",
                                  isCompleted: false,
                                  createdAt: Date(),
                                  completedAt: nil)]
            selectedFolderID = list?.folder?.id
        }
    }

    var isNewList: Bool {
        existingListID == nil
    }

    func loadData() {
        guard let listID = existingListID,
              let refreshed = environment.todoService.fetchListWithItems(id: listID) else {
            return
        }
        apply(list: refreshed)
    }

    func addItem() {
        items.append(EditableItem(id: UUID(),
                                  title: "",
                                  detail: "",
                                  isCompleted: false,
                                  createdAt: Date(),
                                  completedAt: nil))
    }

    func removeItems(at offsets: IndexSet) {
        let sortedOffsets = offsets.sorted(by: >)
        for index in sortedOffsets where items.indices.contains(index) {
            items.remove(at: index)
        }
        if items.isEmpty {
            addItem()
        }
    }

    func moveItems(from source: IndexSet, to destination: Int) {
        var workingItems = items
        let sortedSource = source.sorted(by: >)
        var extracted: [EditableItem] = []

        for index in sortedSource {
            guard workingItems.indices.contains(index) else { continue }
            extracted.insert(workingItems.remove(at: index), at: 0)
        }

        let adjustedDestination = max(0, min(destination - source.filter { $0 < destination }.count, workingItems.count))
        workingItems.insert(contentsOf: extracted, at: adjustedDestination)
        items = workingItems
    }

    func toggleCompletion(for itemID: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == itemID }) else { return }
        items[idx].isCompleted.toggle()
        items[idx].completedAt = items[idx].isCompleted ? (items[idx].completedAt ?? Date()) : nil
    }

    func save() async -> Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            errorMessage = "Todo title cannot be empty."
            return false
        }

        let preparedItems = sanitizedItems()
        guard !preparedItems.isEmpty else {
            errorMessage = "Add at least one item with a title."
            return false
        }

        isSaving = true
        defer { isSaving = false }

        do {
            if let listID = existingListID,
               var existing = environment.todoService.fetchListWithItems(id: listID) {
                existing.title = trimmedTitle
                existing.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                existing.dueDate = dueDate
                existing.isPinned = isPinned
                existing.isArchived = isArchived
                existing.updatedAt = Date()
                existing.folder = environment.folderService.folders(for: .todos).first(where: { $0.id == selectedFolderID })
                existing.items = preparedItems.enumerated().map { index, item in
                    var updated = item
                    updated.sortOrder = index
                    return updated
                }
                _ = try await environment.todoService.updateList(existing)
            } else {
                let orderedItems = preparedItems.enumerated().map { index, item -> TodoItemModel in
                    var model = item
                    model.sortOrder = index
                    return model
                }

                _ = try await environment.todoService.createList(
                    title: trimmedTitle,
                    notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    dueDate: dueDate,
                    isPinned: isPinned,
                    folderID: selectedFolderID,
                    items: orderedItems
                )
            }

            _ = await environment.todoService.refresh(force: true)
            return true
        } catch TodoService.TodoServiceError.validationFailed(let message) {
            errorMessage = message
            return false
        } catch {
            errorMessage = "Unable to save todo list."
            return false
        }
    }

    private func sanitizedItems() -> [TodoItemModel] {
        items.enumerated().compactMap { index, editable in
            let trimmedTitle = editable.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedTitle.isEmpty else { return nil }

            return TodoItemModel(
                id: editable.id,
                title: trimmedTitle,
                detail: editable.detail.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                isCompleted: editable.isCompleted,
                sortOrder: index,
                createdAt: editable.createdAt,
                completedAt: editable.isCompleted ? (editable.completedAt ?? Date()) : nil
            )
        }
    }

    private func apply(list: TodoListModel) {
        title = list.title
        notes = list.notes ?? ""
        dueDate = list.dueDate
        isPinned = list.isPinned
        isArchived = list.isArchived
        selectedFolderID = list.folder?.id
        items = list.items.sorted(by: { $0.sortOrder < $1.sortOrder }).map {
            EditableItem(id: $0.id,
                         title: $0.title,
                         detail: $0.detail ?? "",
                         isCompleted: $0.isCompleted,
                         createdAt: $0.createdAt,
                         completedAt: $0.completedAt)
        }

        if items.isEmpty {
            addItem()
        }
    }
}
