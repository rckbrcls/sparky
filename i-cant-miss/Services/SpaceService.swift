//
//  SpaceService.swift
//  i-cant-miss
//
//  Created by Codex on 09/03/24.
//

import Combine
@preconcurrency import CoreData
import os.log

enum SpaceServiceError: LocalizedError {
    case cannotDeleteDefaultSpace
    case spaceNotFound
    case tagNotFound
    case validationFailed(String)

    var errorDescription: String? {
        switch self {
        case .cannotDeleteDefaultSpace:
            return "Default spaces cannot be deleted."
        case .spaceNotFound:
            return "The space could not be found."
        case .tagNotFound:
            return "The tag could not be found."
        case .validationFailed(let message):
            return message
        }
    }
}

@MainActor
final class SpaceService: ObservableObject {
    @Published private(set) var spaces: [SpaceModel] = []
    @Published private(set) var tags: [TagModel] = []
    @Published private(set) var lastRefreshed: Date?

    private let persistence: PersistenceController
    private let cacheTTL: TimeInterval
    private var refreshTimer: AnyCancellable?
    private var spaceIndex: [UUID: SpaceModel] = [:]
    private let logger = Logger(subsystem: "i-cant-miss", category: "SpaceService")
    private var lastTagsRefresh: Date?

    init(persistence: PersistenceController, cacheTTL: TimeInterval = 30) {
        self.persistence = persistence
        self.cacheTTL = cacheTTL

        // Load initial data synchronously to ensure data is available immediately
        loadInitialData()
        configureAutoRefresh()
    }

    deinit {
        refreshTimer?.cancel()
    }

    private func loadInitialData() {
        let context = persistence.container.viewContext

        var spaceModels: [SpaceModel] = []
        var tagModels: [TagModel]

        do {
            // Load spaces
            let spaceRequest: NSFetchRequest<Space> = Space.fetchRequest()
            spaceRequest.sortDescriptors = [
                NSSortDescriptor(keyPath: \Space.sortOrder, ascending: true),
                NSSortDescriptor(keyPath: \Space.name, ascending: true)
            ]
            spaceRequest.returnsObjectsAsFaults = false
            let spaceResults = try context.fetch(spaceRequest)

            for space in spaceResults {
                let spaceModel = space.toModel()
                spaceModels.append(spaceModel)
            }

            // Load tags
            let tagRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
            tagRequest.sortDescriptors = [
                NSSortDescriptor(keyPath: \Tag.name, ascending: true)
            ]
            let tagResults = try context.fetch(tagRequest)
            tagModels = tagResults.map { $0.toModel() }
        } catch {
            logger.error("Failed to load initial spaces/tags: \(error.localizedDescription)")
            tagModels = []
        }

        // Deduplicate spaces by id to avoid duplicates
        var deduplicated: [UUID: SpaceModel] = [:]
        for space in spaceModels {
            deduplicated[space.id] = space
        }
        let orderedSpaces = deduplicated
            .values
            .sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder {
                    return lhs.sortOrder < rhs.sortOrder
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }

        // Update properties directly - we're already on MainActor
        self.spaces = Array(orderedSpaces)
        self.tags = tagModels
        self.lastRefreshed = Date()
        self.lastTagsRefresh = Date()
        rebuildIndex()
    }

