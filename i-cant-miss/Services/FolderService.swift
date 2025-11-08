//
//  FolderService.swift
//  i-cant-miss
//
//  Created by Codex on 13/10/25.
//

import Foundation
import Combine
@preconcurrency import CoreData
import os.log

@MainActor
final class FolderService: ObservableObject {
    enum FolderServiceError: Error {
        case folderNotFound
        case tagNotFound
        case validationFailed(String)
    }

    @Published private(set) var folders: [FolderModel] = []
    @Published private(set) var tags: [TagModel] = []

    private let persistence: PersistenceController
    private var refreshTimer: AnyCancellable?
    private let cacheTTL: TimeInterval = 30
    private let logger = Logger(subsystem: "i-cant-miss", category: "FolderService")
    private var lastFoldersRefresh: Date?
    private var lastTagsRefresh: Date?

    init(persistence: PersistenceController) {
        self.persistence = persistence

        // Load initial data synchronously to ensure data is available immediately
        loadInitialData()
        configureAutoRefresh()
    }

    private func loadInitialData() {
        let context = persistence.container.viewContext

        var folderModels: [FolderModel]
        var tagModels: [TagModel]

        do {
            // Load folders
            let folderRequest: NSFetchRequest<Folder> = Folder.fetchRequest()
            folderRequest.sortDescriptors = [
                NSSortDescriptor(keyPath: \Folder.sortOrder, ascending: true)
            ]
            folderRequest.returnsObjectsAsFaults = false
            folderRequest.relationshipKeyPathsForPrefetching = ["parent", "children"]
            let folderResults = try context.fetch(folderRequest)
            folderModels = folderResults.map { $0.toModel() }

            // Load tags
            let tagRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
            tagRequest.sortDescriptors = [
                NSSortDescriptor(keyPath: \Tag.name, ascending: true)
            ]
            let tagResults = try context.fetch(tagRequest)
            tagModels = tagResults.map { $0.toModel() }
        } catch {
            logger.error("Failed to load initial folders/tags: \(error.localizedDescription)")
            folderModels = []
            tagModels = []
        }

        // Update properties directly - we're already on MainActor
        self.folders = folderModels
        self.tags = tagModels
        self.lastFoldersRefresh = Date()
        self.lastTagsRefresh = Date()
    }
    func configureAutoRefresh() {
        refreshTimer?.cancel()
        refreshTimer = Timer.publish(every: cacheTTL, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.refreshFolders(force: false)
                    await self?.refreshTags(force: false)
                }
            }
    }

    @discardableResult
    func refreshFolders(force: Bool) async -> [FolderModel] {
        if !force,
           let last = lastFoldersRefresh,
           Date().timeIntervalSince(last) < cacheTTL {
            return folders
        }

        do {
            let fetched = try fetchFolders(in: persistence.container.viewContext)

            // Always update on main thread to ensure UI updates
            await MainActor.run {
                self.folders = fetched
                self.lastFoldersRefresh = Date()
            }

            return fetched
        } catch {
            logger.error("Failed to refresh folders: \(error.localizedDescription)")
            return folders
        }
    }

    @discardableResult
    func refreshTags(force: Bool) async -> [TagModel] {
        if !force,
           let last = lastTagsRefresh,
           Date().timeIntervalSince(last) < cacheTTL {
            return tags
        }

        do {
            let fetched = try await fetchTags(in: persistence.container.viewContext)

            // Always update on main thread to ensure UI updates
            await MainActor.run {
                self.tags = fetched
                self.lastTagsRefresh = Date()
            }

            return fetched
        } catch {
            logger.error("Failed to refresh tags: \(error.localizedDescription)")
            return tags
        }
    }

    func createFolder(
        name: String,
        colorHex: String?,
        iconName: String?,
        isDefault: Bool,
        audience: FolderAudience,
        parentID: UUID? = nil
    ) async throws -> FolderModel {
        try await withCheckedThrowingContinuation { continuation in
            persistence.performBackgroundTask { context in
                do {
                    guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        throw FolderServiceError.validationFailed("Folder name is required")
                    }

                    if isDefault {
                        try self.clearDefaultFolder(context: context, audience: audience)
                    }

                    let folder = Folder(context: context)
                    folder.id = UUID()
                    folder.name = name
                    folder.colorHex = colorHex
                    folder.iconName = iconName
                    folder.isDefault = isDefault
                    folder.setAudience(audience)
                    if let parentID,
                       let parentFolder = try self.fetchFolder(by: parentID, context: context) {
                        folder.parentFolder = parentFolder
                        let siblingCount = parentFolder.childFolderSet.count
                        folder.sortOrder = Int16(siblingCount)
                    } else {
                        let rootCount = try self.countRootFolders(in: context)
                        folder.sortOrder = Int16(rootCount)
                    }

                    try context.save()
                    self.fetchFolder(by: folder.objectID) { result in
                        continuation.resume(with: result)
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func updateFolder(_ model: FolderModel) async throws -> FolderModel {
        try await withCheckedThrowingContinuation { continuation in
            persistence.performBackgroundTask { context in
                do {
                    guard let folder = try self.fetchFolder(by: model.id, context: context) else {
                        throw FolderServiceError.folderNotFound
                    }

                    guard !model.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        throw FolderServiceError.validationFailed("Folder name is required")
                    }

                    if model.isDefault {
                        try self.clearDefaultFolder(context: context, audience: model.audience, excluding: folder)
                    }

                    folder.name = model.name
                    folder.colorHex = model.colorHex
                    folder.iconName = model.iconName
                    folder.isDefault = model.isDefault
                    folder.setAudience(model.audience)
                    folder.sortOrder = Int16(model.sortOrder)
                    if let parentID = model.parentID {
                        guard parentID != model.id else {
                            throw FolderServiceError.validationFailed("A folder cannot be its own parent.")
                        }
                        if let parentFolder = try self.fetchFolder(by: parentID, context: context) {
                            folder.parentFolder = parentFolder
                        } else {
                            throw FolderServiceError.folderNotFound
                        }
                    } else {
                        folder.parentFolder = nil
                    }

                    try context.save()
                    self.fetchFolder(by: folder.objectID) { result in
                        continuation.resume(with: result)
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func reorderFolders(_ orderedIDs: [UUID]) async throws {
        try await withCheckedThrowingContinuation { continuation in
            persistence.performBackgroundTask { context in
                do {
                    for (index, id) in orderedIDs.enumerated() {
                        if let folder = try self.fetchFolder(by: id, context: context) {
                            folder.sortOrder = Int16(index)
                        }
                    }
                    try context.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func deleteFolder(id: UUID) async throws {
        try await withCheckedThrowingContinuation { continuation in
            persistence.performBackgroundTask { context in
                do {
                    guard let folder = try self.fetchFolder(by: id, context: context) else {
                        throw FolderServiceError.folderNotFound
                    }
                    context.delete(folder)
                    try context.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func createTag(name: String, colorHex: String?) async throws -> TagModel {
        try await withCheckedThrowingContinuation { continuation in
            persistence.performBackgroundTask { context in
                do {
                    guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        throw FolderServiceError.validationFailed("Tag name is required")
                    }

                    let tag = Tag(context: context)
                    tag.id = UUID()
                    tag.name = name
                    tag.colorHex = colorHex

                    try context.save()
                    self.fetchTag(by: tag.objectID) { result in
                        continuation.resume(with: result)
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func deleteTag(id: UUID) async throws {
        try await withCheckedThrowingContinuation { continuation in
            persistence.performBackgroundTask { context in
                do {
                    guard let tag = try self.fetchTag(by: id, context: context) else {
                        throw FolderServiceError.tagNotFound
                    }
                    context.delete(tag)
                    try context.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Internal fetch helpers

    func fetchFolder(by id: UUID, context: NSManagedObjectContext) throws -> Folder? {
        let request = Folder.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    func fetchTag(by id: UUID, context: NSManagedObjectContext) throws -> Tag? {
        let request = Tag.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private func fetchFolder(by objectID: NSManagedObjectID, completion: @escaping (Result<FolderModel, Error>) -> Void) {
        let context = persistence.container.viewContext
        context.perform {
            do {
                guard let folder = try context.existingObject(with: objectID) as? Folder else {
                    throw FolderServiceError.folderNotFound
                }
                completion(.success(folder.toModel()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    private func fetchTag(by objectID: NSManagedObjectID, completion: @escaping (Result<TagModel, Error>) -> Void) {
        let context = persistence.container.viewContext
        context.perform {
            do {
                guard let tag = try context.existingObject(with: objectID) as? Tag else {
                    throw FolderServiceError.tagNotFound
                }
                completion(.success(tag.toModel()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    // MARK: - Core Data fetch helpers

    private func fetchFolders(in context: NSManagedObjectContext) throws -> [FolderModel] {
        let request: NSFetchRequest<Folder> = Folder.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Folder.sortOrder, ascending: true),
            NSSortDescriptor(keyPath: \Folder.name, ascending: true)
        ]
        request.returnsObjectsAsFaults = false
        request.relationshipKeyPathsForPrefetching = ["parent", "children"]

        let results = try context.fetch(request)
        var needsSave = false

        for folder in results {
            let reminderCount = Int(folder.reminders?.count ?? 0)
            let noteCount = Int(folder.notes?.count ?? 0)
            let todoCount = Int(folder.todoLists?.count ?? 0)
            let currentAudience = folder.audienceValue

            let needsReassignment =
                !folder.hasAssignedAudience ||
                (currentAudience == .reminders && reminderCount == 0 && (noteCount > 0 || todoCount > 0)) ||
                (currentAudience == .notes && noteCount == 0 && (reminderCount > 0 || todoCount > 0)) ||
                (currentAudience == .todos && todoCount == 0 && (reminderCount > 0 || noteCount > 0))

            if needsReassignment {
                let inferredAudience = inferAudience(for: folder)
                if inferredAudience != currentAudience {
                    folder.setAudience(inferredAudience)
                    needsSave = true
                }
            }
        }

        if needsSave {
            try context.save()
        }

        return results.map { $0.toModel() }
    }

    private func fetchTags(in context: NSManagedObjectContext) async throws -> [TagModel] {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let request: NSFetchRequest<Tag> = Tag.fetchRequest()
                    request.sortDescriptors = [
                        NSSortDescriptor(keyPath: \Tag.name, ascending: true)
                    ]
                    let results = try context.fetch(request)
                    continuation.resume(returning: results.map { $0.toModel() })
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func clearDefaultFolder(context: NSManagedObjectContext, audience: FolderAudience, excluding folder: Folder? = nil) throws {
        let request = Folder.fetchRequest()
        request.predicate = NSPredicate(format: "isDefault == YES AND audienceRaw == %@", audience.rawValue)
        let defaults = try context.fetch(request)
        for existing in defaults where existing != folder {
            existing.isDefault = false
        }
    }

    private func inferAudience(for folder: Folder) -> FolderAudience {
        let reminderCount = Int(folder.reminders?.count ?? 0)
        let noteCount = Int(folder.notes?.count ?? 0)
        let todoCount = Int(folder.todoLists?.count ?? 0)

        let counts: [(FolderAudience, Int)] = [
            (.reminders, reminderCount),
            (.notes, noteCount),
            (.todos, todoCount)
        ]

        if let max = counts.max(by: { $0.1 < $1.1 }), max.1 > 0 {
            return max.0
        }

        return .reminders
    }

    func folders(for audience: FolderAudience) -> [FolderModel] {
        folders.filter { $0.audience == audience }
    }

    func defaultFolder(for audience: FolderAudience) -> FolderModel? {
        folders.first(where: { $0.isDefault && $0.audience == audience })
    }

    private func countRootFolders(in context: NSManagedObjectContext) throws -> Int {
        let request: NSFetchRequest<Folder> = Folder.fetchRequest()
        request.predicate = NSPredicate(format: "parent == nil")
        let result = try context.count(for: request)
        return max(result, 0)
    }
}
