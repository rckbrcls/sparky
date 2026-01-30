//
//  MindService.swift
//  i-cant-miss
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
    @Published private(set) var lastRefreshed: Date?

    private let dataController: DataController
    private let cacheTTL: TimeInterval
    private var refreshTimer: AnyCancellable?
    private var mindIndex: [UUID: Mind] = [:]
    private let logger = Logger(subsystem: "i-cant-miss", category: "MindService")

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
            var descriptor = FetchDescriptor<Mind>()
            descriptor.includePendingChanges = true

            let mindResults = try context.fetch(descriptor)
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

            let mindResults = try context.fetch(descriptor)
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

    func spaceIDs(in mind: Mind) -> [UUID] {
        let spaces = mind.spaces ?? []
        return spaces.map { $0.id }
    }

    // MARK: - CRUD Operations

    func createMind(
        name: String,
        colorHex: String?,
        iconName: String?,
        isDefault: Bool
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
            isDefault: isDefault
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
        context.delete(mind)
        dataController.save()

        _ = await refresh(force: true)
    }

    // MARK: - Internal fetch helpers

    func fetchMind(by id: UUID, context: ModelContext) throws -> Mind? {
        var descriptor = FetchDescriptor<Mind>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
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

    // MARK: - Migration

    func ensureDefaultMindExists() async throws {
        let context = dataController.modelContext

        let descriptor = FetchDescriptor<Mind>(
            predicate: #Predicate { $0.isDefault == true }
        )
        let count = try context.fetchCount(descriptor)

        if count == 0 {
            let defaultMind = Mind(
                id: UUID(),
                name: "All Minds",
                iconName: "brain.head.profile",
                sortOrder: 0,
                isDefault: true
            )

            let spaceDescriptor = FetchDescriptor<Space>()
            let spaces = try context.fetch(spaceDescriptor)
            for space in spaces {
                space.mind = defaultMind
            }

            context.insert(defaultMind)
            dataController.save()

            _ = await refresh(force: true)
        }
    }
}
