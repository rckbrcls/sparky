//
//  MemoryService.swift
//  i-cant-miss
//
//  Created by Codex on 09/03/24.
//

import Foundation
import Combine
@preconcurrency import CoreData
import os.log

@MainActor
final class MemoryService: ObservableObject {
    enum MemoryServiceError: Error {
        case memoryNotFound
        case validationFailed(String)
    }

    enum SortStrategy {
        case manual
        case updatedAtDescending
        case dueDateAscending
        case nextTriggerAscending
    }

    struct SpaceFilterKey: Hashable {
        let spaceIDs: Set<UUID>
        let statuses: Set<MemoryStatus>
        let includeCompleted: Bool
        let sort: SortStrategy

        init(spaceIDs: Set<UUID>,
             statuses: Set<MemoryStatus>,
             includeCompleted: Bool,
             sort: SortStrategy) {
            self.spaceIDs = spaceIDs
            self.statuses = statuses
            self.includeCompleted = includeCompleted
            self.sort = sort
        }
    }

    struct TimelineSection: Identifiable, Hashable {
        enum Kind: String, CaseIterable, Identifiable {
            case today
            case nextSevenDays
            case later
            case recurring

            var id: String { rawValue }

            var title: String {
                switch self {
                case .today: return "Today"
                case .nextSevenDays: return "Next 7 Days"
                case .later: return "Later"
                case .recurring: return "Recurring"
                }
            }

            var systemImage: String {
                switch self {
                case .today: return "sun.max.fill"
                case .nextSevenDays: return "calendar.badge.clock"
                case .later: return "calendar.badge.exclamationmark"
                case .recurring: return "arrow.triangle.2.circlepath"
                }
            }
        }

        let kind: Kind
        let memories: [MemoryModel]

        var id: Kind { kind }
    }

    @Published private(set) var memories: [MemoryModel] = []
    @Published private(set) var lastRefreshed: Date?

    private let persistence: PersistenceController
    private let spaceService: SpaceService
    private let attachmentStore: MemoryAttachmentStore
    private let cacheTTL: TimeInterval
    private var refreshTimer: AnyCancellable?
    private var cache: [SpaceFilterKey: [MemoryModel]] = [:]
    private var cacheTimestamps: [SpaceFilterKey: Date] = [:]
    private let logger = Logger(subsystem: "i-cant-miss", category: "MemoryService")
    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()

    var notificationScheduler: NotificationScheduler?
    var geofenceManager: GeofenceManager?

    init(persistence: PersistenceController,
         spaceService: SpaceService,
         attachmentStore: MemoryAttachmentStore,
         cacheTTL: TimeInterval = 30) {
        self.persistence = persistence
        self.spaceService = spaceService
        self.attachmentStore = attachmentStore
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
    func refresh(force: Bool) async -> [MemoryModel] {
        if !force,
           let last = lastRefreshed,
           Date().timeIntervalSince(last) < cacheTTL {
            return memories
        }

        let context = persistence.container.viewContext

        do {
            let entities = try fetchMemoryEntities(in: context)
            let combined = await buildMemoryModels(from: entities)

            memories = combined
            lastRefreshed = Date()
            cache.removeAll()
            cacheTimestamps.removeAll()

            if let scheduler = notificationScheduler {
                await scheduler.refreshNotifications(memories: combined)
            }
            geofenceManager?.sync(memories: combined)

            return combined
        } catch {
            logger.error("Failed to refresh memories: \(error.localizedDescription)")
            return memories
        }
    }

    func memories(in space: SpaceModel?,
                  includeDescendants: Bool = true,
                  statuses: Set<MemoryStatus> = [],
                  includeCompleted: Bool = true,
                  sort: SortStrategy = .updatedAtDescending) -> [MemoryModel] {
        let spaceIDs: Set<UUID>
        if let space {
            if space.isAllSpaces {
                spaceIDs = []
            } else if includeDescendants {
                spaceIDs = spaceService.descendantIDs(of: space)
            } else {
                spaceIDs = [space.id]
            }
        } else {
            spaceIDs = []
        }

        let key = SpaceFilterKey(
            spaceIDs: spaceIDs,
            statuses: statuses,
            includeCompleted: includeCompleted,
            sort: sort
        )

        if let cached = cache[key],
           let timestamp = cacheTimestamps[key],
           Date().timeIntervalSince(timestamp) < cacheTTL {
            return cached
        }

        var filtered = memories

        if !spaceIDs.isEmpty {
            filtered = filtered.filter { memory in
                guard let spaceID = memory.space?.id else { return false }
                return spaceIDs.contains(spaceID)
            }
        }

        if !statuses.isEmpty {
            filtered = filtered.filter { statuses.contains($0.status) }
        } else {
            filtered = filtered.filter { memory in
                switch memory.status {
                case .active:
                    return true
                case .completed:
                    return includeCompleted
                }
            }
        }

        let sorted = sortedMemories(filtered, using: sort)
        cache[key] = sorted
        cacheTimestamps[key] = Date()
        return sorted
    }

    func inboxMemories() -> [MemoryModel] {
        memories
            .filter { $0.isInbox }
            .sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned {
                    return lhs.isPinned && !rhs.isPinned
                }
                if let lhsDue = lhs.dueDate, let rhsDue = rhs.dueDate, lhsDue != rhsDue {
                    return lhsDue < rhsDue
                }
                return lhs.updatedAt > rhs.updatedAt
            }
    }

