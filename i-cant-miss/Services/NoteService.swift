//
//  NoteService.swift
//  i-cant-miss
//
//  Created by Codex on 13/10/25.
//

import Foundation
import Combine
@preconcurrency import CoreData
import os.log

@MainActor
final class NoteService: ObservableObject {
    enum NoteServiceError: Error {
        case noteNotFound
        case folderNotFound
        case validationFailed(String)
    }

    enum NoteFilter {
        case all
        case folder(UUID)
        case pinned
    }

    @Published private(set) var notes: [NoteModel] = []
    @Published private(set) var lastRefreshed: Date?

    private let persistence: PersistenceController
    private let folderService: FolderService
    private var refreshTimer: AnyCancellable?
    private let cacheTTL: TimeInterval = 30
    private let logger = Logger(subsystem: "i-cant-miss", category: "NoteService")

    init(persistence: PersistenceController, folderService: FolderService) {
        self.persistence = persistence
        self.folderService = folderService

        // Load initial data synchronously to ensure data is available immediately
        loadInitialData()
        configureAutoRefresh()
    }

    private func loadInitialData() {
        let context = persistence.container.viewContext

        let noteModels: [NoteModel]
        do {
            let request: NSFetchRequest<Note> = Note.fetchRequest()
            request.sortDescriptors = [
                NSSortDescriptor(keyPath: \Note.isPinned, ascending: false),
                NSSortDescriptor(keyPath: \Note.updatedAt, ascending: false)
            ]
            // Prefetch relationships to avoid faulting issues
            request.relationshipKeyPathsForPrefetching = ["folder", "tags"]
            let results = try context.fetch(request)
            noteModels = results.map { $0.toModel() }
        } catch {
            logger.error("Failed to load initial notes: \(error.localizedDescription)")
            noteModels = []
        }

        // Update properties directly - we're already on MainActor
        self.notes = noteModels
        self.lastRefreshed = Date()
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
    func refresh(force: Bool) async -> [NoteModel] {
        if !force, let last = lastRefreshed, Date().timeIntervalSince(last) < cacheTTL {
            return notes
        }

        let context = persistence.container.viewContext
        do {
            let fetched = try await fetchNotes(in: context)

            // Always update on main thread to ensure UI updates
            await MainActor.run {
                self.notes = fetched
                self.lastRefreshed = Date()
            }

            return fetched
        } catch {
            logger.error("Failed to refresh notes: \(error.localizedDescription)")
            return notes
        }
    }

    func notes(for filter: NoteFilter) -> [NoteModel] {
        switch filter {
        case .all:
            return notes
        case .folder(let id):
            return notes.filter { $0.folder?.id == id }
        case .pinned:
            return notes.filter(\.isPinned)
        }
    }

    func createNote(title: String?, content: String, folderID: UUID?, tagIDs: [UUID], isPinned: Bool) async throws -> NoteModel {
        let objectID: NSManagedObjectID = try await withCheckedThrowingContinuation { continuation in
            persistence.performBackgroundTask { context in
                do {
                    guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        throw NoteServiceError.validationFailed("Note content is required")
                    }

                    let note = Note(context: context)
                    note.id = UUID()
                    note.title = title
                    note.content = content
                    note.createdAt = Date()
                    note.updatedAt = Date()
                    note.isPinned = isPinned

                    if let folderID = folderID,
                       let folder = try self.folderService.fetchFolder(by: folderID, context: context) {
                        note.folder = folder
                    }

                    let tags = try tagIDs.compactMap { try self.folderService.fetchTag(by: $0, context: context) }
                    if !tags.isEmpty {
                        note.addToTags(NSSet(array: tags))
                    }

                    try context.save()
                    continuation.resume(returning: note.objectID)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        // Now fetch from view context after save is complete
        return try await fetchNoteFromViewContext(objectID: objectID)
    }

    func updateNote(_ model: NoteModel) async throws -> NoteModel {
        let objectID: NSManagedObjectID = try await withCheckedThrowingContinuation { continuation in
            persistence.performBackgroundTask { context in
                do {
                    guard let note = try self.fetchNote(by: model.id, context: context) else {
                        throw NoteServiceError.noteNotFound
                    }

                    guard !model.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        throw NoteServiceError.validationFailed("Note content is required")
                    }

                    note.title = model.title
                    note.content = model.content
                    note.isPinned = model.isPinned
                    note.updatedAt = Date()

                    if let folderID = model.folder?.id,
                       let folder = try self.folderService.fetchFolder(by: folderID, context: context) {
                        note.folder = folder
                    } else {
                        note.folder = nil
                    }

                    note.removeFromTags(note.tags ?? NSSet())
                    let tags = try model.tags.compactMap { try self.folderService.fetchTag(by: $0.id, context: context) }
                    if !tags.isEmpty {
                        note.addToTags(NSSet(array: tags))
                    }

                    try context.save()
                    continuation.resume(returning: note.objectID)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        // Now fetch from view context after save is complete
        return try await fetchNoteFromViewContext(objectID: objectID)
    }

    func togglePin(noteID: UUID) async throws -> NoteModel {
        try await mutateNote(id: noteID) { note, _ in
            note.isPinned.toggle()
            note.updatedAt = Date()
        }
    }

    func deleteNote(id: UUID) async throws {
        try await withCheckedThrowingContinuation { continuation in
            persistence.performBackgroundTask { context in
                do {
                    guard let note = try self.fetchNote(by: id, context: context) else {
                        throw NoteServiceError.noteNotFound
                    }
                    context.delete(note)
                    try context.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchNoteWithRelationships(id: UUID) -> NoteModel? {
        let context = persistence.container.viewContext
        do {
            let request: NSFetchRequest<Note> = Note.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.relationshipKeyPathsForPrefetching = ["folder", "tags"]
            request.fetchLimit = 1

            guard let note = try context.fetch(request).first else {
                return nil
            }

            return note.toModel()
        } catch {
            logger.error("Failed to fetch note with relationships: \(error.localizedDescription)")
            return nil
        }
    }    // MARK: - Private helpers

    private func fetchNoteFromViewContext(objectID: NSManagedObjectID) async throws -> NoteModel {
        return try await withCheckedThrowingContinuation { continuation in
            let viewContext = persistence.container.viewContext

            // Give a small delay to ensure the save notification has been processed
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                viewContext.perform {
                    do {
                        // Refresh to get the latest merged changes
                        viewContext.refresh(viewContext.object(with: objectID), mergeChanges: true)

                        guard let note = try? viewContext.existingObject(with: objectID) as? Note else {
                            throw NoteServiceError.noteNotFound
                        }
                        continuation.resume(returning: note.toModel())
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    private func fetchNotes(in context: NSManagedObjectContext) async throws -> [NoteModel] {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let request: NSFetchRequest<Note> = Note.fetchRequest()
                    request.sortDescriptors = [
                        NSSortDescriptor(keyPath: \Note.isPinned, ascending: false),
                        NSSortDescriptor(keyPath: \Note.updatedAt, ascending: false)
                    ]
                    // Prefetch relationships to avoid faulting issues
                    request.relationshipKeyPathsForPrefetching = ["folder", "tags"]
                    let results = try context.fetch(request)
                    continuation.resume(returning: results.map { $0.toModel() })
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func mutateNote(id: UUID, mutation: @escaping (Note, NSManagedObjectContext) throws -> Void) async throws -> NoteModel {
        try await withCheckedThrowingContinuation { continuation in
            persistence.performBackgroundTask { context in
                do {
                    guard let note = try self.fetchNote(by: id, context: context) else {
                        throw NoteServiceError.noteNotFound
                    }
                    try mutation(note, context)
                    try context.save()
                    self.fetchNote(by: note.objectID) { result in
                        continuation.resume(with: result)
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func fetchNote(by objectID: NSManagedObjectID, completion: @escaping (Result<NoteModel, Error>) -> Void) {
        let viewContext = persistence.container.viewContext

        // Wait a bit to ensure background context save has completed and merged
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            viewContext.perform {
                do {
                    // Refresh to ensure we have latest data
                    viewContext.refreshAllObjects()

                    let note = try viewContext.existingObject(with: objectID) as? Note
                    guard let note = note else {
                        throw NoteServiceError.noteNotFound
                    }
                    completion(.success(note.toModel()))
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }

    private func fetchNote(by id: UUID, context: NSManagedObjectContext) throws -> Note? {
        let request = Note.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }
}
