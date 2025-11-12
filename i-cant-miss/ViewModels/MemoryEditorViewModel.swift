//
//  MemoryEditorViewModel.swift
//  i-cant-miss
//
//  Created by Codex on 09/03/24.
//

import Foundation
import Combine

enum MemoryEditorTemplate {
    case blank
    case checklist
    case quickReminder
}

@MainActor
final class MemoryEditorViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var body: String = ""
    @Published var selectedSpaceID: UUID?
    @Published var status: MemoryStatus = .active
    @Published var priority: MemoryPriority = .medium
    @Published var isPinned: Bool = false
    @Published var dueDateEnabled: Bool = false
    @Published var dueDate: Date = Date().addingTimeInterval(3600)
    @Published var autoCompleteChecklist: Bool
    @Published var triggers: [MemoryTriggerDraft] = []
    @Published var checklistItems: [CheckItemDraft] = []
    @Published var showChecklist: Bool = false
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?
    @Published var attachments: [MemoryModel.Attachment] = []
    @Published var linkAttachments: [MemoryModel.Attachment] = []

    let environment: AppEnvironment
    private let attachmentStore: MemoryAttachmentStore
    private let existingMemory: MemoryModel?
    private let template: MemoryEditorTemplate
    private let defaultSpace: SpaceModel?
    private var hasMigratedLegacyAttachments = false

    init(environment: AppEnvironment,
         attachmentStore: MemoryAttachmentStore,
         memory: MemoryModel?,
         defaultSpace: SpaceModel?,
         template: MemoryEditorTemplate) {
        self.environment = environment
        self.attachmentStore = attachmentStore
        self.existingMemory = memory
        self.template = template
        self.defaultSpace = defaultSpace
        self.autoCompleteChecklist = memory?.metadata.autoCompleteOnChecklistCompletion ?? false
        configureInitialState()
    }

    var availableSpaces: [SpaceModel] {
        environment.spaceService.spaces
    }

    var editingMemoryID: UUID? {
        existingMemory?.id
    }

    var selectedSpace: SpaceModel? {
        guard let id = selectedSpaceID else { return nil }
        if let space = environment.spaceService.space(id: id) {
            return space
        }
        if id == SpaceModel.allSpacesIdentifier {
            return SpaceModel.allSpaces
        }
        if id == SpaceModel.inboxIdentifier {
            return SpaceModel.inbox
        }
        return nil
    }

    var canToggleAutoComplete: Bool {
        !checklistItems.isEmpty
    }

    var sequentialTrigger: MemoryTriggerDraft? {
        triggers.first(where: { $0.type == .sequential })
    }

    func loadLatestDataIfNeeded() {
        guard let memory = existingMemory else { return }
        switch memory.metadata.origin {
        case .reminder(let id):
            if let reminder = environment.reminderService.fetchReminderWithRelationships(id: id) {
                apply(reminder: reminder)
            }
        case .note(let id):
            if let note = environment.noteService.fetchNoteWithRelationships(id: id) {
                apply(note: note)
            }
        case .todoList(let id):
            if let list = environment.todoService.fetchListWithItems(id: id) {
                apply(todoList: list)
            }
        case .none:
            break
        }
    }

    func addChecklistItem() {
        showChecklist = true
        let nextOrder = (checklistItems.map(\.sortOrder).max() ?? -1) + 1
        checklistItems.append(CheckItemDraft(sortOrder: nextOrder))
    }

    func addChecklistItem(title: String, detail: String = "") {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        let trimmedDetail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        showChecklist = true
        let nextOrder = (checklistItems.map(\.sortOrder).max() ?? -1) + 1
        checklistItems.append(CheckItemDraft(title: trimmedTitle,
                                             detail: trimmedDetail,
                                             sortOrder: nextOrder))
    }

    func removeChecklistItems(at offsets: IndexSet) {
        let sorted = offsets.sorted(by: >)
        for index in sorted where checklistItems.indices.contains(index) {
            checklistItems.remove(at: index)
        }
        reindexChecklist()
        if checklistItems.isEmpty {
            showChecklist = false
        }
    }

    func moveChecklistItems(from source: IndexSet, to destination: Int) {
        var items = checklistItems
        let moving = source.sorted(by: >).map { items.remove(at: $0) }.reversed()
        let adjustedDestination = max(0, min(destination - source.filter { $0 < destination }.count, items.count))
        items.insert(contentsOf: moving, at: adjustedDestination)
        checklistItems = items
        reindexChecklist()
    }

    func toggleChecklistCompletion(for itemID: UUID) {
        guard let index = checklistItems.firstIndex(where: { $0.id == itemID }) else { return }
        checklistItems[index].isCompleted.toggle()
        checklistItems[index].completedAt = checklistItems[index].isCompleted ? (checklistItems[index].completedAt ?? Date()) : nil
    }

    @MainActor
    func createAttachment(data: Data) -> MemoryModel.Attachment {
        let attachment = MemoryModel.Attachment(
            id: UUID(),
            kind: .photo,
            data: data,
            createdAt: Date()
        )
        attachments.append(attachment)
        return attachment
    }

    @MainActor
    func createLinkAttachment(url: URL) -> MemoryModel.Attachment {
        let attachment = MemoryModel.Attachment(
            id: UUID(),
            kind: .link,
            data: Data(),
            createdAt: Date(),
            url: url
        )
        linkAttachments.append(attachment)
        return attachment
    }

    @MainActor
    func removeAttachment(id: UUID) {
        attachments.removeAll { $0.id == id }
    }

    @MainActor
    func removeLinkAttachment(id: UUID) {
        linkAttachments.removeAll { $0.id == id }
    }

    @MainActor
    func syncAttachments(withReferencedIDs ids: Set<UUID>) {
        guard !ids.isEmpty else {
            attachments.removeAll()
            linkAttachments.removeAll()
            return
        }
        attachments.removeAll { !ids.contains($0.id) }
        linkAttachments.removeAll { !ids.contains($0.id) }
    }

    func updateSchedule(
        fireDate: Date?,
        recurrence: RecurrenceRule?,
        weekdaySelection: Set<Int>,
        weekdayReferenceTime: Date
    ) {
        updateTimeTrigger(fireDate: fireDate, recurrence: recurrence)
        updateWeekdayTrigger(weekdaySelection: weekdaySelection, referenceTime: weekdayReferenceTime)
    }

    func setTimeTrigger(fireDate: Date?, recurrence: RecurrenceRule?) {
        updateTimeTrigger(fireDate: fireDate, recurrence: recurrence)
    }

    func setWeekdayTrigger(weekdaySelection: Set<Int>, referenceTime: Date) {
        updateWeekdayTrigger(weekdaySelection: weekdaySelection, referenceTime: referenceTime)
    }

    func addLocationTrigger(name: String, latitude: Double, longitude: Double, radius: Double, event: LocationEvent) {
        let draft = MemoryTriggerDraft(
            type: .location,
            fireDate: nil,
            startDate: Date(),
            timeZoneIdentifier: TimeZone.current.identifier,
            weekdayMask: 0,
            isActive: true,
            location: .init(latitude: latitude, longitude: longitude, radius: radius, name: name, event: event)
        )
        triggers.append(draft)
    }

    func addPersonTrigger(name: String, identifier: String?) {
        let draft = MemoryTriggerDraft(
            type: .person,
            fireDate: nil,
            startDate: Date(),
            person: .init(name: name, contactIdentifier: identifier),
            spacedStage: 0,
            ignoreCount: 0
        )
        triggers.append(draft)
    }

    func removeTrigger(id: UUID) {
        triggers.removeAll { $0.id == id }
    }

    func updateTrigger(id: UUID, with updated: MemoryTriggerDraft) {
        guard let index = triggers.firstIndex(where: { $0.id == id }) else { return }
        triggers[index] = updated
    }

    func clearScheduleTriggers() {
        triggers.removeAll { $0.type == .time || $0.type == .dayOfWeek }
    }

    func updateSequentialTrigger(previousMemoryID: UUID?, nextMemoryID: UUID?) {
        let sanitizedPrevious = previousMemoryID
        let sanitizedNext = nextMemoryID

        guard sanitizedPrevious != nil || sanitizedNext != nil else {
            triggers.removeAll { $0.type == .sequential }
            return
        }

        let sequential = MemoryTriggerModel.TriggerSequential(
            previousMemoryID: sanitizedPrevious,
            nextMemoryID: sanitizedNext
        )

        if let index = triggers.firstIndex(where: { $0.type == .sequential }) {
            triggers[index].sequential = sequential
            triggers[index].isActive = true
        } else {
            let draft = MemoryTriggerDraft(
                type: .sequential,
                isActive: true,
                sequential: sequential
            )
            triggers.append(draft)
        }
    }

    func removeSequentialTrigger() {
        triggers.removeAll { $0.type == .sequential }
    }

    func selectTemplate(_ template: MemoryEditorTemplate) {
        applyTemplate(template)
    }

    func save() async -> Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            errorMessage = "Provide a title for the memory."
            return false
        }
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitizedChecklist = sanitizedChecklistItems()
        if showChecklist && sanitizedChecklist.isEmpty {
            showChecklist = false
        }

        isSaving = true
        defer { isSaving = false }

        do {
            let memoryID: UUID
            if let memory = existingMemory {
                memoryID = try await updateExistingMemory(memory, sanitizedChecklist: sanitizedChecklist)
            } else {
                memoryID = try await createNewMemory(trimmedTitle: trimmedTitle,
                                                     trimmedBody: trimmedBody,
                                                     sanitizedChecklist: sanitizedChecklist)
            }

            let allAttachments = attachments + linkAttachments
            try await attachmentStore.replaceAttachments(for: memoryID, with: allAttachments)
            await environment.memoryService.refresh(force: true)
            return true
        } catch {
            errorMessage = "Unable to save memory."
            return false
        }
    }
}

