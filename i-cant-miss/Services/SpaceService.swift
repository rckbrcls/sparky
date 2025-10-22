//
//  SpaceService.swift
//  i-cant-miss
//
//  Created by Codex on 09/03/24.
//

import Combine
@preconcurrency import CoreData
import os.log

@MainActor
final class SpaceService: ObservableObject {
    @Published private(set) var spaces: [SpaceModel] = []
    @Published private(set) var lastRefreshed: Date?

    private let persistence: PersistenceController
    private let cacheTTL: TimeInterval
    private var refreshTimer: AnyCancellable?
    private var spaceIndex: [UUID: SpaceModel] = [:]
    private let logger = Logger(subsystem: "i-cant-miss", category: "SpaceService")

    init(persistence: PersistenceController, cacheTTL: TimeInterval = 30) {
        self.persistence = persistence
        self.cacheTTL = cacheTTL

        configureAutoRefresh()
        Task { await refresh(force: true) }
    }

    deinit {
        refreshTimer?.cancel()
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
    func refresh(force: Bool) async -> [SpaceModel] {
        if !force,
           let last = lastRefreshed,
           Date().timeIntervalSince(last) < cacheTTL {
            return spaces
        }

        let context = persistence.container.viewContext
        let request: NSFetchRequest<Folder> = Folder.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Folder.sortOrder, ascending: true),
            NSSortDescriptor(keyPath: \Folder.name, ascending: true)
        ]
        request.returnsObjectsAsFaults = false

        do {
            let folders = try context.fetch(request)
            var nextSpaces: [SpaceModel] = [SpaceModel.inbox]

            for folder in folders {
                let folderModel = folder.toModel()
                let space = folderModel.toSpace(parentID: nil, childIDs: [])
                nextSpaces.append(space)
            }

            // Deduplicate by id to avoid duplicates when inbox exists in Core Data.
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

            spaces = orderedSpaces
            lastRefreshed = Date()
            rebuildIndex()
            return orderedSpaces
        } catch {
            logger.error("Failed to refresh spaces: \(error.localizedDescription)")
            return spaces
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

    func resolveSpace(for folder: FolderModel?) -> SpaceModel {
        guard let folder else {
            return spaceIndex[SpaceModel.inbox.id] ?? SpaceModel.inbox
        }

        if let cached = spaceIndex[folder.id] {
            return cached
        }

        // The folder may not have been materialized yet (e.g. newly created in memory).
        let derived = folder.toSpace()
        spaceIndex[derived.id] = derived
        return derived
    }

    func defaultSpace() -> SpaceModel {
        spaceIndex[SpaceModel.inbox.id] ?? SpaceModel.inbox
    }

    func rootSpaces() -> [SpaceModel] {
        spaces.filter { $0.parentID == nil }
    }

    func children(of parent: SpaceModel) -> [SpaceModel] {
        parent.childIDs.compactMap { spaceIndex[$0] }
            .sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder {
                    return lhs.sortOrder < rhs.sortOrder
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    func isValidMove(space: SpaceModel, targetParentID: UUID?) -> Bool {
        guard let targetParentID else { return true }
        guard let target = spaceIndex[targetParentID] else { return false }
        return !target.isAncestor(of: space) { [weak self] id in
            self?.spaceIndex[id]
        }
    }

    func descendantIDs(of space: SpaceModel) -> Set<UUID> {
        var visited: Set<UUID> = []
        var stack: [UUID] = [space.id]

        while let currentID = stack.popLast() {
            guard !visited.contains(currentID) else { continue }
            visited.insert(currentID)
            guard let node = spaceIndex[currentID] else { continue }
            stack.append(contentsOf: node.childIDs)
        }

        return visited
    }
}
