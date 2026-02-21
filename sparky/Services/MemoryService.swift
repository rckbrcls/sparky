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
    private var refreshTask: Task<Void, Never>?
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
        refreshTask?.cancel()
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
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(self?.cacheTTL ?? 30))
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
            let populated = results

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
            } else if mind.isLimbo {
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
            guard memory.status == .active else { return false }
            return memory.scheduleConfig?.isActive == true
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

        memory.checkItems = checkItems

        if let scheduleDraft = draft.scheduleConfig {
            memory.scheduleConfig = scheduleDraft.toModel(memory: memory)
        }
        if let locationDraft = draft.locationConfig {
            memory.locationConfig = locationDraft.toModel(memory: memory)
        }

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
        let previousAttachments = memory.attachmentReferences
        let previousCompletionDates = memory.completionDateEntries

        memory.checkItems = []
        memory.attachmentReferences = []
        memory.completionDateEntries = []

        for item in previousCheckItems {
            context.delete(item)
        }

        // Delete old configs
        if let oldSchedule = memory.scheduleConfig {
            memory.scheduleConfig = nil
            context.delete(oldSchedule)
        }
        if let oldLocation = memory.locationConfig {
            memory.locationConfig = nil
            context.delete(oldLocation)
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

        // Create new configs from draft
        if let scheduleDraft = draft.scheduleConfig {
            memory.scheduleConfig = scheduleDraft.toModel(memory: memory)
        }
        if let locationDraft = draft.locationConfig {
            memory.locationConfig = locationDraft.toModel(memory: memory)
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

        let now = Date()
        memory.status = status
        memory.updatedAt = now

        // Cascade status to checklist items
        if !memory.checkItems.isEmpty {
            for item in memory.checkItems {
                switch status {
                case .completed:
                    item.isCompleted = true
                    item.completedAt = item.completedAt ?? now
                    item.updatedAt = now
                case .active:
                    item.isCompleted = false
                    item.completedAt = nil
                    item.updatedAt = now
                }
            }
        }

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
        let existing: MemoryCompletionDate?

        if memory.hasIntraDayRecurrence {
            existing = memory.completionDateEntries.first { entry in
                calendar.isDate(entry.date, inSameDayAs: date) &&
                calendar.component(.hour, from: entry.date) == calendar.component(.hour, from: date) &&
                calendar.component(.minute, from: entry.date) == calendar.component(.minute, from: date)
            }
        } else {
            existing = memory.completionDateEntries.first { calendar.isDate($0.date, inSameDayAs: date) }
        }

        let now = Date()

        if let existing {
            dataController.modelContext.delete(existing)
            // Uncompleting for date: reset checklist items
            for item in memory.checkItems {
                item.isCompleted = false
                item.completedAt = nil
                item.updatedAt = now
            }
        } else {
            let entry = MemoryCompletionDate(date: date, memory: memory)
            memory.completionDateEntries.append(entry)
            // Completing for date: mark all checklist items as completed
            for item in memory.checkItems {
                item.isCompleted = true
                item.completedAt = item.completedAt ?? now
                item.updatedAt = now
            }
        }

        memory.updatedAt = now
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

    func toggleChecklistItemCompletion(memoryID: UUID, itemID: UUID, date: Date? = nil) async throws {
        guard let memory = memory(id: memoryID) else {
            throw MemoryServiceError.memoryNotFound
        }

        guard let index = memory.checkItems.firstIndex(where: { $0.id == itemID }) else {
            return
        }

        let now = Date()
        let item = memory.checkItems[index]
        item.isCompleted.toggle()
        item.completedAt = item.isCompleted ? now : nil
        item.updatedAt = now
        memory.updatedAt = now

        // Auto-complete or reactivate memory based on checklist state
        let allCompleted = memory.checkItems.allSatisfy(\.isCompleted)

        if memory.hasRecurringTriggers, let effectiveDate = date {
            // Recurring memory: toggle completion for the specific date
            let calendar = Calendar.current
            let existing: MemoryCompletionDate?

            if memory.hasIntraDayRecurrence {
                existing = memory.completionDateEntries.first { entry in
                    calendar.isDate(entry.date, inSameDayAs: effectiveDate) &&
                    calendar.component(.hour, from: entry.date) == calendar.component(.hour, from: effectiveDate) &&
                    calendar.component(.minute, from: entry.date) == calendar.component(.minute, from: effectiveDate)
                }
            } else {
                existing = memory.completionDateEntries.first { calendar.isDate($0.date, inSameDayAs: effectiveDate) }
            }

            if allCompleted && existing == nil {
                let entry = MemoryCompletionDate(date: effectiveDate, memory: memory)
                memory.completionDateEntries.append(entry)
            } else if !allCompleted, let existing {
                dataController.modelContext.delete(existing)
            }
        } else if !memory.hasRecurringTriggers {
            // Non-recurring memory: toggle global status
            if allCompleted && memory.status == .active {
                memory.status = .completed
                if let coordinator = triggerExecutorCoordinator {
                    await coordinator.unregisterAll(for: memoryID)
                }
            } else if !allCompleted && memory.status == .completed {
                memory.status = .active
            }
        }

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
            scheduleConfig: source.scheduleConfig.map {
                let draft = ScheduleConfigDraft.from($0)
                return ScheduleConfigDraft(
                    id: UUID(),
                    fireDate: draft.fireDate,
                    startDate: draft.startDate,
                    recurrenceRule: draft.recurrenceRule,
                    timeZoneIdentifier: draft.timeZoneIdentifier,
                    weekdayMask: draft.weekdayMask,
                    isActive: draft.isActive,
                    isAllDay: draft.isAllDay,
                    recurrenceEndType: draft.recurrenceEndType
                )
            },
            locationConfig: source.locationConfig.map {
                let draft = LocationConfigDraft.from($0)
                return LocationConfigDraft(
                    id: UUID(),
                    latitude: draft.latitude,
                    longitude: draft.longitude,
                    radius: draft.radius,
                    name: draft.name,
                    event: draft.event,
                    isActive: draft.isActive
                )
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

}