// MARK: - Private helpers

private extension MemoryEditorViewModel {
    func configureInitialState() {
        if let memory = existingMemory {
            apply(memory: memory)
        } else {
            selectedSpaceID = defaultSpace?.id ?? environment.spaceService.defaultSpace().id
            applyTemplate(template)
            attachments = []
            linkAttachments = []
            hasMigratedLegacyAttachments = true
        }
    }

    func apply(memory: MemoryModel) {
        title = memory.title
        body = memory.body ?? ""
        selectedSpaceID = memory.space.id
        status = memory.status
        priority = memory.priority ?? .medium
        isPinned = memory.isPinned
        dueDateEnabled = memory.dueDate != nil
        dueDate = memory.dueDate ?? Date().addingTimeInterval(3600)
        triggers = memory.triggers.map { draft(from: $0) }
        checklistItems = memory.checkItems
            .sorted(by: { $0.sortOrder < $1.sortOrder })
            .enumerated()
            .map { index, item in
                CheckItemDraft(
                    id: item.id,
                    title: item.title,
                    detail: item.detail ?? "",
                    isCompleted: item.isCompleted,
                    sortOrder: index,
                    createdAt: item.createdAt,
                    completedAt: item.completedAt
                )
            }
        showChecklist = !checklistItems.isEmpty
        autoCompleteChecklist = memory.metadata.autoCompleteOnChecklistCompletion
        let photoAttachments = memory.attachments.filter { $0.kind == .photo }
        let linkAttachments = memory.attachments.filter { $0.kind == .link }
        attachments = photoAttachments
        self.linkAttachments = linkAttachments
        migrateLegacyAttachmentsIfNeeded()
    }

