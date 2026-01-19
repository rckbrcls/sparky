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
        case updatedAtAscending
        case createdAtDescending
        case createdAtAscending
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

    var triggerExecutorCoordinator: TriggerExecutorCoordinator?

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

    /// Notifica o executor sequencial sobre a conclusão de uma memória
    private func notifySequentialExecutor(memoryID: UUID) async {
        guard let coordinator = triggerExecutorCoordinator else { return }
        await coordinator.sequential.handleMemoryCompletion(memoryID: memoryID)
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

            if let coordinator = triggerExecutorCoordinator {
                await coordinator.sync(memories: combined)
            }

            return combined
        } catch {
            logger.error("Failed to refresh memories: \(error.localizedDescription)")
            return memories
        }
    }

    func memories(in space: SpaceModel?,
                  statuses: Set<MemoryStatus> = [],
                  includeCompleted: Bool = true,
                  sort: SortStrategy = .updatedAtDescending) -> [MemoryModel] {
        let spaceIDs: Set<UUID>
        if let space {
            if space.isAllSpaces {
                spaceIDs = []
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
                return lhs.updatedAt > rhs.updatedAt
            }
    }

    func scheduledMemories(referenceDate: Date = Date()) -> [MemoryModel] {
        let result = memories
            .filter { memory in
                // Deve ter pelo menos um trigger scheduled ativo com fireDate
                // Memórias devem aparecer no calendário independente do status ou se a hora passou
                let hasScheduledWithFireDate = memory.triggers.contains {
                    $0.type == .scheduled && $0.isActive && $0.fireDate != nil
                }

                return hasScheduledWithFireDate
            }
            .sorted { lhs, rhs in
                let lhsDate = lhs.nextFireDate(referenceDate: referenceDate)
                    ?? lhs.triggers.first(where: { $0.type == .scheduled && $0.fireDate != nil })?.fireDate
                    ?? .distantFuture
                let rhsDate = rhs.nextFireDate(referenceDate: referenceDate)
                    ?? rhs.triggers.first(where: { $0.type == .scheduled && $0.fireDate != nil })?.fireDate
                    ?? .distantFuture
                if lhsDate != rhsDate {
                    return lhsDate < rhsDate
                }
                return lhs.updatedAt > rhs.updatedAt
            }

        return result
    }


    func nonScheduledMemories() -> [MemoryModel] {
        return memories
            .filter { memory in
                guard memory.status == .active else { return false }
                guard memory.space == nil else { return false } // Memórias com space não aparecem na aba Triggers

                // Não deve ter nenhum trigger scheduled ativo
                let hasScheduled = memory.triggers.contains {
                    $0.type == .scheduled && $0.isActive
                }

                return !hasScheduled
            }
    }

    func memoriesWithLocationOnly() -> [MemoryModel] {
        return nonScheduledMemories()
            .filter { memory in
                let activeTriggers = memory.triggers.filter { $0.isActive }
                guard !activeTriggers.isEmpty else { return false }

                // Deve ter apenas triggers location
                let hasLocation = activeTriggers.contains { $0.type == .location }
                let hasOtherTypes = activeTriggers.contains { $0.type != .location }

                return hasLocation && !hasOtherTypes
            }
    }



    func memoriesWithSequentialOnly() -> [MemoryModel] {
        return nonScheduledMemories()
            .filter { memory in
                let activeTriggers = memory.triggers.filter { $0.isActive }
                guard !activeTriggers.isEmpty else { return false }

                // Deve ter apenas triggers sequential
                let hasSequential = activeTriggers.contains { $0.type == .sequential }
                let hasOtherTypes = activeTriggers.contains { $0.type != .sequential }

                return hasSequential && !hasOtherTypes
            }
    }

    func memoriesWithoutTriggers() -> [MemoryModel] {
        return memories
            .filter { memory in
                guard memory.status == .active else { return false }
                return !memory.hasTriggers
            }
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
        // Ensure we're on the main thread since memories is @Published
        assert(Thread.isMainThread, "updateCachedMemory must be called on main thread")
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

    func deleteMemories(ids: [UUID]) async throws {
        for id in ids {
            try await deleteMemory(id: id)
        }
    }

    func toggleCompletion(memoryID: UUID) async throws {
        guard let current = memory(id: memoryID) else {
            throw MemoryServiceError.memoryNotFound
        }
        let newStatus: MemoryStatus = current.status == .completed ? .active : .completed
        try await setStatus(memoryID: memoryID, status: newStatus)

        // Se a memória foi completada, notificar executor sequencial
        if newStatus == .completed {
            await notifySequentialExecutor(memoryID: memoryID)
        }
    }

    /// Toggles completion for a specific date (for recurring memories)
    /// - Parameters:
    ///   - memoryID: The ID of the memory to toggle
    ///   - date: The specific date to mark as completed/uncompleted
    func toggleCompletionForDate(memoryID: UUID, date: Date) async throws {
        guard let current = memory(id: memoryID) else {
            throw MemoryServiceError.memoryNotFound
        }

        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)

        var updatedDates = current.completedDates

        // Check if this date is already marked as completed
        if let index = updatedDates.firstIndex(where: { calendar.isDate($0, inSameDayAs: normalizedDate) }) {
            // Remove the date (uncomplete)
            updatedDates.remove(at: index)
        } else {
            // Add the date (complete)
            updatedDates.append(normalizedDate)
        }

        // Update the memory's contentsData with the new completedDates
        try await mutateContentsData(memoryID: memoryID) { bundle in
            bundle.completedDates = updatedDates.isEmpty ? nil : updatedDates
        }
    }

    func togglePin(memoryID: UUID) async throws {
        try await mutateMemory(memoryID: memoryID) { memory in
            memory.isPinned.toggle()
        }
    }
    
    func toggleChecklistItemCompletion(memoryID: UUID, itemID: UUID) async throws {
        try await mutateContentsData(memoryID: memoryID) { bundle in
            guard var checkItems = bundle.checkItems else { return }
            guard let index = checkItems.firstIndex(where: { $0.id == itemID }) else { return }
            
            let item = checkItems[index]
            let newCompletedState = !item.isCompleted
            let newCompletedAt = newCompletedState ? Date() : nil
            
            checkItems[index] = CheckItemModel(
                id: item.id,
                title: item.title,
                detail: item.detail,
                isCompleted: newCompletedState,
                sortOrder: item.sortOrder,
                createdAt: item.createdAt,
                updatedAt: Date(),
                completedAt: newCompletedAt
            )
            
            bundle.checkItems = checkItems
        }
    }

    func setStatus(memoryID: UUID, status: MemoryStatus) async throws {
        try await mutateMemory(memoryID: memoryID) { memory in
            memory.statusRaw = status.rawValue
            // Remover pin quando o memory é marcado como concluído
            if status == .completed {
                memory.isPinned = false
            }
        }

        // Se a memória foi completada, notificar executor sequencial
        if status == .completed {
            await notifySequentialExecutor(memoryID: memoryID)
        }
    }

    func moveMemory(_ id: UUID, to space: SpaceModel?) async throws {
        try await mutateMemory(memoryID: id) { memory in
            if let space,
               space.id != SpaceModel.allSpacesIdentifier,
               space.id != SpaceModel.inboxSpacesIdentifier,
               let spaceEntity = try self.fetchSpace(by: space.id, context: memory.managedObjectContext ?? self.persistence.container.viewContext) {
                memory.space = spaceEntity
            } else {
                memory.space = nil
            }
        }
    }

    func duplicateMemory(memoryID: UUID) async throws {
        guard let memory = memory(id: memoryID) else {
            throw MemoryServiceError.memoryNotFound
        }

        // 1. Duplicate Attachments
        // We reuse the same data, but create new Attachment records with new IDs so they can be managed independently
        // However, MemoryAttachmentStore handles attachments by ID.
        // If we want "independent" attachments (e.g. deleting one doesn't delete the other's), we need new IDs and new files.
        // For simplicity and storage efficiency here, we might just reference the same attachments if they were shared?
        // BUT, MemoryModel has `attachments: [Attachment]`, where Attachment has an ID.
        // MemoryDraft takes `attachments: [Attachment]`.
        // Let's create new Attachment objects with new IDs but SAME data.
        let newAttachments = memory.attachments.map { attachment in
            MemoryModel.Attachment(
                id: UUID(), // New ID
                kind: attachment.kind,
                data: attachment.data, // Copying data (might be expensive if large, but safe)
                createdAt: Date(),
                url: attachment.url,
                filename: attachment.filename
            )
        }

        // 2. Duplicate CheckItems (Reset completion)
        let newCheckItems = memory.checkItems.map { item in
            CheckItemDraft(
                id: UUID(),
                title: item.title,
                detail: item.detail ?? "",
                isCompleted: false, // Reset completion
                sortOrder: item.sortOrder,
                createdAt: Date(),
                completedAt: nil
            )
        }

        // 3. Duplicate Triggers
        let newTriggers = memory.triggers.map { trigger in
            MemoryTriggerModel(
                id: UUID(),
                type: trigger.type,
                fireDate: trigger.fireDate,
                startDate: trigger.startDate,
                recurrenceRule: trigger.recurrenceRule,
                timeZoneIdentifier: trigger.timeZoneIdentifier,
                weekdayMask: trigger.weekdayMask,
                isActive: trigger.isActive,
                location: trigger.location,
                sequential: trigger.sequential,
                spacedStage: trigger.spacedStage,
                lastReviewDate: nil,
                ignoreCount: 0
            )
        }

        // 4. Create Draft
        let draft = MemoryDraft(
            id: UUID(),
            title: memory.title, // Title copy
            status: .active, // Reset status to active
            isPinned: memory.isPinned,
            dueDate: memory.dueDate,
            spaceID: memory.space?.id,
            triggers: newTriggers,
            note: memory.note, // Fixed field
            checkItems: newCheckItems,
            photoAttachmentIDs: [], // These will be populated by apply() based on new attachments if we passed them?
            // Actually MemoryDraft `attachments` arg is what persists new attachments.
            // But we also have `photoAttachmentIDs` etc.
            // Let's look at `persist` method. It calls `attachmentStore.replaceAttachments`.
            // So we just need to pass the new attachments in `attachments` array.
            // AND we need to make sure the ID arrays match these new IDs if we want them categorized?
            // `decodeContents` in MemoryService uses `bundle.photoAttachmentIDs` etc.
            // If we pass `attachments` in draft, `persist` saves them.
            // BUT `apply` encodes `bundle` with `draft.photoAttachmentIDs`.
            // So we MUST map the new IDs to the correct arrays.
            linkAttachmentIDs: [],
            audioAttachmentIDs: [],
            fileAttachmentIDs: [],
            attachments: newAttachments,
            autoCompleteOnChecklistCompletion: memory.autoCompleteOnChecklistCompletion
        )

        // Populate specific ID arrays based on kind
        var draftWithIDs = draft
        draftWithIDs.photoAttachmentIDs = newAttachments.filter { $0.kind == .photo }.map { $0.id }
        draftWithIDs.linkAttachmentIDs = newAttachments.filter { $0.kind == .link }.map { $0.id }
        draftWithIDs.audioAttachmentIDs = newAttachments.filter { $0.kind == .audio }.map { $0.id }
        draftWithIDs.fileAttachmentIDs = newAttachments.filter { $0.kind == .file }.map { $0.id }

        // 5. Create
        _ = try await createMemory(from: draftWithIDs)
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
        entity.dueDate = draft.dueDate
        entity.autoCompleteOnChecklistCompletion = draft.autoCompleteOnChecklistCompletion
        entity.updatedAt = Date()

        entity.triggersData = try jsonEncoder.encode(draft.triggers)

        // Convert CheckItemDrafts to CheckItemModels for persistence
        let checkItemModels = draft.checkItems.enumerated().map { index, item in
            CheckItemModel(
                id: item.id,
                title: item.title,
                detail: item.detail.isEmpty ? nil : item.detail,
                isCompleted: item.isCompleted,
                sortOrder: index,
                createdAt: item.createdAt,
                updatedAt: item.completedAt ?? item.createdAt,
                completedAt: item.completedAt
            )
        }

        // Create the new content bundle with fixed fields
        let bundle = MemoryDomain.MemoryContentBundle(
            note: draft.note,
            checkItems: checkItemModels.isEmpty ? nil : checkItemModels,
            photoAttachmentIDs: draft.photoAttachmentIDs.isEmpty ? nil : draft.photoAttachmentIDs,
            linkAttachmentIDs: draft.linkAttachmentIDs.isEmpty ? nil : draft.linkAttachmentIDs,
            audioAttachmentIDs: draft.audioAttachmentIDs.isEmpty ? nil : draft.audioAttachmentIDs,
            fileAttachmentIDs: draft.fileAttachmentIDs.isEmpty ? nil : draft.fileAttachmentIDs,
            completedDates: draft.completedDates.isEmpty ? nil : draft.completedDates
        )
        entity.contentsData = try jsonEncoder.encode(bundle)
        entity.body = draft.note

        if let spaceID = draft.spaceID,
           spaceID != SpaceModel.allSpacesIdentifier,
           spaceID != SpaceModel.inboxSpacesIdentifier,
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
            dueDate: entity.dueDate,
            space: entity.space?.toModel(),
            triggers: triggers,
            checkItems: decoded.checkItems,
            autoCompleteOnChecklistCompletion: entity.autoCompleteOnChecklistCompletion,
            note: decoded.note,
            photoAttachmentIDs: decoded.photoAttachmentIDs,
            linkAttachmentIDs: decoded.linkAttachmentIDs,
            audioAttachmentIDs: decoded.audioAttachmentIDs,
            fileAttachmentIDs: decoded.fileAttachmentIDs,
            attachments: decoded.attachments,
            completedDates: decoded.completedDates
        )

        return memory
    }

    struct DecodedContents {
        var note: String?
        var checkItems: [CheckItemModel]
        var photoAttachmentIDs: [UUID]
        var linkAttachmentIDs: [UUID]
        var audioAttachmentIDs: [UUID]
        var fileAttachmentIDs: [UUID]
        var attachments: [MemoryModel.Attachment]
        var body: String?
        var completedDates: [Date]
    }

    func decodeContents(for entity: Memory,
                        attachments: [MemoryModel.Attachment]) -> DecodedContents {
        guard let data = entity.contentsData,
              let bundle = try? jsonDecoder.decode(MemoryDomain.MemoryContentBundle.self, from: data) else {
            return DecodedContents(
                note: nil,
                checkItems: [],
                photoAttachmentIDs: [],
                linkAttachmentIDs: [],
                audioAttachmentIDs: [],
                fileAttachmentIDs: [],
                attachments: attachments,
                body: nil,
                completedDates: []
            )
        }

        // Check if this is new format (has fixed fields) or legacy format (has contents array)
        if bundle.contents != nil {
            // Legacy migration: convert from contents array to fixed fields
            return migrateLegacyContents(bundle: bundle, attachments: attachments)
        }

        // New format: use fixed fields directly
        let allReferencedIDs = Set(
            (bundle.photoAttachmentIDs ?? []) +
            (bundle.linkAttachmentIDs ?? []) +
            (bundle.audioAttachmentIDs ?? []) +
            (bundle.fileAttachmentIDs ?? [])
        )
        let filteredAttachments = allReferencedIDs.isEmpty ? attachments : attachments.filter { allReferencedIDs.contains($0.id) }

        return DecodedContents(
            note: bundle.note,
            checkItems: bundle.checkItems ?? [],
            photoAttachmentIDs: bundle.photoAttachmentIDs ?? [],
            linkAttachmentIDs: bundle.linkAttachmentIDs ?? [],
            audioAttachmentIDs: bundle.audioAttachmentIDs ?? [],
            fileAttachmentIDs: bundle.fileAttachmentIDs ?? [],
            attachments: filteredAttachments,
            body: bundle.note,
            completedDates: bundle.completedDates ?? []
        )
    }

    /// Migrates legacy contents array format to new fixed fields format
    func migrateLegacyContents(bundle: MemoryDomain.MemoryContentBundle,
                               attachments: [MemoryModel.Attachment]) -> DecodedContents {
        guard let contents = bundle.contents else {
            return DecodedContents(
                note: nil, checkItems: [], photoAttachmentIDs: [],
                linkAttachmentIDs: [], audioAttachmentIDs: [], fileAttachmentIDs: [],
                attachments: attachments, body: nil, completedDates: []
            )
        }

        // Extract note from richText contents (combine multiple into one)
        let note = contents.aggregatedBodyText()

        // Extract checklist items
        let checkItems = contents.flattenedChecklistItems()

        // Extract attachment IDs by type
        var photoIDs: [UUID] = []
        var linkIDs: [UUID] = []
        var audioIDs: [UUID] = []
        var fileIDs: [UUID] = []

        for content in contents {
            switch content {
            case .photos(let ids):
                photoIDs.append(contentsOf: ids)
            case .links(let ids):
                linkIDs.append(contentsOf: ids)
            case .audio(let ids):
                audioIDs.append(contentsOf: ids)
            case .files(let ids):
                fileIDs.append(contentsOf: ids)
            default:
                break
            }
        }

        let referencedIDs = Set(contents.referencedAttachmentIDs())
        let filteredAttachments = referencedIDs.isEmpty ? attachments : attachments.filter { referencedIDs.contains($0.id) }

        return DecodedContents(
            note: note,
            checkItems: checkItems,
            photoAttachmentIDs: photoIDs,
            linkAttachmentIDs: linkIDs,
            audioAttachmentIDs: audioIDs,
            fileAttachmentIDs: fileIDs,
            attachments: filteredAttachments,
            body: note,
            completedDates: bundle.completedDates ?? []
        )
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
        let objectID: NSManagedObjectID = try await withCheckedThrowingContinuation { continuation in
            persistence.performBackgroundTask { context in
                do {
                    guard let memory = try self.fetchMemory(by: memoryID, context: context) else {
                        throw MemoryServiceError.memoryNotFound
                    }
                    try mutation(memory)
                    memory.updatedAt = Date()
                    try context.save()
                    continuation.resume(returning: memory.objectID)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        // Update cache immediately with the updated memory
        // fetchMemoryFromViewContext is already @MainActor, so we're on main thread
        do {
            let updatedMemory = try await fetchMemoryFromViewContext(objectID: objectID)
            updateCachedMemory(updatedMemory)
        } catch {
            logger.error("Failed to update cache immediately: \(error.localizedDescription)")
        }

        // Then refresh to ensure everything is in sync
        await refresh(force: true)
    }

    /// Mutates the contentsData field of a memory
    /// This is useful for updating fields stored in MemoryContentBundle without affecting other memory properties
    func mutateContentsData(memoryID: UUID,
                            mutation: @escaping (inout MemoryDomain.MemoryContentBundle) throws -> Void) async throws {
        let objectID: NSManagedObjectID = try await withCheckedThrowingContinuation { continuation in
            persistence.performBackgroundTask { context in
                do {
                    guard let memory = try self.fetchMemory(by: memoryID, context: context) else {
                        throw MemoryServiceError.memoryNotFound
                    }

                    // Decode existing contentsData or create new bundle
                    var bundle: MemoryDomain.MemoryContentBundle
                    if let data = memory.contentsData,
                       let existingBundle = try? self.jsonDecoder.decode(MemoryDomain.MemoryContentBundle.self, from: data) {
                        bundle = existingBundle
                    } else {
                        bundle = MemoryDomain.MemoryContentBundle()
                    }

                    // Apply mutation
                    try mutation(&bundle)

                    // Re-encode and save
                    memory.contentsData = try self.jsonEncoder.encode(bundle)
                    memory.updatedAt = Date()
                    try context.save()
                    continuation.resume(returning: memory.objectID)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        // Update cache immediately
        do {
            let updatedMemory = try await fetchMemoryFromViewContext(objectID: objectID)
            updateCachedMemory(updatedMemory)
        } catch {
            logger.error("Failed to update cache immediately: \(error.localizedDescription)")
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

    internal func sortedMemories(_ memories: [MemoryModel], using strategy: SortStrategy) -> [MemoryModel] {
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

        case .updatedAtAscending:
            return memories.sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned {
                    return lhs.isPinned && !rhs.isPinned
                }
                return lhs.updatedAt < rhs.updatedAt
            }

        case .createdAtDescending:
            return memories.sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned {
                    return lhs.isPinned && !rhs.isPinned
                }
                return lhs.createdAt > rhs.createdAt
            }

        case .createdAtAscending:
            return memories.sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned {
                    return lhs.isPinned && !rhs.isPinned
                }
                return lhs.createdAt < rhs.createdAt
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
                return lhs.updatedAt > rhs.updatedAt
            }
        }
    }
}
