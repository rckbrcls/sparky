//
//  MemoryBulkActionProcessor.swift
//  i-cant-miss
//
//  Created by GPT-5 Codex on 12/11/25.
//

import Foundation

@MainActor
final class MemoryBulkActionProcessor {
    struct MemoryBulkActionResult {
        let succeededIDs: Set<UUID>
        let failedIDs: [UUID: Error]

        var hasFailures: Bool { !failedIDs.isEmpty }
        var hasSuccesses: Bool { !succeededIDs.isEmpty }
    }

    enum ProcessorError: LocalizedError {
        case memoryNotFound
        case originUnavailable
        case unsupportedOperation(String)
        case folderUnavailable
        case modelNotFound
        case underlying(Error)

        var errorDescription: String? {
            switch self {
            case .memoryNotFound:
                return "Memory not found."
            case .originUnavailable:
                return "Memory origin is unavailable."
            case .unsupportedOperation(let description):
                return description
            case .folderUnavailable:
                return "Unable to resolve destination space."
            case .modelNotFound:
                return "Unable to load backing model."
            case .underlying(let error):
                return error.localizedDescription
            }
        }
    }

    private enum MutatedService: Hashable {
        case reminders
        case notes
        case todos
    }

    private let environment: AppEnvironment

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    // MARK: - Public API

    func moveMemories(_ ids: Set<UUID>, to space: SpaceModel) async -> MemoryBulkActionResult {
        let (result, services) = await process(ids: ids) { memory in
            try await self.move(memory: memory, to: space)
        }
        await refreshServices(services, hasSuccess: result.hasSuccesses)
        return result
    }

    func updateStatus(of ids: Set<UUID>, to status: MemoryStatus) async -> MemoryBulkActionResult {
        let (result, services) = await process(ids: ids) { memory in
            try await self.setStatus(for: memory, status: status)
        }
        await refreshServices(services, hasSuccess: result.hasSuccesses)
        return result
    }

    func updatePriority(of ids: Set<UUID>, to priority: MemoryPriority) async -> MemoryBulkActionResult {
        let (result, services) = await process(ids: ids) { memory in
            try await self.setPriority(for: memory, priority: priority)
        }
        await refreshServices(services, hasSuccess: result.hasSuccesses)
        return result
    }

    // MARK: - Processing helpers

    private func process(
        ids: Set<UUID>,
        handler: @escaping (MemoryModel) async throws -> Set<MutatedService>
    ) async -> (MemoryBulkActionResult, Set<MutatedService>) {
        var succeeded: Set<UUID> = []
        var failed: [UUID: Error] = [:]
        var mutatedServices: Set<MutatedService> = []

        for id in ids {
            guard let memory = environment.memoryService.memory(id: id) else {
                failed[id] = ProcessorError.memoryNotFound
                continue
            }

            do {
                let services = try await handler(memory)
                mutatedServices.formUnion(services)
                succeeded.insert(id)
            } catch {
                failed[id] = error
            }
        }

        let result = MemoryBulkActionResult(
            succeededIDs: succeeded,
            failedIDs: failed
        )
        return (result, mutatedServices)
    }

    private func refreshServices(_ services: Set<MutatedService>, hasSuccess: Bool) async {
        if services.contains(.reminders) {
            await environment.reminderService.refresh(force: true)
        }

        if services.contains(.notes) {
            await environment.noteService.refresh(force: true)
        }

        if services.contains(.todos) {
            await environment.todoService.refresh(force: true)
        }

        if hasSuccess {
            await environment.memoryService.refresh(force: true)
        }
    }

    // MARK: - Individual operations

    private func move(memory: MemoryModel, to space: SpaceModel) async throws -> Set<MutatedService> {
        guard let origin = memory.metadata.origin else {
            throw ProcessorError.originUnavailable
        }

        switch origin {
        case .reminder(let reminderID):
            try await moveReminder(reminderID, to: space)
            return [.reminders]
        case .note(let noteID):
            try await moveNote(noteID, to: space)
            return [.notes]
        case .todoList(let listID):
            try await moveTodoList(listID, to: space)
            return [.todos]
        }
    }

