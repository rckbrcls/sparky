//
//  MemoryService.swift
//  sparky
//

import Foundation
import Combine
import SwiftData
import os.log

enum MemoryServiceError: LocalizedError {
    case memoryNotFound
    case validationFailed(String)

    var errorDescription: String? {
        switch self {
        case .memoryNotFound:
            return "The memory could not be found."
        case .validationFailed(let message):
            return message
        }
    }
}

@MainActor
final class MemoryService: ObservableObject {
    enum SortStrategy {
        case manual
        case createdAtAscending
        case createdAtDescending
        case updatedAtAscending
        case updatedAtDescending
    }

    @Published private(set) var memories: [Memory] = []
    @Published private(set) var lastRefreshed: Date?

    var triggerExecutorCoordinator: TriggerExecutorCoordinator?

    private let dataController: DataController
    private let mindService: MindService
    private let attachmentStore: MemoryAttachmentStore
    private let cacheTTL: TimeInterval
    private var refreshTimer: AnyCancellable?
    private var memoryIndex: [UUID: Memory] = [:]
    private let logger = Logger(subsystem: "sparky", category: "MemoryService")

    init(
        dataController: DataController,
        mindService: MindService,
        attachmentStore: MemoryAttachmentStore,
        cacheTTL: TimeInterval = 30
    ) {
        self.dataController = dataController
        self.mindService = mindService
        self.attachmentStore = attachmentStore
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
            var descriptor = FetchDescriptor<Memory>()
            descriptor.includePendingChanges = true

            let results = try context.fetch(descriptor)
            let sorted = results.sorted { lhs, rhs in
                (lhs.updatedAt ?? lhs.createdAt ?? Date()) > (rhs.updatedAt ?? rhs.createdAt ?? Date())
            }

            self.memories = sorted
            self.lastRefreshed = Date()
            rebuildIndex()
        } catch {
            logger.error("Failed to load initial memories: \(error.localizedDescription)")
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
    func refresh(force: Bool) async -> [Memory] {
        if !force,
           let last = lastRefreshed,
           Date().timeIntervalSince(last) < cacheTTL {
            return memories
        }

        let context = dataController.modelContext

        do {
            var descriptor = FetchDescriptor<Memory>()
            descriptor.includePendingChanges = true

            let results = try context.fetch(descriptor)
            var populated = results

            for memory in populated {
                memory.attachments = await attachmentStore.attachments(for: memory.id)
            }

            let sorted = populated.sorted { lhs, rhs in
                (lhs.updatedAt ?? lhs.createdAt ?? Date()) > (rhs.updatedAt ?? rhs.createdAt ?? Date())
            }

            self.memories = sorted
            lastRefreshed = Date()
            rebuildIndex()

            if let coordinator = triggerExecutorCoordinator {
                await coordinator.sync(memories: sorted)
            }

            return sorted
        } catch {
            logger.error("Failed to refresh memories: \(error.localizedDescription)")
            return memories
        }
    }

    private func rebuildIndex() {
        memoryIndex.removeAll(keepingCapacity: true)
        for memory in memories {
            memoryIndex[memory.id] = memory
        }
    }

    func memory(id: UUID) -> Memory? {
        memoryIndex[id]
    }

    func memories(
        in mind: Mind?,
        statuses: [MemoryStatus] = [],
        includeCompleted: Bool = true,
        sort: SortStrategy = .updatedAtDescending
    ) -> [Memory] {
        var filtered: [Memory]

        if let mind = mind {
            if mind.isAllMinds {
                filtered = memories
            } else if mind.isInbox {
                filtered = memories.filter { $0.mind == nil }
            } else {
                let mindID = mind.id
                filtered = memories.filter { $0.mind?.id == mindID }
            }
        } else {
            filtered = memories
        }

        if !includeCompleted {
            filtered = filtered.filter { $0.status == .active }
        }

        if !statuses.isEmpty {
            filtered = filtered.filter { statuses.contains($0.status) }
        }

        return sortedMemories(filtered, using: sort)
    }

    func sortedMemories(_ memories: [Memory], using strategy: SortStrategy) -> [Memory] {
        switch strategy {
        case .manual:
            return memories.sorted { lhs, rhs in
                lhs.userOrder < rhs.userOrder
            }
        case .createdAtAscending:
            return memories.sorted { lhs, rhs in
                (lhs.createdAt ?? Date()) < (rhs.createdAt ?? Date())
            }
        case .createdAtDescending:
            return memories.sorted { lhs, rhs in
                (lhs.createdAt ?? Date()) > (rhs.createdAt ?? Date())
            }
        case .updatedAtAscending:
            return memories.sorted { lhs, rhs in
                (lhs.updatedAt ?? lhs.createdAt ?? Date()) < (rhs.updatedAt ?? rhs.createdAt ?? Date())
            }
        case .updatedAtDescending:
            return memories.sorted { lhs, rhs in
                (lhs.updatedAt ?? lhs.createdAt ?? Date()) > (rhs.updatedAt ?? rhs.createdAt ?? Date())
            }
        }
    }

    func scheduledMemories() -> [Memory] {
        memories.filter { memory in
            memory.status == .active && memory.triggers.contains { $0.type == .scheduled && $0.isActive }
        }
    }

    // MARK: - CRUD Operations

    func createMemory(from draft: MemoryDraft) async throws -> Memory {
        let trimmedTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw MemoryServiceError.validationFailed("Memory title is required")
        }

        let context = dataController.modelContext
        let now = Date()

        let mind = draft.mindID.flatMap { mindService.mind(id: $0) }

        let userOrder = (memories.map(\.userOrder).max() ?? -1) + 1

        let memory = Memory(
            id: draft.id,
            title: trimmedTitle,
            body: draft.note,
            statusRaw: draft.status.rawValue,
            isPinned: draft.isPinned,
            priorityRaw: nil,
            dueDate: draft.dueDate,
            createdAt: now,
            updatedAt: now,
            userOrder: userOrder,
            autoCompleteOnChecklistCompletion: draft.autoCompleteOnChecklistCompletion,
            mind: mind
        )

        let checkItems = draft.checkItems.sorted { $0.sortOrder < $1.sortOrder }.map { item in
            CheckItemModel(
                id: item.id,
                title: item.title,
                detail: item.detail.isEmpty ? nil : item.detail,
                isCompleted: item.isCompleted,
                sortOrder: item.sortOrder,
                createdAt: item.createdAt,
                updatedAt: item.completedAt ?? item.createdAt,
                completedAt: item.completedAt,
                memory: memory
            )
        }

        let triggers = draft.triggers.map { trigger in
            cloneTrigger(trigger, for: memory)
        }

        memory.checkItems = checkItems
        memory.triggers = triggers
        memory.attachmentReferences = buildAttachmentReferences(from: draft, memory: memory)
        memory.completionDateEntries = buildCompletionEntries(from: draft, memory: memory)

        context.insert(memory)
        dataController.save()

        try await attachmentStore.replaceAttachments(for: memory.id, with: draft.attachments)

        _ = await refresh(force: true)
        return memoryIndex[memory.id] ?? memory
    }

