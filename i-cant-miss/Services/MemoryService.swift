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
        let includeArchived: Bool
        let sort: SortStrategy

        init(spaceIDs: Set<UUID>,
             statuses: Set<MemoryStatus>,
             includeCompleted: Bool,
             includeArchived: Bool,
             sort: SortStrategy) {
            self.spaceIDs = spaceIDs
            self.statuses = statuses
            self.includeCompleted = includeCompleted
            self.includeArchived = includeArchived
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
            let reminderModels = try fetchReminders(in: context)
            let noteModels = try fetchNotes(in: context)
            let todoModels = try fetchTodoLists(in: context)

            let combined = await buildUnifiedMemories(
                reminders: reminderModels,
                notes: noteModels,
                todos: todoModels
            )

            memories = combined
            lastRefreshed = Date()
            cache.removeAll()
            cacheTimestamps.removeAll()

            if let scheduler = notificationScheduler {
                await scheduler.refreshNotifications(reminders: reminderModels)
            }
            geofenceManager?.sync(reminders: reminderModels)

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
                  includeArchived: Bool = false,
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
            includeArchived: includeArchived,
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
                case .archived:
                    return includeArchived
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
            .filter { !$0.hasTriggers && $0.space == nil && $0.status == .active }
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
}

// MARK: - Fetching & conversion

private extension MemoryService {
    func fetchReminders(in context: NSManagedObjectContext) throws -> [ReminderModel] {
        let request: NSFetchRequest<Reminder> = Reminder.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Reminder.updatedAt, ascending: false)
        ]
        request.relationshipKeyPathsForPrefetching = ["triggers", "folder"]
        request.returnsObjectsAsFaults = false
        return try context.fetch(request).map { $0.toModel() }
    }

    func fetchNotes(in context: NSManagedObjectContext) throws -> [NoteModel] {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Note.updatedAt, ascending: false)
        ]
        request.relationshipKeyPathsForPrefetching = ["folder", "tags"]
        request.returnsObjectsAsFaults = false
        return try context.fetch(request).map { $0.toModel() }
    }

    func fetchTodoLists(in context: NSManagedObjectContext) throws -> [TodoListModel] {
        let request: NSFetchRequest<TodoList> = TodoList.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \TodoList.updatedAt, ascending: false)
        ]
        request.relationshipKeyPathsForPrefetching = ["items", "folder"]
        request.returnsObjectsAsFaults = false
        return try context.fetch(request).map { $0.toModel() }
    }

    func buildUnifiedMemories(reminders: [ReminderModel],
                              notes: [NoteModel],
                              todos: [TodoListModel]) async -> [MemoryModel] {
        let defaultSpace = spaceService.defaultSpace()
        var unified: [MemoryModel] = []
        unified.reserveCapacity(reminders.count + notes.count + todos.count)

        for reminder in reminders {
            let space = reminder.folder.flatMap { spaceService.resolveSpace(for: $0) } ?? defaultSpace
            var memory = reminder.toMemory(space: space)
            let attachments = await attachmentStore.attachments(for: memory.id)
            populateContents(for: &memory, attachments: attachments)
            unified.append(memory)
        }

        for note in notes {
            let space = note.folder.flatMap { spaceService.resolveSpace(for: $0) } ?? defaultSpace
            var memory = note.toMemory(space: space)
            let attachments = await attachmentStore.attachments(for: memory.id)
            populateContents(for: &memory, attachments: attachments)
            unified.append(memory)
        }

        for todo in todos {
            let space = todo.folder.flatMap { spaceService.resolveSpace(for: $0) } ?? defaultSpace
            var memory = todo.toMemory(space: space)
            let attachments = await attachmentStore.attachments(for: memory.id)
            populateContents(for: &memory, attachments: attachments)
            unified.append(memory)
        }

        return unified.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned && !rhs.isPinned
            }
            return lhs.updatedAt > rhs.updatedAt
        }
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

    func populateContents(for memory: inout MemoryModel,
                          attachments: [MemoryModel.Attachment]) {
        let decodeResult = MemoryContentCodec.extractContents(from: attachments)

        let photoAttachments = decodeResult.remainingAttachments.filter { $0.kind == .photo }
        let linkAttachments = decodeResult.remainingAttachments.filter { $0.kind == .link }

        if decodeResult.contents.isEmpty {
            memory.contents = MemoryContent.legacyContents(
                body: memory.body,
                checkItems: memory.checkItems,
                photoAttachments: photoAttachments,
                linkAttachments: linkAttachments
            )
        } else {
            memory.contents = decodeResult.contents
        }

        let referencedAttachmentIDs = Set(memory.contents.referencedAttachmentIDs())
        if referencedAttachmentIDs.isEmpty {
            memory.attachments = decodeResult.remainingAttachments
        } else {
            memory.attachments = decodeResult.remainingAttachments.filter { referencedAttachmentIDs.contains($0.id) }
        }
        memory.body = memory.contents.aggregatedBodyText()
        memory.checkItems = memory.contents.flattenedChecklistItems()
    }
}