    private func configureAutoRefresh() {
        refreshTimer?.cancel()
        refreshTimer = Timer.publish(every: cacheTTL, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.refresh(force: false)
                    await self?.refreshTags(force: false)
                }
            }
    }

    @discardableResult
    func refresh(force: Bool) async -> [SpaceModel] {
        if !force,
           let last = lastRefreshed,
           Date().timeIntervalSince(last) < cacheTTL {
            return spaces
        }

        let context = persistence.container.viewContext
        let request: NSFetchRequest<Space> = Space.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Space.sortOrder, ascending: true),
            NSSortDescriptor(keyPath: \Space.name, ascending: true)
        ]
        request.returnsObjectsAsFaults = false

        do {
            let spaces = try context.fetch(request)
            var nextSpaces: [SpaceModel] = []

            for space in spaces {
                let spaceModel = space.toModel()
                nextSpaces.append(spaceModel)
            }

            // Deduplicate by id to avoid duplicates.
            var deduplicated: [UUID: SpaceModel] = [:]
            for space in nextSpaces {
                deduplicated[space.id] = space
            }
            let orderedSpaces = deduplicated
                .values
                .sorted { lhs, rhs in
                    if lhs.sortOrder != rhs.sortOrder {
                        return lhs.sortOrder < rhs.sortOrder
                    }
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }

            self.spaces = Array(orderedSpaces)
            lastRefreshed = Date()
            rebuildIndex()
            return Array(orderedSpaces)
        } catch {
            logger.error("Failed to refresh spaces: \(error.localizedDescription)")
            return spaces
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

    private func rebuildIndex() {
        spaceIndex.removeAll(keepingCapacity: true)
        for space in spaces {
            spaceIndex[space.id] = space
        }
    }

    func space(id: UUID) -> SpaceModel? {
        spaceIndex[id]
    }

    func defaultSpace() -> SpaceModel? {
        spaces.first(where: { $0.isDefault })
    }



    func memoryIDs(in space: SpaceModel) -> [UUID] {
        let context = persistence.container.viewContext
        do {
            guard let spaceEntity = try fetchSpace(by: space.id, context: context) else {
                return []
            }
            let memories = spaceEntity.memories as? Set<Memory> ?? []
            return memories.compactMap { $0.id }
        } catch {
            logger.error("Failed to fetch memories for space: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - CRUD Operations

    func createSpace(
        name: String,
        colorHex: String?,
        iconName: String?,
        isDefault: Bool
    ) async throws -> SpaceModel {
        let objectID: NSManagedObjectID = try await withCheckedThrowingContinuation { continuation in
            persistence.performBackgroundTask { context in
                do {
                    guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        throw SpaceServiceError.validationFailed("Space name is required")
                    }

                    if isDefault {
                        try self.clearDefaultSpace(context: context)
                    }

                    let space = Space(context: context)
                    space.id = UUID()
                    space.name = name
                    space.colorHex = colorHex
                    space.iconName = iconName
                    space.isDefault = isDefault

                    let spaceCount = try self.countSpaces(in: context)
                    space.sortOrder = Int16(spaceCount)

                    try context.save()
                    continuation.resume(returning: space.objectID)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        return try await fetchSpaceFromViewContext(objectID: objectID)
    }

    func updateSpace(_ model: SpaceModel) async throws -> SpaceModel {
        let objectID: NSManagedObjectID = try await withCheckedThrowingContinuation { continuation in
            persistence.performBackgroundTask { context in
                do {
                    guard let space = try self.fetchSpace(by: model.id, context: context) else {
                        throw SpaceServiceError.spaceNotFound
                    }

                    guard !model.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        throw SpaceServiceError.validationFailed("Space name is required")
                    }

                    if model.isDefault {
                        try self.clearDefaultSpace(context: context, excluding: space)
                    }

                    space.name = model.name
                    space.colorHex = model.colorHex
                    space.iconName = model.iconName
                    space.isDefault = model.isDefault
                    space.sortOrder = Int16(model.sortOrder)



                    try context.save()
                    continuation.resume(returning: space.objectID)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        return try await fetchSpaceFromViewContext(objectID: objectID)
    }

    func reorderSpaces(_ orderedIDs: [UUID]) async throws {
        try await withCheckedThrowingContinuation { continuation in
            persistence.performBackgroundTask { context in
                do {
                    for (index, id) in orderedIDs.enumerated() {
                        if let space = try self.fetchSpace(by: id, context: context) {
                            space.sortOrder = Int16(index)
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

    func deleteSpace(_ space: SpaceModel, deleteMemories: Bool = false, memoryService: MemoryService? = nil) async throws {
        guard !space.isDefault else {
            throw SpaceServiceError.cannotDeleteDefaultSpace
        }

        // If deleteMemories is true and memoryService is provided, use it to delete memories (which also cleans up attachments)
        if deleteMemories, let memoryService = memoryService {
            let memoryIDs = memoryIDs(in: space)
            try await memoryService.deleteMemories(ids: memoryIDs)
        }

        try await withCheckedThrowingContinuation { continuation in
            persistence.performBackgroundTask { context in
                do {
                    guard let spaceEntity = try self.fetchSpace(by: space.id, context: context) else {
                        throw SpaceServiceError.spaceNotFound
                    }

                    // If deleteMemories is true but memoryService was not provided, delete memories directly in Core Data
                    // Note: This won't clean up attachments, but it's a fallback for backward compatibility
                    if deleteMemories && memoryService == nil {
                        let memories = spaceEntity.memories as? Set<Memory> ?? []
                        for memory in memories {
                            context.delete(memory)
                        }
                    }

                    context.delete(spaceEntity)
                    try context.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        _ = await refresh(force: true)

        // Refresh MemoryService to update memories that now have space = nil
        if let memoryService = memoryService {
            _ = await memoryService.refresh(force: true)
        }
    }

    // MARK: - Tag Operations

    func createTag(name: String, colorHex: String?) async throws -> TagModel {
        let objectID: NSManagedObjectID = try await withCheckedThrowingContinuation { continuation in
            persistence.performBackgroundTask { context in
                do {
                    guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        throw SpaceServiceError.validationFailed("Tag name is required")
                    }

                    let tag = Tag(context: context)
                    tag.id = UUID()
                    tag.name = name
                    tag.colorHex = colorHex

                    try context.save()
                    continuation.resume(returning: tag.objectID)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        return try await fetchTagFromViewContext(objectID: objectID)
    }

    func deleteTag(id: UUID) async throws {
        try await withCheckedThrowingContinuation { continuation in
            persistence.performBackgroundTask { context in
                do {
                    guard let tag = try self.fetchTag(by: id, context: context) else {
                        throw SpaceServiceError.tagNotFound
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

    func fetchSpace(by id: UUID, context: NSManagedObjectContext) throws -> Space? {
        let request = Space.fetchRequest()
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

    private func fetchSpaceFromViewContext(objectID: NSManagedObjectID) async throws -> SpaceModel {
        return try await withCheckedThrowingContinuation { continuation in
            let viewContext = persistence.container.viewContext
            viewContext.perform {
                do {
                    guard let space = try viewContext.existingObject(with: objectID) as? Space else {
                        throw SpaceServiceError.spaceNotFound
                    }
                    continuation.resume(returning: space.toModel())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func fetchTagFromViewContext(objectID: NSManagedObjectID) async throws -> TagModel {
        return try await withCheckedThrowingContinuation { continuation in
            let viewContext = persistence.container.viewContext
            viewContext.perform {
                do {
                    guard let tag = try viewContext.existingObject(with: objectID) as? Tag else {
                        throw SpaceServiceError.tagNotFound
                    }
                    continuation.resume(returning: tag.toModel())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
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

    private func clearDefaultSpace(context: NSManagedObjectContext, excluding space: Space? = nil) throws {
        let request = Space.fetchRequest()
        request.predicate = NSPredicate(format: "isDefault == YES")
        let defaults = try context.fetch(request)
        for existing in defaults where existing != space {
            existing.isDefault = false
        }
    }

    private func countSpaces(in context: NSManagedObjectContext) throws -> Int {
        let request: NSFetchRequest<Space> = Space.fetchRequest()
        let result = try context.count(for: request)
        return max(result, 0)
    }
}

// MARK: - Core Data Extensions

extension Space {
    func toModel() -> SpaceModel {
        SpaceModel(
            id: id ?? UUID(),
            name: name ?? "Untitled",
            colorHex: colorHex,
            iconName: iconName,
            sortOrder: Int(sortOrder),
            isDefault: isDefault
        )
    }
}

extension Tag {
    func toModel() -> TagModel {
        TagModel(
            id: id ?? UUID(),
            name: name ?? "",
            colorHex: colorHex
        )
    }
}