    func updateMemory(from draft: MemoryDraft) async throws -> Memory {
        let trimmedTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw MemoryServiceError.validationFailed("Memory title is required")
        }

        guard let memory = memory(id: draft.id) else {
            throw MemoryServiceError.memoryNotFound
        }

        let context = dataController.modelContext
        let now = Date()

        let mind = draft.mindID.flatMap { mindService.mind(id: $0) }

        memory.title = trimmedTitle
        memory.body = draft.note
        memory.statusRaw = draft.status.rawValue
        memory.isPinned = draft.isPinned
        memory.dueDate = draft.dueDate
        memory.updatedAt = now
        memory.autoCompleteOnChecklistCompletion = draft.autoCompleteOnChecklistCompletion
        memory.mind = mind

        let previousCheckItems = memory.checkItems
        let previousTriggers = memory.triggers
        let previousAttachments = memory.attachmentReferences
        let previousCompletionDates = memory.completionDateEntries

        memory.checkItems = []
        memory.triggers = []
        memory.attachmentReferences = []
        memory.completionDateEntries = []

        for item in previousCheckItems {
            context.delete(item)
        }

        for trigger in previousTriggers {
            context.delete(trigger)
        }

        for attachment in previousAttachments {
            context.delete(attachment)
        }

        for completion in previousCompletionDates {
            context.delete(completion)
        }

