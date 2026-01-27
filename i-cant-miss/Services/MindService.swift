//
//  MindService.swift
//  i-cant-miss
//

import Combine
@preconcurrency import CoreData
import os.log

enum MindServiceError: LocalizedError {
    case cannotDeleteDefaultMind
    case mindNotFound
    case validationFailed(String)

    var errorDescription: String? {
        switch self {
        case .cannotDeleteDefaultMind:
            return "Default minds cannot be deleted."
        case .mindNotFound:
            return "The mind could not be found."
        case .validationFailed(let message):
            return message
        }
    }
}

@MainActor
final class MindService: ObservableObject {
    @Published private(set) var minds: [MindModel] = []
    @Published private(set) var lastRefreshed: Date?

    private let persistence: PersistenceController
    private let cacheTTL: TimeInterval
    private var refreshTimer: AnyCancellable?
    private var mindIndex: [UUID: MindModel] = [:]
    private let logger = Logger(subsystem: "i-cant-miss", category: "MindService")

    init(persistence: PersistenceController, cacheTTL: TimeInterval = 30) {
        self.persistence = persistence
        self.cacheTTL = cacheTTL

        loadInitialData()
        configureAutoRefresh()
    }

    deinit {
        refreshTimer?.cancel()
    }

    private func loadInitialData() {
        let context = persistence.container.viewContext

        var mindModels: [MindModel] = []

        do {
            let mindRequest: NSFetchRequest<Mind> = Mind.fetchRequest()
            mindRequest.sortDescriptors = [
                NSSortDescriptor(keyPath: \Mind.sortOrder, ascending: true),
                NSSortDescriptor(keyPath: \Mind.name, ascending: true)
            ]
            mindRequest.returnsObjectsAsFaults = false
            let mindResults = try context.fetch(mindRequest)

            for mind in mindResults {
                let mindModel = mind.toModel()
                mindModels.append(mindModel)
            }
        } catch {
            logger.error("Failed to load initial minds: \(error.localizedDescription)")
        }

        var deduplicated: [UUID: MindModel] = [:]
        for mind in mindModels {
            deduplicated[mind.id] = mind
        }
        let orderedMinds = deduplicated
            .values
            .sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder {
                    return lhs.sortOrder < rhs.sortOrder
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }

        self.minds = Array(orderedMinds)
        self.lastRefreshed = Date()
        rebuildIndex()
    }

    private func configureAutoRefresh() {
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
    func refresh(force: Bool) async -> [MindModel] {
        if !force,
           let last = lastRefreshed,
           Date().timeIntervalSince(last) < cacheTTL {
            return minds
        }

        let context = persistence.container.viewContext
        let request: NSFetchRequest<Mind> = Mind.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Mind.sortOrder, ascending: true),
            NSSortDescriptor(keyPath: \Mind.name, ascending: true)
        ]
        request.returnsObjectsAsFaults = false