    func apply(reminder: ReminderModel) {
        let trimmedTitle = reminder.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty {
            title = trimmedTitle
        }
        body = reminder.notes ?? ""
        priority = MemoryPriority(rawValue: reminder.priority.rawValue) ?? .medium
        status = reminder.status == .archived ? .archived : (reminder.status == .completed ? .completed : .active)
        triggers = reminder.triggers.map { draft(from: $0) }
        isPinned = false
        if let folder = reminder.folder {
            selectedSpaceID = environment.spaceService.resolveSpace(for: folder).id
        }
        migrateLegacyAttachmentsIfNeeded()
    }

    func apply(note: NoteModel) {
        if let trimmedTitle = note.title?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty {
            title = trimmedTitle
        }
        body = note.content
        isPinned = note.isPinned
        if let folder = note.folder {
            selectedSpaceID = environment.spaceService.resolveSpace(for: folder).id
        }
        migrateLegacyAttachmentsIfNeeded()
    }

    func apply(todoList: TodoListModel) {
        let trimmedTitle = todoList.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty {
            title = trimmedTitle
        }
        body = todoList.notes ?? ""
        isPinned = todoList.isPinned
        status = todoList.isArchived ? .archived : (todoList.isCompleted ? .completed : .active)
        dueDateEnabled = todoList.dueDate != nil
        dueDate = todoList.dueDate ?? Date().addingTimeInterval(3600)
        checklistItems = todoList.items
            .sorted(by: { $0.sortOrder < $1.sortOrder })
            .enumerated()
            .map { index, item in
                CheckItemDraft(
                    id: item.id,
                    title: item.title,
                    detail: item.detail ?? "",
                    isCompleted: item.isCompleted,
                    sortOrder: index,
                    createdAt: item.createdAt,
                    completedAt: item.completedAt
                )
            }
        showChecklist = !checklistItems.isEmpty
        autoCompleteChecklist = existingMemory?.metadata.autoCompleteOnChecklistCompletion ?? autoCompleteChecklist
        if let folder = todoList.folder {
            selectedSpaceID = environment.spaceService.resolveSpace(for: folder).id
        }
        migrateLegacyAttachmentsIfNeeded()
    }

