//
//  MemoryService.swift
//  i-cant-miss
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
    private let lobeService: LobeService
    private let attachmentStore: MemoryAttachmentStore
    private let cacheTTL: TimeInterval
    private var refreshTimer: AnyCancellable?
    private var memoryIndex: [UUID: Memory] = [:]
    private let logger = Logger(subsystem: "i-cant-miss", category: "MemoryService")
    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()

    init(
        dataController: DataController,
        lobeService: LobeService,
        attachmentStore: MemoryAttachmentStore,
        cacheTTL: TimeInterval = 30
    ) {
        self.dataController = dataController
        self.lobeService = lobeService
        self.attachmentStore = attachmentStore
        self.cacheTTL = cacheTTL

        jsonEncoder.dateEncodingStrategy = .iso8601
        jsonDecoder.dateDecodingStrategy = .iso8601

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
            let populated = results.map { populateTransients($0) }
            let sorted = populated.sorted { lhs, rhs in
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
            var populated = results.map { populateTransients($0) }

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

    private func populateTransients(_ memory: Memory) -> Memory {
        if let triggersData = memory.triggersData,
           !triggersData.isEmpty,
           let decoded = try? jsonDecoder.decode([MemoryTriggerModel].self, from: triggersData) {
            memory.triggers = decoded
        } else {
            memory.triggers = []
        }

        if let contentsData = memory.contentsData,
           !contentsData.isEmpty {
            if let bundle = try? jsonDecoder.decode(MemoryDomain.MemoryContentBundle.self, from: contentsData) {
                memory.note = bundle.note
                memory.checkItems = bundle.checkItems ?? []
                memory.photoAttachmentIDs = bundle.photoAttachmentIDs ?? []
                memory.linkAttachmentIDs = bundle.linkAttachmentIDs ?? []
                memory.audioAttachmentIDs = bundle.audioAttachmentIDs ?? []
                memory.fileAttachmentIDs = bundle.fileAttachmentIDs ?? []
                memory.completedDates = bundle.completedDates ?? []
            }
        }

        return memory
    }

    func memory(id: UUID) -> Memory? {
        memoryIndex[id]
    }

    func memories(
        in lobe: Space?,
        statuses: [MemoryStatus] = [],
        includeCompleted: Bool = true,
        sort: SortStrategy = .updatedAtDescending
    ) -> [Memory] {
        var filtered: [Memory]

        if let lobe = lobe {
            if lobe.isAllSpaces {
                filtered = memories
            } else if lobe.isInbox || lobe.isLimbo {
                filtered = memories.filter { $0.space == nil }
            } else if let mindID = lobe.mind?.id {
                filtered = memories.filter { memory in
                    guard let memoryLobeMindID = memory.space?.mind?.id else { return false }
                    return memoryLobeMindID == mindID
                }
            } else {
                let lobeID = lobe.id
                filtered = memories.filter { $0.space?.id == lobeID }
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
            return memories.sorted { (lhs.createdAt ?? Date()) < (rhs.createdAt ?? Date()) }
        case .createdAtDescending:
            return memories.sorted { (lhs.createdAt ?? Date()) > (rhs.createdAt ?? Date()) }
        case .updatedAtAscending:
            return memories.sorted { (lhs.updatedAt ?? lhs.createdAt ?? Date()) < (rhs.updatedAt ?? rhs.createdAt ?? Date()) }
        case .updatedAtDescending:
            return memories.sorted { (lhs.updatedAt ?? lhs.createdAt ?? Date()) > (rhs.updatedAt ?? rhs.createdAt ?? Date()) }
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

        let space = draft.lobeID.flatMap { lobeService.lobe(id: $0) }

        let triggersData = try? jsonEncoder.encode(draft.triggers)
        let contentsBundle = MemoryDomain.MemoryContentBundle(
            note: draft.note,
            checkItems: draft.checkItems.map { item in
                CheckItemModel(
                    id: item.id,
                    title: item.title,
                    detail: item.detail.isEmpty ? nil : item.detail,
                    isCompleted: item.isCompleted,
                    sortOrder: item.sortOrder,
                    createdAt: item.createdAt,
                    updatedAt: item.completedAt ?? item.createdAt,
                    completedAt: item.completedAt
                )
            },
            photoAttachmentIDs: draft.photoAttachmentIDs,
            linkAttachmentIDs: draft.linkAttachmentIDs,
            audioAttachmentIDs: draft.audioAttachmentIDs,
            fileAttachmentIDs: draft.fileAttachmentIDs,
            completedDates: draft.completedDates
        )
        let contentsData = try? jsonEncoder.encode(contentsBundle)

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
            contentsData: contentsData,
            triggersData: triggersData,
            space: space
        )

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

        let space = draft.lobeID.flatMap { lobeService.lobe(id: $0) }

        let triggersData = try? jsonEncoder.encode(draft.triggers)
        let contentsBundle = MemoryDomain.MemoryContentBundle(
            note: draft.note,
            checkItems: draft.checkItems.map { item in
                CheckItemModel(
                    id: item.id,
                    title: item.title,
                    detail: item.detail.isEmpty ? nil : item.detail,
                    isCompleted: item.isCompleted,
                    sortOrder: item.sortOrder,
                    createdAt: item.createdAt,
                    updatedAt: item.completedAt ?? item.createdAt,
                    completedAt: item.completedAt
                )
            },
            photoAttachmentIDs: draft.photoAttachmentIDs,
            linkAttachmentIDs: draft.linkAttachmentIDs,
            audioAttachmentIDs: draft.audioAttachmentIDs,
            fileAttachmentIDs: draft.fileAttachmentIDs,
            completedDates: draft.completedDates
        )
        let contentsData = try? jsonEncoder.encode(contentsBundle)

        memory.title = trimmedTitle
        memory.body = draft.note
        memory.statusRaw = draft.status.rawValue
        memory.isPinned = draft.isPinned
        memory.dueDate = draft.dueDate
        memory.updatedAt = now
        memory.autoCompleteOnChecklistCompletion = draft.autoCompleteOnChecklistCompletion
        memory.contentsData = contentsData
        memory.triggersData = triggersData
        memory.space = space

        populateTransients(memory)

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

    func moveMemory(_ id: UUID, to lobe: Space) async throws {
        guard let memory = memory(id: id) else {
            throw MemoryServiceError.memoryNotFound
        }

        memory.space = lobe
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
        if memory.completedDates.contains(where: { calendar.isDate($0, inSameDayAs: date) }) {
            memory.completedDates.removeAll { calendar.isDate($0, inSameDayAs: date) }
        } else {
            memory.completedDates.append(date)
        }

        let contentsBundle = MemoryDomain.MemoryContentBundle(
            note: memory.note,
            checkItems: memory.checkItems,
            photoAttachmentIDs: memory.photoAttachmentIDs,
            linkAttachmentIDs: memory.linkAttachmentIDs,
            audioAttachmentIDs: memory.audioAttachmentIDs,
            fileAttachmentIDs: memory.fileAttachmentIDs,
            completedDates: memory.completedDates
        )
        memory.contentsData = try? jsonEncoder.encode(contentsBundle)
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

        memory.checkItems[index].isCompleted.toggle()
        memory.checkItems[index].completedAt = memory.checkItems[index].isCompleted ? Date() : nil

        let contentsBundle = MemoryDomain.MemoryContentBundle(
            note: memory.note,
            checkItems: memory.checkItems,
            photoAttachmentIDs: memory.photoAttachmentIDs,
            linkAttachmentIDs: memory.linkAttachmentIDs,
            audioAttachmentIDs: memory.audioAttachmentIDs,
            fileAttachmentIDs: memory.fileAttachmentIDs,
            completedDates: memory.completedDates
        )
        memory.contentsData = try? jsonEncoder.encode(contentsBundle)
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
            lobeID: source.space?.id,
            triggers: source.triggers.map { trigger in
                MemoryTriggerModel(
                    id: UUID(),
                    type: trigger.type,
                    fireDate: trigger.fireDate,
                    startDate: trigger.startDate,
                    recurrenceRule: trigger.recurrenceRule,
                    timeZoneIdentifier: trigger.timeZoneIdentifier,
                    weekdayMask: trigger.weekdayMask,
                    isActive: trigger.isActive,
                    isAllDay: trigger.isAllDay,
                    location: trigger.location,
                    sequential: trigger.sequential.map { seq in
                        MemoryTriggerModel.TriggerSequential(
                            sequenceID: seq.sequenceID,
                            stepIndex: seq.stepIndex,
                            startDate: seq.startDate,
                            currentStepIndex: seq.currentStepIndex
                        )
                    },
                    spacedStage: trigger.spacedStage,
                    lastReviewDate: trigger.lastReviewDate,
                    ignoreCount: trigger.ignoreCount
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