    func timelineMemories(referenceDate: Date = Date()) -> [MemoryModel] {
        memories
            .filter { memory in
                memory.status == .active && memory.hasTriggers && memory.nextFireDate(referenceDate: referenceDate) != nil
            }
            .sorted { lhs, rhs in
                let lhsDate = lhs.nextFireDate(referenceDate: referenceDate) ?? .distantFuture
                let rhsDate = rhs.nextFireDate(referenceDate: referenceDate) ?? .distantFuture
                if lhsDate != rhsDate {
                    return lhsDate < rhsDate
                }
                if lhs.priority != rhs.priority {
                    let lhsPriority = lhs.priority?.rawValue ?? -1
                    let rhsPriority = rhs.priority?.rawValue ?? -1
                    return lhsPriority > rhsPriority
                }
                return lhs.updatedAt > rhs.updatedAt
            }
    }

    func timelineSections(referenceDate: Date = Date()) -> [TimelineSection] {
        let calendar = Calendar.current
        let timelineMemories = timelineMemories(referenceDate: referenceDate)
        guard !timelineMemories.isEmpty else { return [] }

        var today: [MemoryModel] = []
        var nextSeven: [MemoryModel] = []
        var later: [MemoryModel] = []
        var recurring: [UUID: MemoryModel] = [:]

        let startOfDay = calendar.startOfDay(for: referenceDate)
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? referenceDate
        let sevenDaysOut = calendar.date(byAdding: .day, value: 7, to: startOfTomorrow) ?? referenceDate

        for memory in timelineMemories {
            guard let fireDate = memory.nextFireDate(referenceDate: referenceDate) else { continue }
            if calendar.isDate(fireDate, inSameDayAs: referenceDate) {
                today.append(memory)
            } else if fireDate < sevenDaysOut {
                nextSeven.append(memory)
            } else {
                later.append(memory)
            }

            if memory.hasRecurringTriggers {
                recurring[memory.id] = memory
            }
        }

        var sections: [TimelineSection] = []

        if !today.isEmpty {
            sections.append(TimelineSection(kind: .today, memories: sortedMemories(today, using: .nextTriggerAscending)))
        }

        if !nextSeven.isEmpty {
            sections.append(TimelineSection(kind: .nextSevenDays, memories: sortedMemories(nextSeven, using: .nextTriggerAscending)))
        }

        if !later.isEmpty {
            sections.append(TimelineSection(kind: .later, memories: sortedMemories(later, using: .nextTriggerAscending)))
        }

        if !recurring.isEmpty {
            let items = Array(recurring.values)
            sections.append(TimelineSection(kind: .recurring, memories: sortedMemories(items, using: .nextTriggerAscending)))
        }

        return sections
    }

