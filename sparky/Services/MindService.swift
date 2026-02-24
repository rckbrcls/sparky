//
//  MindService.swift
//  sparky
//

import Foundation
import Combine
import SwiftData
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
    @Published private(set) var minds: [Mind] = []
    @Published private(set) var tags: [Tag] = []
    @Published private(set) var lastRefreshed: Date?
    @Published private(set) var lastTagsRefresh: Date?

    private let dataController: DataController
    private let cacheTTL: TimeInterval
    private var refreshTask: Task<Void, Never>?
    private var mindIndex: [UUID: Mind] = [:]
    private let logger = Logger(subsystem: "sparky", category: "MindService")

    init(dataController: DataController, cacheTTL: TimeInterval = 30) {
        self.dataController = dataController
        self.cacheTTL = cacheTTL

        loadInitialData()
        configureAutoRefresh()
    }

    deinit {
        refreshTask?.cancel()
    }

    private func loadInitialData() {
        let context = dataController.modelContext

        do {
            var descriptor = FetchDescriptor<Mind>()
            descriptor.includePendingChanges = true

            let fetched = try context.fetch(descriptor)

            removeSentinelMinds(fetched, context: context)

            let mindResults = fetched
                .filter { !$0.isAllMinds && !$0.isLimbo }
                .sorted { lhs, rhs in
                    if lhs.sortOrder != rhs.sortOrder {
                        return lhs.sortOrder < rhs.sortOrder
                    }
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }

            self.minds = mindResults
            self.lastRefreshed = Date()
            rebuildIndex()
        } catch {
            logger.error("Failed to load initial minds: \(error.localizedDescription)")
        }
    }

    private func configureAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(self?.cacheTTL ?? 30))
                await self?.refresh(force: false)
            }
        }
    }

    @discardableResult
    func refresh(force: Bool) async -> [Mind] {
        if !force,
           let last = lastRefreshed,
           Date().timeIntervalSince(last) < cacheTTL {
            return minds
        }

        let context = dataController.modelContext

        do {
            var descriptor = FetchDescriptor<Mind>()
            descriptor.includePendingChanges = true

            let fetched = try context.fetch(descriptor)

            removeSentinelMinds(fetched, context: context)

            let mindResults = fetched
                .filter { !$0.isAllMinds && !$0.isLimbo }
                .sorted { lhs, rhs in
                    if lhs.sortOrder != rhs.sortOrder {
                        return lhs.sortOrder < rhs.sortOrder
                    }
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }

            self.minds = mindResults
            lastRefreshed = Date()
            rebuildIndex()
            return mindResults
        } catch {
            logger.error("Failed to refresh minds: \(error.localizedDescription)")
            return minds
        }
    }

    @discardableResult
    func refreshTags(force: Bool) async -> [Tag] {
        if !force,
           let last = lastTagsRefresh,
           Date().timeIntervalSince(last) < cacheTTL {
            return tags
        }

        do {
            let fetched = try fetchTags(in: dataController.modelContext)
            self.tags = fetched
            self.lastTagsRefresh = Date()
            return fetched
        } catch {
            logger.error("Failed to refresh tags: \(error.localizedDescription)")
            return tags
        }
    }

    private func rebuildIndex() {
        mindIndex.removeAll(keepingCapacity: true)
        for mind in minds {
            mindIndex[mind.id] = mind
        }
    }

    func mind(id: UUID) -> Mind? {
        mindIndex[id]
    }

    func defaultMind() -> Mind? {
        minds.first(where: { $0.isDefault })
    }

    // MARK: - CRUD Operations

    func createMind(
        name: String,
        colorHex: String?,
        iconName: String?,
        isDefault: Bool,
        parent: Mind? = nil
    ) async throws -> Mind {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MindServiceError.validationFailed("Mind name is required")
        }

        let context = dataController.modelContext

        if isDefault {
            try clearDefaultMind(context: context)
        }

        let mind = Mind(
            id: UUID(),
            name: name,
            colorHex: colorHex,
            iconName: iconName,
            sortOrder: countMinds(in: context),
            isDefault: isDefault,
            parent: parent
        )

        context.insert(mind)
        dataController.save()

        await refresh(force: true)
        return mind
    }

    func updateMind(_ mind: Mind) async throws -> Mind {
        let context = dataController.modelContext

        guard !mind.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MindServiceError.validationFailed("Mind name is required")
        }

        if mind.isDefault {
            try clearDefaultMind(context: context, excluding: mind)
        }

        dataController.save()

        await refresh(force: true)
        return mind
    }

    func reorderMinds(_ orderedIDs: [UUID]) async throws {
        let context = dataController.modelContext

        for (index, id) in orderedIDs.enumerated() {
            if let mind = try fetchMind(by: id, context: context) {
                mind.sortOrder = index
            }
        }

        dataController.save()
        await refresh(force: true)
    }

    func deleteMind(_ mind: Mind) async throws {
        guard !mind.isDefault else {
            throw MindServiceError.cannotDeleteDefaultMind
        }

        let context = dataController.modelContext

        func recursivelyDelete(mind: Mind) {
            if let children = mind.children {
                for child in children {
                    recursivelyDelete(mind: child)
                }
            }
            context.delete(mind)
        }

        recursivelyDelete(mind: mind)

        dataController.save()

        _ = await refresh(force: true)
    }

    // MARK: - Tag Operations

    func createTag(name: String, colorHex: String?) async throws -> Tag {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MindServiceError.validationFailed("Tag name is required")
        }

        let context = dataController.modelContext

        let tag = Tag(
            id: UUID(),
            name: name,
            colorHex: colorHex
        )

        context.insert(tag)
        dataController.save()

        await refreshTags(force: true)
        return tag
    }

    func deleteTag(id: UUID) async throws {
        let context = dataController.modelContext

        guard let tag = try fetchTag(by: id, context: context) else {
            throw MindServiceError.validationFailed("Tag not found")
        }

        context.delete(tag)
        dataController.save()

        await refreshTags(force: true)
    }

    // MARK: - Internal fetch helpers

    func fetchMind(by id: UUID, context: ModelContext) throws -> Mind? {
        var descriptor = FetchDescriptor<Mind>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func fetchTag(by id: UUID, context: ModelContext) throws -> Tag? {
        var descriptor = FetchDescriptor<Tag>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func fetchTags(in context: ModelContext) throws -> [Tag] {
        let descriptor = FetchDescriptor<Tag>()
        let results = try context.fetch(descriptor)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return results
    }

    private func removeSentinelMinds(_ minds: [Mind], context: ModelContext) {
        let sentinelIDs: Set<UUID> = [Mind.allMindsIdentifier, Mind.limboIdentifier]
        for mind in minds where sentinelIDs.contains(mind.id) {
            logger.warning("Removing accidentally persisted sentinel mind: \(mind.id)")
            context.delete(mind)
        }
        dataController.save()
    }

    private func clearDefaultMind(context: ModelContext, excluding mind: Mind? = nil) throws {
        let descriptor = FetchDescriptor<Mind>(
            predicate: #Predicate { $0.isDefault == true }
        )
        let defaults = try context.fetch(descriptor)
        for existing in defaults where existing.id != mind?.id {
            existing.isDefault = false
        }
    }

    private func countMinds(in context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<Mind>()
        do {
            return try context.fetchCount(descriptor)
        } catch {
            return 0
        }
    }
}
