//
//  LobeService.swift
//  sparky
//
//  Created by Codex on 09/03/24.
//

import Foundation
import Combine
import SwiftData
import os.log

enum LobeServiceError: LocalizedError {
    case cannotDeleteDefaultLobe
    case lobeNotFound
    case tagNotFound
    case validationFailed(String)

    var errorDescription: String? {
        switch self {
        case .cannotDeleteDefaultLobe:
            return "Default lobes cannot be deleted."
        case .lobeNotFound:
            return "The lobe could not be found."
        case .tagNotFound:
            return "The tag could not be found."
        case .validationFailed(let message):
            return message
        }
    }
}

@MainActor
final class LobeService: ObservableObject {
    @Published private(set) var lobes: [Space] = []
    @Published private(set) var tags: [Tag] = []
    @Published private(set) var lastRefreshed: Date?

    private let dataController: DataController
    private let cacheTTL: TimeInterval
    private var refreshTimer: AnyCancellable?
    private var lobeIndex: [UUID: Space] = [:]
    private let logger = Logger(subsystem: "sparky", category: "LobeService")
    private var lastTagsRefresh: Date?

    init(dataController: DataController, cacheTTL: TimeInterval = 30) {
        self.dataController = dataController
        self.cacheTTL = cacheTTL

        loadInitialData()
        configureAutoRefresh()
    }

    deinit {
        refreshTimer?.cancel()
    }

    private func loadInitialData() {
        let context = dataController.modelContext

        do {
            // Load spaces
            var spaceDescriptor = FetchDescriptor<Space>()
            spaceDescriptor.includePendingChanges = true

            let spaceResults = try context.fetch(spaceDescriptor)
                .sorted { lhs, rhs in
                    if lhs.sortOrder != rhs.sortOrder {
                        return lhs.sortOrder < rhs.sortOrder
                    }
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }

            self.lobes = spaceResults

            // Load tags
            var tagDescriptor = FetchDescriptor<Tag>()
            tagDescriptor.includePendingChanges = true

            let tagResults = try context.fetch(tagDescriptor)
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            self.tags = tagResults
        } catch {
            logger.error("Failed to load initial lobes/tags: \(error.localizedDescription)")
        }

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
    func refresh(force: Bool) async -> [Space] {
        if !force,
           let last = lastRefreshed,
           Date().timeIntervalSince(last) < cacheTTL {
            return lobes
        }

        let context = dataController.modelContext

        do {
            var descriptor = FetchDescriptor<Space>()
            descriptor.includePendingChanges = true

            let spaces = try context.fetch(descriptor)
                .sorted { lhs, rhs in
                    if lhs.sortOrder != rhs.sortOrder {
                        return lhs.sortOrder < rhs.sortOrder
                    }
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }

            self.lobes = spaces
            lastRefreshed = Date()
            rebuildIndex()
            return spaces
        } catch {
            logger.error("Failed to refresh lobes: \(error.localizedDescription)")
            return lobes
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
        lobeIndex.removeAll(keepingCapacity: true)
        for lobe in lobes {
            lobeIndex[lobe.id] = lobe
        }
    }

    func lobe(id: UUID) -> Space? {
        lobeIndex[id]
    }

    func defaultLobe() -> Space? {
        lobes.first(where: { $0.isDefault })
    }

    func memoryIDs(in lobe: Space) -> [UUID] {
        let memories = lobe.memories ?? []
        return memories.map { $0.id }
    }

    // MARK: - CRUD Operations

    func createLobe(
        name: String,
        colorHex: String?,
        iconName: String?,
        isDefault: Bool,
        mindID: UUID? = nil
    ) async throws -> Space {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LobeServiceError.validationFailed("Lobe name is required")
        }

        let context = dataController.modelContext

        if isDefault {
            try clearDefaultSpace(context: context)
        }

        var mindEntity: Mind?
        if let mindID = mindID {
            var descriptor = FetchDescriptor<Mind>(
                predicate: #Predicate { $0.id == mindID }
            )
            descriptor.fetchLimit = 1
            mindEntity = try context.fetch(descriptor).first
        }

        let space = Space(
            id: UUID(),
            name: name,
            colorHex: colorHex,
            iconName: iconName,
            sortOrder: countSpaces(in: context),
            isDefault: isDefault,
            mind: mindEntity
        )

        context.insert(space)
        dataController.save()

        await refresh(force: true)
        return space
    }

    func updateLobe(_ space: Space) async throws -> Space {
        let context = dataController.modelContext

        guard !space.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LobeServiceError.validationFailed("Lobe name is required")
        }

        if space.isDefault {
            try clearDefaultSpace(context: context, excluding: space)
        }

        dataController.save()

        await refresh(force: true)
        return space
    }

    func reorderLobes(_ orderedIDs: [UUID]) async throws {
        let context = dataController.modelContext

        for (index, id) in orderedIDs.enumerated() {
            if let space = try fetchSpace(by: id, context: context) {
                space.sortOrder = index
            }
        }

        dataController.save()
        await refresh(force: true)
    }

    func deleteLobe(_ lobe: Space, deleteMemories: Bool = false, memoryService: MemoryService? = nil) async throws {
        guard !lobe.isDefault else {
            throw LobeServiceError.cannotDeleteDefaultLobe
        }

        if deleteMemories, let memoryService = memoryService {
            let ids = memoryIDs(in: lobe)
            try await memoryService.deleteMemories(ids: Set(ids))
        }

        let context = dataController.modelContext

        if deleteMemories && memoryService == nil {
            let memories = lobe.memories ?? []
            for memory in memories {
                context.delete(memory)
            }
        }

        context.delete(lobe)
        dataController.save()

        _ = await refresh(force: true)

        if let memoryService = memoryService {
            _ = await memoryService.refresh(force: true)
        }
    }

    // MARK: - Tag Operations

    func createTag(name: String, colorHex: String?) async throws -> Tag {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LobeServiceError.validationFailed("Tag name is required")
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
            throw LobeServiceError.tagNotFound
        }

        context.delete(tag)
        dataController.save()

        await refreshTags(force: true)
    }

    // MARK: - Internal fetch helpers

    func fetchSpace(by id: UUID, context: ModelContext) throws -> Space? {
        var descriptor = FetchDescriptor<Space>(
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

    private func clearDefaultSpace(context: ModelContext, excluding space: Space? = nil) throws {
        let descriptor = FetchDescriptor<Space>(
            predicate: #Predicate { $0.isDefault == true }
        )
        let defaults = try context.fetch(descriptor)
        for existing in defaults where existing.id != space?.id {
            existing.isDefault = false
        }
    }

    private func countSpaces(in context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<Space>()
        do {
            return try context.fetchCount(descriptor)
        } catch {
            return 0
        }
    }
}