    func searchMemories(query: String) -> [MemoryModel] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        return memories.filter { memory in
            if memory.title.localizedCaseInsensitiveContains(trimmed) {
                return true
            }
            if let body = memory.body, body.localizedCaseInsensitiveContains(trimmed) {
                return true
            }
            return false
        }
    }

    func memory(id: UUID) -> MemoryModel? {
        memories.first { $0.id == id }
    }

    func updateCachedMemory(_ memory: MemoryModel) {
        guard let index = memories.firstIndex(where: { $0.id == memory.id }) else { return }
        memories[index] = memory
        cache.removeAll()
        cacheTimestamps.removeAll()
    }

    func removeFromCache(memoryID: UUID) {
        memories.removeAll { $0.id == memoryID }
        cache.removeAll()
        cacheTimestamps.removeAll()
    }

    // MARK: - CRUD

    func createMemory(from draft: MemoryDraft) async throws -> MemoryModel {
        try await persist(draft: draft, isUpdate: false)
    }

    func updateMemory(from draft: MemoryDraft) async throws -> MemoryModel {
        try await persist(draft: draft, isUpdate: true)
    }

    func deleteMemory(id: UUID) async throws {
        try await withCheckedThrowingContinuation { continuation in
            persistence.performBackgroundTask { context in
                do {
                    guard let memory = try self.fetchMemory(by: id, context: context) else {
                        throw MemoryServiceError.memoryNotFound
                    }
                    context.delete(memory)
                    try context.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
        try await attachmentStore.deleteAllAttachments(for: id)
        await refresh(force: true)
    }

    func toggleCompletion(memoryID: UUID) async throws {
        guard let current = memory(id: memoryID) else {
            throw MemoryServiceError.memoryNotFound
        }
        let newStatus: MemoryStatus = current.status == .completed ? .active : .completed
        try await setStatus(memoryID: memoryID, status: newStatus)
    }

    func togglePin(memoryID: UUID) async throws {
        try await mutateMemory(memoryID: memoryID) { memory in
            memory.isPinned.toggle()
        }
    }

    func setStatus(memoryID: UUID, status: MemoryStatus) async throws {
        try await mutateMemory(memoryID: memoryID) { memory in
            memory.statusRaw = status.rawValue
        }
    }

    func setPriority(memoryID: UUID, priority: MemoryPriority?) async throws {
        try await mutateMemory(memoryID: memoryID) { memory in
            if let priority {
                memory.priorityRaw = NSNumber(value: priority.rawValue)
            } else {
                memory.priorityRaw = nil
            }
        }
    }

    func moveMemory(_ id: UUID, to space: SpaceModel?) async throws {
        try await mutateMemory(memoryID: id) { memory in
            if let space,
               space.id != SpaceModel.allSpacesIdentifier,
               let spaceEntity = try self.fetchSpace(by: space.id, context: memory.managedObjectContext ?? self.persistence.container.viewContext) {
                memory.space = spaceEntity
            } else {
                memory.space = nil
            }
        }
    }
}

// MARK: - Private helpers

private extension MemoryService {
    func persist(draft: MemoryDraft, isUpdate: Bool) async throws -> MemoryModel {
        let sanitizedTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitizedTitle.isEmpty else {
            throw MemoryServiceError.validationFailed("Title is required.")
        }

        let objectID: NSManagedObjectID = try await withCheckedThrowingContinuation { continuation in
            persistence.performBackgroundTask { context in
                do {
                    let memory: Memory
                    if isUpdate {
                        guard let existing = try self.fetchMemory(by: draft.id, context: context) else {
                            throw MemoryServiceError.memoryNotFound
                        }
                        memory = existing
                    } else {
                        memory = Memory(context: context)
                        memory.id = draft.id
                        memory.createdAt = Date()
                    }

                    try self.apply(draft: draft, to: memory, context: context, sanitizedTitle: sanitizedTitle)
                    try context.save()
                    continuation.resume(returning: memory.objectID)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        try await attachmentStore.replaceAttachments(for: draft.id, with: draft.attachments)
        let model = try await fetchMemoryFromViewContext(objectID: objectID)
        await refresh(force: true)
        return model
    }

    func apply(draft: MemoryDraft,
               to entity: Memory,
               context: NSManagedObjectContext,
               sanitizedTitle: String) throws {
        entity.title = sanitizedTitle
        entity.statusRaw = draft.status.rawValue
        entity.isPinned = draft.isPinned
        entity.priorityRaw = draft.priority.map { NSNumber(value: $0.rawValue) }
        entity.dueDate = draft.dueDate
        entity.autoCompleteOnChecklistCompletion = draft.autoCompleteOnChecklistCompletion
        entity.updatedAt = Date()

        entity.triggersData = try jsonEncoder.encode(draft.triggers)
        let bundle = MemoryDomain.MemoryContentBundle(contents: draft.contents)
        entity.contentsData = try jsonEncoder.encode(bundle)
        entity.body = draft.contents.aggregatedBodyText()

        if let spaceID = draft.spaceID,
           spaceID != SpaceModel.allSpacesIdentifier,
           let space = try fetchSpace(by: spaceID, context: context) {
            entity.space = space
        } else {
            entity.space = nil
        }
    }

    func fetchMemoryEntities(in context: NSManagedObjectContext) throws -> [Memory] {
        let request: NSFetchRequest<Memory> = Memory.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Memory.isPinned, ascending: false),
            NSSortDescriptor(keyPath: \Memory.updatedAt, ascending: false)
        ]
        request.returnsObjectsAsFaults = false
        request.relationshipKeyPathsForPrefetching = ["space"]
        return try context.fetch(request)
    }

    func buildMemoryModels(from entities: [Memory]) async -> [MemoryModel] {
        var unified: [MemoryModel] = []
        unified.reserveCapacity(entities.count)

        for entity in entities {
            let attachments = await attachmentStore.attachments(for: entity.id ?? UUID())
            do {
                let model = try makeMemoryModel(from: entity, attachments: attachments)
                unified.append(model)
            } catch {
                logger.error("Failed to decode memory \(entity.id?.uuidString ?? "<unknown>"): \(error.localizedDescription)")
            }
        }

        return unified.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned && !rhs.isPinned
            }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    func makeMemoryModel(from entity: Memory,
                         attachments: [MemoryModel.Attachment]) throws -> MemoryModel {
        let triggers = decodeTriggers(from: entity.triggersData)
        let decoded = decodeContents(for: entity, attachments: attachments)

        let memory = MemoryModel(
            id: entity.id ?? UUID(),
            title: entity.title ?? "Untitled",
            body: decoded.body,
            createdAt: entity.createdAt ?? Date(),
            updatedAt: entity.updatedAt ?? Date(),
            status: MemoryStatus(rawValue: entity.statusRaw ?? MemoryStatus.active.rawValue) ?? .active,
            isPinned: entity.isPinned,
            priority: entity.priorityRaw.map { MemoryPriority(rawValue: Int16(truncating: $0)) }.flatMap { $0 },
            dueDate: entity.dueDate,
            space: entity.space?.toModel(),
            triggers: triggers,
            checkItems: decoded.checkItems,
            autoCompleteOnChecklistCompletion: entity.autoCompleteOnChecklistCompletion,
            contents: decoded.contents,
            attachments: decoded.attachments
        )

        return memory
    }

    func decodeContents(for entity: Memory,
                        attachments: [MemoryModel.Attachment]) -> (contents: [MemoryContent], attachments: [MemoryModel.Attachment], checkItems: [CheckItemModel], body: String?) {
        guard let data = entity.contentsData,
              let bundle = try? jsonDecoder.decode(MemoryDomain.MemoryContentBundle.self, from: data) else {
            return ([], attachments, [], nil)
        }

        let contents = bundle.contents
        let referencedIDs = Set(contents.referencedAttachmentIDs())
        let filteredAttachments = referencedIDs.isEmpty ? attachments : attachments.filter { referencedIDs.contains($0.id) }
        let body = contents.aggregatedBodyText()
        let checkItems = contents.flattenedChecklistItems()
        return (contents, filteredAttachments, checkItems, body)
    }

    func decodeTriggers(from data: Data?) -> [MemoryTriggerModel] {
        guard let data else { return [] }
        do {
            return try jsonDecoder.decode([MemoryTriggerModel].self, from: data)
        } catch {
            logger.error("Failed to decode triggers: \(error.localizedDescription)")
            return []
        }
    }

    func mutateMemory(memoryID: UUID,
                      mutation: @escaping (Memory) throws -> Void) async throws {
        try await withCheckedThrowingContinuation { continuation in
            persistence.performBackgroundTask { context in
                do {
                    guard let memory = try self.fetchMemory(by: memoryID, context: context) else {
                        throw MemoryServiceError.memoryNotFound
                    }
                    try mutation(memory)
                    memory.updatedAt = Date()
                    try context.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
        await refresh(force: true)
    }

    func fetchMemory(by id: UUID, context: NSManagedObjectContext) throws -> Memory? {
        let request: NSFetchRequest<Memory> = Memory.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    func fetchMemoryFromViewContext(objectID: NSManagedObjectID) async throws -> MemoryModel {
        let memory: Memory = try await withCheckedThrowingContinuation { continuation in
            let viewContext = persistence.container.viewContext
            viewContext.perform {
                do {
                    guard let memory = try viewContext.existingObject(with: objectID) as? Memory else {
                        throw MemoryServiceError.memoryNotFound
                    }
                    continuation.resume(returning: memory)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        let attachments = await attachmentStore.attachments(for: memory.id ?? UUID())
        return try makeMemoryModel(from: memory, attachments: attachments)
    }

    func fetchSpace(by id: UUID, context: NSManagedObjectContext) throws -> Space? {
        let request: NSFetchRequest<Space> = Space.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    func sortedMemories(_ memories: [MemoryModel], using strategy: SortStrategy) -> [MemoryModel] {
        switch strategy {
        case .manual:
            return memories.sorted { lhs, rhs in
                let lhsOrder = lhs.space?.sortOrder ?? Int.max
                let rhsOrder = rhs.space?.sortOrder ?? Int.max
                if lhsOrder != rhsOrder {
                    return lhsOrder < rhsOrder
                }
                return lhs.updatedAt > rhs.updatedAt
            }

        case .updatedAtDescending:
            return memories.sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned {
                    return lhs.isPinned && !rhs.isPinned
                }
                return lhs.updatedAt > rhs.updatedAt
            }

        case .dueDateAscending:
            return memories.sorted { lhs, rhs in
                switch (lhs.dueDate, rhs.dueDate) {
                case let (lhsDue?, rhsDue?):
                    if lhsDue != rhsDue { return lhsDue < rhsDue }
                    return lhs.updatedAt > rhs.updatedAt
                case (nil, nil):
                    return lhs.updatedAt > rhs.updatedAt
                case (nil, _?):
                    return false
                case (_?, nil):
                    return true
                }
            }

        case .nextTriggerAscending:
            return memories.sorted { lhs, rhs in
                let lhsDate = lhs.nextFireDate() ?? .distantFuture
                let rhsDate = rhs.nextFireDate() ?? .distantFuture
                if lhsDate != rhsDate { return lhsDate < rhsDate }
                if lhs.priority != rhs.priority {
                    let lhsPriority = lhs.priority?.rawValue ?? -1
                    let rhsPriority = rhs.priority?.rawValue ?? -1
                    return lhsPriority > rhsPriority
                }
                return lhs.updatedAt > rhs.updatedAt
            }
        }
    }
}