    func applyTemplate(_ template: MemoryEditorTemplate) {
        switch template {
        case .blank:
            break
        case .checklist:
            // Start with an empty checklist and show the inline new-item row.
            showChecklist = true
            checklistItems = []
        case .quickReminder:
            let fireDate = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date()) ?? Date().addingTimeInterval(3600)
            let trigger = MemoryTriggerDraft(
                type: .time,
                fireDate: fireDate,
                startDate: fireDate,
                timeZoneIdentifier: TimeZone.current.identifier,
                weekdayMask: 0,
                isActive: true
            )
            triggers = [trigger]
        }
    }

    func reindexChecklist() {
        for index in checklistItems.indices {
            checklistItems[index].sortOrder = index
        }
    }

    func sanitizedChecklistItems() -> [CheckItemDraft] {
        checklistItems.enumerated().compactMap { index, item in
            let trimmed = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            var sanitized = item
            sanitized.title = trimmed
            sanitized.sortOrder = index
            sanitized.detail = item.detail.trimmingCharacters(in: .whitespacesAndNewlines)
            return sanitized
        }
    }

    func migrateLegacyAttachmentsIfNeeded() {
        guard !hasMigratedLegacyAttachments else { return }
        defer { hasMigratedLegacyAttachments = true }

        attachments.removeAll()
        linkAttachments.removeAll()
    }

    func updateExistingMemory(_ memory: MemoryModel,
                              sanitizedChecklist: [CheckItemDraft]) async throws -> UUID {
        switch memory.metadata.origin {
        case .reminder(let id):
            return try await updateReminder(id: id)
        case .note(let id):
            return try await updateNote(id: id)
        case .todoList(let id):
            return try await updateTodoList(id: id, sanitizedChecklist: sanitizedChecklist)
        case .none:
            return try await createNewMemory(trimmedTitle: title.trimmingCharacters(in: .whitespacesAndNewlines),
                                             trimmedBody: body.trimmingCharacters(in: .whitespacesAndNewlines),
                                             sanitizedChecklist: sanitizedChecklist)
        }
    }

    func createNewMemory(trimmedTitle: String,
                         trimmedBody: String,
                         sanitizedChecklist: [CheckItemDraft]) async throws -> UUID {
        if !triggers.isEmpty {
            return try await createReminder(trimmedTitle: trimmedTitle, trimmedBody: trimmedBody)
        } else if !sanitizedChecklist.isEmpty || dueDateEnabled {
            return try await createTodoList(trimmedTitle: trimmedTitle,
                                            trimmedBody: trimmedBody,
                                            sanitizedChecklist: sanitizedChecklist)
        } else {
            return try await createNote(trimmedTitle: trimmedTitle, trimmedBody: trimmedBody)
        }
    }

    func updateReminder(id: UUID) async throws -> UUID {
        guard var reminder = environment.reminderService.fetchReminderWithRelationships(id: id)
                ?? environment.reminderService.reminders.first(where: { $0.id == id }) else {
            throw MemoryService.MemoryServiceError.memoryNotFound
        }

        reminder.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        reminder.notes = body.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        reminder.priority = ReminderPriority(rawValue: priority.rawValue) ?? .medium
        reminder.status = reminderStatus(for: status)
        reminder.folder = folderForAudience(.reminders)
        reminder.triggers = triggers.map { $0.toModel() }
        reminder.updatedAt = Date()

        let updated = try await environment.reminderService.updateReminder(reminder)
        await environment.reminderService.refresh(force: true)
        return updated.id
    }

    func updateNote(id: UUID) async throws -> UUID {
        guard var note = environment.noteService.fetchNoteWithRelationships(id: id)
                ?? environment.noteService.notes.first(where: { $0.id == id }) else {
            throw NoteService.NoteServiceError.noteNotFound
        }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = body.trimmingCharacters(in: .whitespacesAndNewlines)

        note.title = trimmedTitle
        note.content = trimmedContent
        note.isPinned = isPinned
        note.updatedAt = Date()
        note.folder = folderForAudience(.notes)
        let updated = try await environment.noteService.updateNote(note)
        await environment.noteService.refresh(force: true)
        return updated.id
    }

    func updateTodoList(id: UUID, sanitizedChecklist: [CheckItemDraft]) async throws -> UUID {
        guard var list = environment.todoService.fetchListWithItems(id: id)
                ?? environment.todoService.lists.first(where: { $0.id == id }) else {
            throw TodoService.TodoServiceError.listNotFound
        }

        list.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        list.notes = body.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        list.dueDate = dueDateEnabled ? dueDate : nil
        list.isPinned = isPinned
        list.isArchived = status == .archived
        list.updatedAt = Date()
        list.folder = folderForAudience(.todos)
        list.items = sanitizedChecklist.enumerated().map { index, draft in
            draft.toModel(at: index)
        }

        let updated = try await environment.todoService.updateList(list)
        await environment.todoService.refresh(force: true)
        return updated.id
    }

    func createReminder(trimmedTitle: String, trimmedBody: String) async throws -> UUID {
        let draft = ReminderDraft(
            title: trimmedTitle.isEmpty ? "Reminder" : trimmedTitle,
            notes: trimmedBody.nilIfEmpty,
            status: reminderStatus(for: status),
            priority: ReminderPriority(rawValue: priority.rawValue) ?? .medium,
            folderID: folderForAudience(.reminders)?.id,
            createdAt: Date(),
            updatedAt: Date(),
            triggers: triggers
        )
        let reminder = try await environment.reminderService.createReminder(from: draft)
        await environment.reminderService.refresh(force: true)
        return reminder.id
    }

    func createNote(trimmedTitle: String, trimmedBody: String) async throws -> UUID {
        let note = try await environment.noteService.createNote(
            title: trimmedTitle,
            content: trimmedBody,
            folderID: folderForAudience(.notes)?.id,
            tagIDs: [],
            isPinned: isPinned
        )
        await environment.noteService.refresh(force: true)
        return note.id
    }

    func createTodoList(trimmedTitle: String,
                        trimmedBody: String,
                        sanitizedChecklist: [CheckItemDraft]) async throws -> UUID {
        let fallbackItems: [CheckItemDraft] = sanitizedChecklist.isEmpty ? [CheckItemDraft(title: trimmedTitle.isEmpty ? "Item" : trimmedTitle, sortOrder: 0)] : sanitizedChecklist
        let items = fallbackItems.enumerated().map { index, draft in
            draft.toModel(at: index)
        }

        let list = try await environment.todoService.createList(
            title: trimmedTitle.isEmpty ? "Checklist" : trimmedTitle,
            notes: trimmedBody.nilIfEmpty,
            dueDate: dueDateEnabled ? dueDate : nil,
            isPinned: isPinned,
            folderID: folderForAudience(.todos)?.id,
            items: items
        )
        await environment.todoService.refresh(force: true)
        return list.id
    }

    func folderForAudience(_ audience: FolderAudience) -> FolderModel? {
        guard let selectedSpaceID else {
            return environment.folderService.defaultFolder(for: audience)
        }

        if selectedSpaceID == SpaceModel.allSpacesIdentifier || selectedSpaceID == SpaceModel.inboxIdentifier {
            return environment.folderService.defaultFolder(for: audience)
        }

        if let space = environment.spaceService.space(id: selectedSpaceID) ?? selectedSpace,
           let folder = space.legacyFolder {
            return folder
        }

        if let folder = environment.folderService.folders.first(where: { $0.id == selectedSpaceID }) {
            return folder
        }

        return environment.folderService.defaultFolder(for: audience)
    }

    func reminderStatus(for memoryStatus: MemoryStatus) -> ReminderStatus {
        switch memoryStatus {
        case .active: return .active
        case .completed: return .completed
        case .archived: return .archived
        }
    }

    func draft(from model: MemoryTriggerModel) -> MemoryTriggerDraft {
        MemoryTriggerDraft(
            id: model.id,
            type: model.type,
            fireDate: model.fireDate,
            startDate: model.startDate,
            recurrenceRule: model.recurrenceRule,
            timeZoneIdentifier: model.timeZoneIdentifier,
            weekdayMask: model.weekdayMask,
            isActive: model.isActive,
            location: model.location,
            person: model.person,
            sequential: model.sequential,
            spacedStage: model.spacedStage,
            lastReviewDate: model.lastReviewDate,
            ignoreCount: model.ignoreCount
        )
    }

    func updateTimeTrigger(fireDate: Date?, recurrence: RecurrenceRule?) {
        let existingIndex = triggers.firstIndex { $0.type == .time }

        guard let fireDate else {
            if let existingIndex {
                triggers.remove(at: existingIndex)
            }
            return
        }

        let identifier = existingIndex.map { triggers[$0].id } ?? UUID()
        let draft = MemoryTriggerDraft(
            id: identifier,
            type: .time,
            fireDate: fireDate,
            startDate: fireDate,
            recurrenceRule: recurrence,
            timeZoneIdentifier: TimeZone.current.identifier,
            weekdayMask: 0,
            isActive: true
        )

        if let existingIndex {
            triggers[existingIndex] = draft
        } else {
            triggers.append(draft)
        }
    }

    func updateWeekdayTrigger(weekdaySelection: Set<Int>, referenceTime: Date) {
        let mask = weekdaySelection.reduce(into: Int16(0)) { partialResult, day in
            partialResult |= Int16(1 << day)
        }

        if mask == 0 {
            triggers.removeAll { $0.type == .dayOfWeek }
            return
        }

        let calendar = Calendar.current
        var components = calendar.dateComponents([.hour, .minute, .second], from: referenceTime)

        if components.hour == nil || components.minute == nil {
            components.hour = calendar.component(.hour, from: Date())
            components.minute = calendar.component(.minute, from: Date())
            components.second = 0
        }

        let fireDate = calendar.nextDate(after: Date(), matching: components, matchingPolicy: .nextTime) ?? referenceTime

        let existingIndex = triggers.firstIndex(where: { $0.type == .dayOfWeek })
        let identifier = existingIndex.map { triggers[$0].id } ?? UUID()
        let draft = MemoryTriggerDraft(
            id: identifier,
            type: .dayOfWeek,
            fireDate: fireDate,
            startDate: referenceTime,
            timeZoneIdentifier: TimeZone.current.identifier,
            weekdayMask: mask,
            isActive: true
        )

        if let existingIndex {
            triggers[existingIndex] = draft
        } else {
            triggers.append(draft)
        }
    }
}