        memory.checkItems = draft.checkItems.sorted { $0.sortOrder < $1.sortOrder }.map { item in
            CheckItemModel(
                id: item.id,
                title: item.title,
                detail: item.detail.isEmpty ? nil : item.detail,
                isCompleted: item.isCompleted,
                sortOrder: item.sortOrder,
                createdAt: item.createdAt,
                updatedAt: item.completedAt ?? item.createdAt,
                completedAt: item.completedAt,
                memory: memory
            )
        }

        memory.triggers = draft.triggers.map { trigger in
            cloneTrigger(trigger, for: memory)
        }
        memory.attachmentReferences = buildAttachmentReferences(from: draft, memory: memory)
        memory.completionDateEntries = buildCompletionEntries(from: draft, memory: memory)

        dataController.save()

        try await attachmentStore.replaceAttachments(for: memory.id, with: draft.attachments)

        _ = await refresh(force: true)
        return memoryIndex[memory.id] ?? memory
    }

    func deleteMemory(id: UUID) async throws {
        guard let memory = memory(id: id) else {
            throw MemoryServiceError.memoryNotFound
        }

        let context = dataController.modelContext
        context.delete(memory)
        try await attachmentStore.deleteAllAttachments(for: id)
        dataController.save()

        if let coordinator = triggerExecutorCoordinator {
            await coordinator.unregisterAll(for: id)
        }

        _ = await refresh(force: true)
    }

    func deleteMemories(ids: Set<UUID>) async throws {
        for id in ids {
            try? await deleteMemory(id: id)
        }
    }

    func moveMemory(_ id: UUID, to mind: Mind?) async throws {
        guard let memory = memory(id: id) else {
            throw MemoryServiceError.memoryNotFound
        }

        memory.mind = mind
        dataController.save()

        _ = await refresh(force: true)
    }

    func setStatus(memoryID: UUID, status: MemoryStatus) async throws {
        guard let memory = memory(id: memoryID) else {
            throw MemoryServiceError.memoryNotFound
        }

        memory.status = status
        memory.updatedAt = Date()
        dataController.save()

        if status == .completed, let coordinator = triggerExecutorCoordinator {
            await coordinator.unregisterAll(for: memoryID)
        }

        _ = await refresh(force: true)
    }

    func toggleCompletion(memoryID: UUID) async throws {
        guard let memory = memory(id: memoryID) else {
            throw MemoryServiceError.memoryNotFound
        }

        let newStatus: MemoryStatus = memory.status == .active ? .completed : .active
        try await setStatus(memoryID: memoryID, status: newStatus)
    }

    func toggleCompletionForDate(memoryID: UUID, date: Date) async throws {
        guard let memory = memory(id: memoryID) else {
            throw MemoryServiceError.memoryNotFound
        }

        let calendar = Calendar.current
        if let existing = memory.completionDateEntries.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
            dataController.modelContext.delete(existing)
        } else {
            let entry = MemoryCompletionDate(date: date, memory: memory)
            memory.completionDateEntries.append(entry)
        }

        memory.updatedAt = Date()
        dataController.save()

        _ = await refresh(force: true)
    }

    func togglePin(memoryID: UUID) async throws {
        guard let memory = memory(id: memoryID) else {
            throw MemoryServiceError.memoryNotFound
        }

        memory.isPinned.toggle()
        memory.updatedAt = Date()
        dataController.save()

        _ = await refresh(force: true)
    }

    func toggleChecklistItemCompletion(memoryID: UUID, itemID: UUID) async throws {
        guard let memory = memory(id: memoryID) else {
            throw MemoryServiceError.memoryNotFound
        }

        guard let index = memory.checkItems.firstIndex(where: { $0.id == itemID }) else {
            return
        }

        let item = memory.checkItems[index]
        item.isCompleted.toggle()
        item.completedAt = item.isCompleted ? Date() : nil
        item.updatedAt = Date()
        memory.updatedAt = Date()
        dataController.save()

        _ = await refresh(force: true)
    }

    func duplicateMemory(memoryID: UUID) async throws {
        guard let source = memory(id: memoryID) else {
            throw MemoryServiceError.memoryNotFound
        }

        let draft = MemoryDraft(
            id: UUID(),
            title: source.title,
            status: source.status,
            isPinned: false,
            dueDate: source.dueDate,
            mindID: source.mind?.id,
            triggers: source.triggers.map { trigger in
                cloneTrigger(trigger, for: nil, id: UUID())
            },
            note: source.note,
            checkItems: source.checkItems.map { item in
                CheckItemDraft(
                    id: UUID(),
                    title: item.title,
                    detail: item.detail ?? "",
                    isCompleted: false,
                    sortOrder: item.sortOrder,
                    createdAt: Date(),
                    completedAt: nil
                )
            },
            photoAttachmentIDs: [],
            linkAttachmentIDs: [],
            audioAttachmentIDs: [],
            fileAttachmentIDs: [],
            attachments: [],
            autoCompleteOnChecklistCompletion: source.autoCompleteOnChecklistCompletion,
            completedDates: []
        )

        _ = try await createMemory(from: draft)
    }

    func updateMemoryOrder(memoryIDs: [UUID]) async throws {
        let context = dataController.modelContext

        for (index, id) in memoryIDs.enumerated() {
            guard let memory = memory(id: id) else { continue }
            memory.userOrder = index
        }

        dataController.save()
        _ = await refresh(force: true)
    }
}

