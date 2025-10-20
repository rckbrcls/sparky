//
//  TodoService.swift
//  i-cant-miss
//
//  Created by Codex on 13/10/25.
//

import Foundation
import Combine
@preconcurrency import CoreData
import os.log

@MainActor
final class TodoService: ObservableObject {
    enum TodoServiceError: Error {
        case listNotFound
        case itemNotFound
        case validationFailed(String)
    }

    @Published private(set) var lists: [TodoListModel] = []
    @Published private(set) var lastRefreshed: Date?

    private let persistence: PersistenceController
    private var refreshTimer: AnyCancellable?
    private let cacheTTL: TimeInterval = 30
    private let logger = Logger(subsystem: "i-cant-miss", category: "TodoService")

    init(persistence: PersistenceController) {
        self.persistence = persistence
        loadInitialData()
        configureAutoRefresh()
    }

    deinit {
        refreshTimer?.cancel()
    }

    private func loadInitialData() {
        let context = persistence.container.viewContext
        let request: NSFetchRequest<TodoList> = TodoList.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \TodoList.isArchived, ascending: true),
            NSSortDescriptor(keyPath: \TodoList.isPinned, ascending: false),
            NSSortDescriptor(keyPath: \TodoList.userOrder, ascending: true),
            NSSortDescriptor(keyPath: \TodoList.updatedAt, ascending: false)
        ]
        request.relationshipKeyPathsForPrefetching = ["items"]

        do {
            let results = try context.fetch(request)
            lists = results.map { $0.toModel() }
            lastRefreshed = Date()
        } catch {
            logger.error("Failed to load initial todo lists: \(error.localizedDescription)")
            lists = []
            lastRefreshed = nil
        }
    }

    func configureAutoRefresh() {
        refreshTimer?.cancel()
        refreshTimer = Timer.publish(every: cacheTTL, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.refresh(force: false)
                }
            }
    }

    @discardableResult
    func refresh(force: Bool) async -> [TodoListModel] {
        if !force, let lastRefreshed, Date().timeIntervalSince(lastRefreshed) < cacheTTL {
            return lists
        }

        let context = persistence.container.viewContext
        do {
            let fetched = try await fetchLists(in: context)
            await MainActor.run {
                self.lists = fetched
                self.lastRefreshed = Date()
            }
            return fetched
        } catch {
            logger.error("Failed to refresh todo lists: \(error.localizedDescription)")
            return lists
        }
    }

    func createList(title: String,
                    notes: String?,
                    dueDate: Date?,
                    isPinned: Bool,
                    items: [TodoItemModel]) async throws -> TodoListModel {
        let sanitizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitizedTitle.isEmpty else {
            throw TodoServiceError.validationFailed("Todo title is required.")
        }

        let filteredItems = items.filter { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !filteredItems.isEmpty else {
            throw TodoServiceError.validationFailed("Add at least one item to the todo list.")
        }

        let currentOrder = Int16(lists.filter { !$0.isArchived }.count)

        let objectID: NSManagedObjectID = try await withCheckedThrowingContinuation { continuation in
            persistence.performBackgroundTask { context in
                do {
                    let list = TodoList(context: context)
                    list.id = UUID()
                    list.title = sanitizedTitle
                    list.notes = notes?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                    list.dueDate = dueDate
                    list.isPinned = isPinned
                    list.isArchived = false
                    list.createdAt = Date()
                    list.updatedAt = Date()
                    list.userOrder = currentOrder

                    for (index, itemModel) in filteredItems.enumerated() {
                        let item = TodoItem(context: context)
                        item.id = itemModel.id
                        item.title = itemModel.title.trimmingCharacters(in: .whitespacesAndNewlines)
                        item.detail = itemModel.detail?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                        item.isCompleted = itemModel.isCompleted
                        item.sortOrder = Int16(index)
                        item.createdAt = itemModel.createdAt
                        item.completedAt = itemModel.isCompleted ? (itemModel.completedAt ?? Date()) : nil
                        item.list = list
                    }

                    try context.save()
                    continuation.resume(returning: list.objectID)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        return try await fetchListFromViewContext(objectID: objectID)
    }

    func updateList(_ model: TodoListModel) async throws -> TodoListModel {
        let objectID: NSManagedObjectID = try await withCheckedThrowingContinuation { continuation in
            persistence.performBackgroundTask { context in
                do {
                    guard let list = try self.fetchList(by: model.id, context: context) else {
                        throw TodoServiceError.listNotFound
                    }

                    list.title = model.title.trimmingCharacters(in: .whitespacesAndNewlines)
                    list.notes = model.notes?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                    list.dueDate = model.dueDate
                    list.isPinned = model.isPinned
                    list.isArchived = model.isArchived
                    list.updatedAt = Date()
                    list.userOrder = Int16(model.userOrder)

                    let existingItems = (list.items as? Set<TodoItem>) ?? []
                    var itemsByID: [UUID: TodoItem] = [:]
                    for item in existingItems {
                        if let id = item.id {
                            itemsByID[id] = item
                        }
                    }

                    for (index, itemModel) in model.items.enumerated() {
                        let trimmedTitle = itemModel.title.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmedTitle.isEmpty else { continue }

                        let item: TodoItem
                        if let existing = itemsByID[itemModel.id] {
                            item = existing
                            itemsByID.removeValue(forKey: itemModel.id)
                        } else {
                            item = TodoItem(context: context)
                            item.id = itemModel.id
                            item.createdAt = itemModel.createdAt
                            item.list = list
                        }

                        item.title = trimmedTitle
                        item.detail = itemModel.detail?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                        item.isCompleted = itemModel.isCompleted
                        item.sortOrder = Int16(index)
                        item.completedAt = itemModel.isCompleted ? (itemModel.completedAt ?? Date()) : nil
                        if item.createdAt == nil {
                            item.createdAt = Date()
                        }
                    }

                    // Remove items that are no longer present
                    for (_, staleItem) in itemsByID {
                        context.delete(staleItem)
                    }

                    try context.save()
                    continuation.resume(returning: list.objectID)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        return try await fetchListFromViewContext(objectID: objectID)
    }

    func deleteList(id: UUID) async throws {
        try await withCheckedThrowingContinuation { continuation in
            persistence.performBackgroundTask { context in
                do {
                    guard let list = try self.fetchList(by: id, context: context) else {
                        throw TodoServiceError.listNotFound
                    }
                    context.delete(list)
                    try context.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func togglePin(listID: UUID) async throws -> TodoListModel {
        let currentLists = lists
        guard let existing = currentLists.first(where: { $0.id == listID }) else {
            throw TodoServiceError.listNotFound
        }
        var updated = existing
        updated.isPinned.toggle()
        updated.updatedAt = Date()
        return try await updateList(updated)
    }

    func setArchived(_ archived: Bool, listID: UUID) async throws -> TodoListModel {
        let currentLists = lists
        guard let existing = currentLists.first(where: { $0.id == listID }) else {
            throw TodoServiceError.listNotFound
        }
        var updated = existing
        updated.isArchived = archived
        updated.updatedAt = Date()
        return try await updateList(updated)
    }

    func toggleItemCompletion(listID: UUID, itemID: UUID) async throws {
        try await withCheckedThrowingContinuation { continuation in
            persistence.performBackgroundTask { context in
                do {
                    guard let list = try self.fetchList(by: listID, context: context) else {
                        throw TodoServiceError.listNotFound
                    }

                    let request: NSFetchRequest<TodoItem> = TodoItem.fetchRequest()
                    request.predicate = NSPredicate(format: "id == %@", itemID as CVarArg)
                    request.fetchLimit = 1

                    guard let item = try context.fetch(request).first else {
                        throw TodoServiceError.itemNotFound
                    }

                    item.isCompleted.toggle()
                    item.completedAt = item.isCompleted ? Date() : nil
                    list.updatedAt = Date()

                    try context.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func addQuickItem(to listID: UUID, title: String, detail: String?) async throws -> TodoItemModel {
        let sanitizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitizedTitle.isEmpty else {
            throw TodoServiceError.validationFailed("Item title cannot be empty.")
        }

        let objectID: NSManagedObjectID = try await withCheckedThrowingContinuation { continuation in
            persistence.performBackgroundTask { context in
                do {
                    guard let list = try self.fetchList(by: listID, context: context) else {
                        throw TodoServiceError.listNotFound
                    }

                    let item = TodoItem(context: context)
                    item.id = UUID()
                    item.title = sanitizedTitle
                    item.detail = detail?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                    item.isCompleted = false
                    item.createdAt = Date()
                    item.sortOrder = Int16((list.items as? Set<TodoItem>)?.count ?? 0)
                    item.list = list

                    list.updatedAt = Date()

                    try context.save()
                    continuation.resume(returning: item.objectID)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        return try await fetchItemFromViewContext(objectID: objectID)
    }

    func deleteItem(listID: UUID, itemID: UUID) async throws {
        try await withCheckedThrowingContinuation { continuation in
            persistence.performBackgroundTask { context in
                do {
                    guard let list = try self.fetchList(by: listID, context: context) else {
                        throw TodoServiceError.listNotFound
                    }

                    let request: NSFetchRequest<TodoItem> = TodoItem.fetchRequest()
                    request.predicate = NSPredicate(format: "id == %@", itemID as CVarArg)
                    request.fetchLimit = 1

                    guard let item = try context.fetch(request).first else {
                        throw TodoServiceError.itemNotFound
                    }

                    context.delete(item)
                    list.updatedAt = Date()
                    try context.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func moveItems(listID: UUID, fromOffsets: IndexSet, toOffset: Int) async throws {
        guard var list = lists.first(where: { $0.id == listID }) else {
            throw TodoServiceError.listNotFound
        }

        var reordered = list.items
        let sortedSource = fromOffsets.sorted(by: >)
        var extracted: [TodoItemModel] = []

        for index in sortedSource {
            guard reordered.indices.contains(index) else { continue }
            extracted.insert(reordered.remove(at: index), at: 0)
        }

        let adjustedDestination = max(0, min(toOffset - fromOffsets.filter { $0 < toOffset }.count, reordered.count))
        reordered.insert(contentsOf: extracted, at: adjustedDestination)

        for index in reordered.indices {
            reordered[index].sortOrder = index
        }

        list.items = reordered
        list.updatedAt = Date()

        _ = try await updateList(list)
    }

    func fetchListWithItems(id: UUID) -> TodoListModel? {
        let context = persistence.container.viewContext
        do {
            let request: NSFetchRequest<TodoList> = TodoList.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.relationshipKeyPathsForPrefetching = ["items"]
            request.fetchLimit = 1

            guard let list = try context.fetch(request).first else {
                return nil
            }

            return list.toModel()
        } catch {
            logger.error("Failed to fetch todo list with items: \(error.localizedDescription)")
            return nil
        }
    }

    func list(with id: UUID) -> TodoListModel? {
        lists.first(where: { $0.id == id })
    }

    // MARK: - Private helpers

    private func fetchListFromViewContext(objectID: NSManagedObjectID) async throws -> TodoListModel {
        try await withCheckedThrowingContinuation { continuation in
            let viewContext = persistence.container.viewContext
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                viewContext.perform {
                    do {
                        viewContext.refresh(viewContext.object(with: objectID), mergeChanges: true)
                        guard let list = try? viewContext.existingObject(with: objectID) as? TodoList else {
                            throw TodoServiceError.listNotFound
                        }
                        continuation.resume(returning: list.toModel())
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    private func fetchItemFromViewContext(objectID: NSManagedObjectID) async throws -> TodoItemModel {
        try await withCheckedThrowingContinuation { continuation in
            let viewContext = persistence.container.viewContext
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                viewContext.perform {
                    do {
                        viewContext.refresh(viewContext.object(with: objectID), mergeChanges: true)
                        guard let item = try? viewContext.existingObject(with: objectID) as? TodoItem else {
                            throw TodoServiceError.itemNotFound
                        }
                        continuation.resume(returning: item.toModel())
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    private func fetchList(by id: UUID, context: NSManagedObjectContext) throws -> TodoList? {
        let request: NSFetchRequest<TodoList> = TodoList.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private func fetchLists(in context: NSManagedObjectContext) async throws -> [TodoListModel] {
        try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let request: NSFetchRequest<TodoList> = TodoList.fetchRequest()
                    request.sortDescriptors = [
                        NSSortDescriptor(keyPath: \TodoList.isArchived, ascending: true),
                        NSSortDescriptor(keyPath: \TodoList.isPinned, ascending: false),
                        NSSortDescriptor(keyPath: \TodoList.userOrder, ascending: true),
                        NSSortDescriptor(keyPath: \TodoList.updatedAt, ascending: false)
                    ]
                    request.relationshipKeyPathsForPrefetching = ["items"]
                    let results = try context.fetch(request)
                    continuation.resume(returning: results.map { $0.toModel() })
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