        do {
            let minds = try context.fetch(request)
            var nextMinds: [MindModel] = []

            for mind in minds {
                let mindModel = mind.toModel()
                nextMinds.append(mindModel)
            }

            var deduplicated: [UUID: MindModel] = [:]
            for mind in nextMinds {
                deduplicated[mind.id] = mind
            }
            let orderedMinds = deduplicated
                .values
                .sorted { lhs, rhs in
                    if lhs.sortOrder != rhs.sortOrder {
                        return lhs.sortOrder < rhs.sortOrder
                    }
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }

            self.minds = Array(orderedMinds)
            lastRefreshed = Date()
            rebuildIndex()
            return Array(orderedMinds)
        } catch {
            logger.error("Failed to refresh minds: \(error.localizedDescription)")
            return minds
        }
    }

    private func rebuildIndex() {
        mindIndex.removeAll(keepingCapacity: true)
        for mind in minds {
            mindIndex[mind.id] = mind
        }
    }

    func mind(id: UUID) -> MindModel? {
        mindIndex[id]
    }

    func defaultMind() -> MindModel? {
        minds.first(where: { $0.isDefault })
    }

    func spaceIDs(in mind: MindModel) -> [UUID] {
        let context = persistence.container.viewContext
        do {
            guard let mindEntity = try fetchMind(by: mind.id, context: context) else {
                return []
            }
            let spaces = mindEntity.spaces as? Set<Space> ?? []
            return spaces.compactMap { $0.id }
        } catch {
            logger.error("Failed to fetch spaces for mind: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - CRUD Operations

    func createMind(
        name: String,
        colorHex: String?,
        iconName: String?,
        isDefault: Bool
    ) async throws -> MindModel {
        let objectID: NSManagedObjectID = try await withCheckedThrowingContinuation { continuation in
            persistence.performBackgroundTask { context in
                do {
                    guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        throw MindServiceError.validationFailed("Mind name is required")
                    }

                    if isDefault {
                        try self.clearDefaultMind(context: context)
                    }

                    let mind = Mind(context: context)
                    mind.id = UUID()
                    mind.name = name
                    mind.colorHex = colorHex
                    mind.iconName = iconName
                    mind.isDefault = isDefault

                    let mindCount = try self.countMinds(in: context)
                    mind.sortOrder = Int16(mindCount)

                    try context.save()
                    continuation.resume(returning: mind.objectID)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        return try await fetchMindFromViewContext(objectID: objectID)
    }

    func updateMind(_ model: MindModel) async throws -> MindModel {
        let objectID: NSManagedObjectID = try await withCheckedThrowingContinuation { continuation in
            persistence.performBackgroundTask { context in
                do {
                    guard let mind = try self.fetchMind(by: model.id, context: context) else {
                        throw MindServiceError.mindNotFound
                    }

                    guard !model.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        throw MindServiceError.validationFailed("Mind name is required")
                    }

                    if model.isDefault {
                        try self.clearDefaultMind(context: context, excluding: mind)
                    }

                    mind.name = model.name
                    mind.colorHex = model.colorHex
                    mind.iconName = model.iconName
                    mind.isDefault = model.isDefault
                    mind.sortOrder = Int16(model.sortOrder)

                    try context.save()
                    continuation.resume(returning: mind.objectID)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        return try await fetchMindFromViewContext(objectID: objectID)
    }

    func reorderMinds(_ orderedIDs: [UUID]) async throws {
        let currentMinds = self.minds
        var mindMap = Dictionary(uniqueKeysWithValues: currentMinds.map { ($0.id, $0) })

        var newOrderedMinds: [MindModel] = []

        for (index, id) in orderedIDs.enumerated() {
            if let mind = mindMap[id] {
                let updatedMind = MindModel(
                    id: mind.id,
                    name: mind.name,
                    colorHex: mind.colorHex,
                    iconName: mind.iconName,
                    sortOrder: index,
                    isDefault: mind.isDefault
                )
                newOrderedMinds.append(updatedMind)
                mindMap.removeValue(forKey: id)
            }
        }

        let remainingMinds = currentMinds.filter { mindMap.keys.contains($0.id) }
        newOrderedMinds.append(contentsOf: remainingMinds)

        self.minds = newOrderedMinds
        rebuildIndex()

        try await withCheckedThrowingContinuation { continuation in
            persistence.performBackgroundTask { context in
                do {
                    for (index, id) in orderedIDs.enumerated() {
                        if let mind = try self.fetchMind(by: id, context: context) {
                            mind.sortOrder = Int16(index)
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

    func deleteMind(_ mind: MindModel) async throws {
        guard !mind.isDefault else {
            throw MindServiceError.cannotDeleteDefaultMind
        }

        try await withCheckedThrowingContinuation { continuation in
            persistence.performBackgroundTask { context in
                do {
                    guard let mindEntity = try self.fetchMind(by: mind.id, context: context) else {
                        throw MindServiceError.mindNotFound
                    }

                    context.delete(mindEntity)
                    try context.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        _ = await refresh(force: true)
    }

    // MARK: - Internal fetch helpers

    func fetchMind(by id: UUID, context: NSManagedObjectContext) throws -> Mind? {
        let request = Mind.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private func fetchMindFromViewContext(objectID: NSManagedObjectID) async throws -> MindModel {
        return try await withCheckedThrowingContinuation { continuation in
            let viewContext = persistence.container.viewContext
            viewContext.perform {
                do {
                    guard let mind = try viewContext.existingObject(with: objectID) as? Mind else {
                        throw MindServiceError.mindNotFound
                    }
                    continuation.resume(returning: mind.toModel())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func clearDefaultMind(context: NSManagedObjectContext, excluding mind: Mind? = nil) throws {
        let request = Mind.fetchRequest()
        request.predicate = NSPredicate(format: "isDefault == YES")
        let defaults = try context.fetch(request)
        for existing in defaults where existing != mind {
            existing.isDefault = false
        }
    }

    private func countMinds(in context: NSManagedObjectContext) throws -> Int {
        let request: NSFetchRequest<Mind> = Mind.fetchRequest()
        let result = try context.count(for: request)
        return max(result, 0)
    }

    // MARK: - Migration

    func ensureDefaultMindExists() async throws {
        let hasDefaultMind = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            persistence.performBackgroundTask { context in
                do {
                    let request = Mind.fetchRequest()
                    request.predicate = NSPredicate(format: "isDefault == YES")
                    request.fetchLimit = 1
                    let count = try context.count(for: request)
                    continuation.resume(returning: count > 0)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        if !hasDefaultMind {
            _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<UUID, Error>) in
                persistence.performBackgroundTask { context in
                    do {
                        let defaultMind = Mind(context: context)
                        let mindID = UUID()
                        defaultMind.id = mindID
                        defaultMind.name = "All Minds"
                        defaultMind.iconName = "brain.head.profile"
                        defaultMind.isDefault = true
                        defaultMind.sortOrder = 0

                        let spaceRequest: NSFetchRequest<Space> = Space.fetchRequest()
                        let spaces = try context.fetch(spaceRequest)
                        for space in spaces {
                            space.mind = defaultMind
                        }

                        try context.save()
                        continuation.resume(returning: mindID)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }

            _ = await refresh(force: true)
        }
    }
}

// MARK: - Core Data Extensions

extension Mind {
    func toModel() -> MindModel {
        MindModel(
            id: id ?? UUID(),
            name: name ?? "Untitled",
            colorHex: colorHex,
            iconName: iconName,
            sortOrder: Int(sortOrder),
            isDefault: isDefault
        )
    }
}