    private func setStatus(for memory: MemoryModel, status: MemoryStatus) async throws -> Set<MutatedService> {
        guard let origin = memory.metadata.origin else {
            throw ProcessorError.originUnavailable
        }

        switch origin {
        case .reminder(let reminderID):
            try await updateReminder(reminderID) { reminder in
                reminder.status = self.reminderStatus(for: status)
                if status == .completed {
                    reminder.lastCompletionDate = Date()
                }
                reminder.updatedAt = Date()
            }
            return [.reminders]
        case .note:
            throw ProcessorError.unsupportedOperation("Status cannot be changed for notes.")
        case .todoList(let listID):
            try await updateTodoList(listID) { list in
                switch status {
                case .active:
                    list.isArchived = false
                case .completed:
                    list.isArchived = false
                    list.items = list.items.map { item in
                        var updated = item
                        updated.isCompleted = true
                        updated.completedAt = updated.completedAt ?? Date()
                        return updated
                    }
                }
                list.updatedAt = Date()
            }
            return [.todos]
        }
    }

    private func setPriority(for memory: MemoryModel, priority: MemoryPriority) async throws -> Set<MutatedService> {
        guard let origin = memory.metadata.origin else {
            throw ProcessorError.originUnavailable
        }

        switch origin {
        case .reminder(let reminderID):
            try await updateReminder(reminderID) { reminder in
                reminder.priority = self.reminderPriority(for: priority)
                reminder.updatedAt = Date()
            }
            return [.reminders]
        case .note:
            throw ProcessorError.unsupportedOperation("Priority cannot be changed for notes.")
        case .todoList:
            throw ProcessorError.unsupportedOperation("Priority cannot be changed for todo lists.")
        }
    }

    // MARK: - Reminder helpers

    private func moveReminder(_ id: UUID, to space: SpaceModel) async throws {
        try await updateReminder(id) { reminder in
            reminder.folder = folder(for: space, audience: .reminders)
            reminder.updatedAt = Date()
        }
    }

    private func updateReminder(_ id: UUID, mutate: (inout ReminderModel) -> Void) async throws {
        guard var reminder = environment.reminderService.fetchReminderWithRelationships(id: id)
            ?? environment.reminderService.reminders.first(where: { $0.id == id }) else {
            throw ProcessorError.modelNotFound
        }

        mutate(&reminder)

        do {
            _ = try await environment.reminderService.updateReminder(reminder)
        } catch {
            throw ProcessorError.underlying(error)
        }
    }

    private func reminderStatus(for memoryStatus: MemoryStatus) -> ReminderStatus {
        switch memoryStatus {
        case .active: return .active
        case .completed: return .completed
        }
    }

    private func reminderPriority(for memoryPriority: MemoryPriority) -> ReminderPriority {
        ReminderPriority(rawValue: memoryPriority.rawValue) ?? .medium
    }

    // MARK: - Note helpers

    private func moveNote(_ id: UUID, to space: SpaceModel) async throws {
        guard var note = environment.noteService.fetchNoteWithRelationships(id: id)
            ?? environment.noteService.notes.first(where: { $0.id == id }) else {
            throw ProcessorError.modelNotFound
        }

        note.folder = folder(for: space, audience: .notes)
        note.updatedAt = Date()

        do {
            _ = try await environment.noteService.updateNote(note)
        } catch {
            throw ProcessorError.underlying(error)
        }
    }

    // MARK: - Todo helpers

    private func moveTodoList(_ id: UUID, to space: SpaceModel) async throws {
        try await updateTodoList(id) { list in
            list.folder = folder(for: space, audience: .todos)
            list.updatedAt = Date()
        }
    }

    private func updateTodoList(_ id: UUID, mutate: (inout TodoListModel) -> Void) async throws {
        guard var list = environment.todoService.fetchListWithItems(id: id)
            ?? environment.todoService.lists.first(where: { $0.id == id }) else {
            throw ProcessorError.modelNotFound
        }

        mutate(&list)

        do {
            _ = try await environment.todoService.updateList(list)
        } catch {
            throw ProcessorError.underlying(error)
        }
    }

    // MARK: - Folder resolution

    private func folder(for space: SpaceModel, audience: FolderAudience) -> FolderModel? {
        if let folder = space.legacyFolder, folder.audience == audience {
            return folder
        }

        if space.id == SpaceModel.allSpacesIdentifier || space.id == SpaceModel.inboxIdentifier {
            return environment.folderService.defaultFolder(for: audience)
        }

        if let folder = environment.folderService.folders.first(where: { $0.id == space.id && $0.audience == audience }) {
            return folder
        }

        return environment.folderService.defaultFolder(for: audience)
    }
}