// MARK: - Model cloning

private extension MemoryService {
    func buildAttachmentReferences(from draft: MemoryDraft, memory: Memory) -> [MemoryAttachmentReference] {
        let createdAtLookup = Dictionary(uniqueKeysWithValues: draft.attachments.map { ($0.id, $0.createdAt) })

        func makeRefs(ids: [UUID], kind: Memory.AttachmentKind) -> [MemoryAttachmentReference] {
            ids.enumerated().map { index, id in
                MemoryAttachmentReference(
                    id: id,
                    kindRaw: kind.rawValue,
                    sortOrder: index,
                    createdAt: createdAtLookup[id] ?? Date(),
                    memory: memory
                )
            }
        }

        return makeRefs(ids: draft.photoAttachmentIDs, kind: .photo)
            + makeRefs(ids: draft.linkAttachmentIDs, kind: .link)
            + makeRefs(ids: draft.audioAttachmentIDs, kind: .audio)
            + makeRefs(ids: draft.fileAttachmentIDs, kind: .file)
    }

    func buildCompletionEntries(from draft: MemoryDraft, memory: Memory) -> [MemoryCompletionDate] {
        draft.completedDates.map { date in
            MemoryCompletionDate(date: date, memory: memory)
        }
    }

    func cloneTrigger(_ source: MemoryTriggerModel, for memory: Memory?, id: UUID? = nil) -> MemoryTriggerModel {
        let location = source.location.map { location in
            MemoryTriggerLocation(
                id: UUID(),
                latitude: location.latitude,
                longitude: location.longitude,
                radius: location.radius,
                name: location.name,
                event: location.event
            )
        }

        let trigger = MemoryTriggerModel(
            id: id ?? source.id,
            type: source.type,
            fireDate: source.fireDate,
            startDate: source.startDate,
            recurrenceRule: source.recurrenceRule,
            timeZoneIdentifier: source.timeZoneIdentifier,
            weekdayMask: source.weekdayMask,
            isActive: source.isActive,
            isAllDay: source.isAllDay,
            location: location,
            spacedStage: source.spacedStage,
            lastReviewDate: source.lastReviewDate,
            ignoreCount: source.ignoreCount,
            memory: memory
        )

        location?.trigger = trigger
        return trigger
    }
}
