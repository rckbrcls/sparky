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
    @Published var selectedSpaceID: UUID?
    @Published var status: MemoryStatus = .active
    @Published var priority: MemoryPriority = .medium
    @Published var isPinned: Bool = false
    @Published var dueDateEnabled: Bool = false
    @Published var dueDate: Date = Date().addingTimeInterval(3600)
    @Published var autoCompleteChecklist: Bool
    @Published var triggers: [MemoryTriggerDraft] = []
    @Published var contentQueue: [MemoryEditorContentItem] = []
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?

    let environment: AppEnvironment
    private let attachmentStore: MemoryAttachmentStore
    private var existingMemory: MemoryModel?
    private struct MemoryPersistenceIdentity {
        var id: UUID?
        var origin: MemoryModel.Metadata.Origin?
    }
    private var persistenceIdentity: MemoryPersistenceIdentity
    private let template: MemoryEditorTemplate
    private let defaultSpace: SpaceModel?

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
        self.persistenceIdentity = MemoryPersistenceIdentity(
            id: memory?.id,
            origin: memory?.metadata.origin
        )
        configureInitialState()
    }

    var availableSpaces: [SpaceModel] {
        environment.spaceService.spaces
    }

    var editingMemoryID: UUID? {
        persistenceIdentity.id ?? existingMemory?.id
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
        !allChecklistItems.isEmpty
    }

    var sequentialTrigger: MemoryTriggerDraft? {
        triggers.first(where: { $0.type == .sequential })
    }

    var aggregatedBody: String {
        contentQueue.compactMap { item -> String? in
            guard let richText = item.richTextContent else { return nil }
            let trimmed = richText.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        .joined(separator: "\n\n")
    }

    var allChecklistItems: [CheckItemDraft] {
        contentQueue.flatMap { $0.checklistContent?.items ?? [] }
    }

    var allPhotoAttachments: [MemoryModel.Attachment] {
        contentQueue.flatMap { $0.photosContent?.attachments ?? [] }
    }

    var allLinkAttachments: [MemoryModel.Attachment] {
        contentQueue.flatMap { $0.linksContent?.links ?? [] }
    }

    func loadLatestDataIfNeeded() async {
        if let origin = persistenceIdentity.origin, let id = persistenceIdentity.id {
            switch origin {
            case .reminder:
                if let reminder = environment.reminderService.fetchReminderWithRelationships(id: id) {
                    let attachments = await attachmentStore.attachments(for: reminder.id)
                    apply(reminder: reminder, attachments: attachments)
                }
            case .note:
                if let note = environment.noteService.fetchNoteWithRelationships(id: id) {
                    let attachments = await attachmentStore.attachments(for: note.id)
                    apply(note: note, attachments: attachments)
                }
            case .todoList:
                if let list = environment.todoService.fetchListWithItems(id: id) {
                    let attachments = await attachmentStore.attachments(for: list.id)
                    apply(todoList: list, attachments: attachments)
                }
            }
            return
        }

        guard let memory = existingMemory else { return }
        switch memory.metadata.origin {
        case .reminder(let id):
            if let reminder = environment.reminderService.fetchReminderWithRelationships(id: id) {
                let attachments = await attachmentStore.attachments(for: reminder.id)
                apply(reminder: reminder, attachments: attachments)
                persistenceIdentity = MemoryPersistenceIdentity(id: reminder.id, origin: .reminder(id))
            }
        case .note(let id):
            if let note = environment.noteService.fetchNoteWithRelationships(id: id) {
                let attachments = await attachmentStore.attachments(for: note.id)
                apply(note: note, attachments: attachments)
                persistenceIdentity = MemoryPersistenceIdentity(id: note.id, origin: .note(id))
            }
        case .todoList(let id):
            if let list = environment.todoService.fetchListWithItems(id: id) {
                let attachments = await attachmentStore.attachments(for: list.id)
                apply(todoList: list, attachments: attachments)
                persistenceIdentity = MemoryPersistenceIdentity(id: list.id, origin: .todoList(id))
            }
        case .none:
            break
        }
    }

    @discardableResult
    func appendContent(_ type: MemoryEditorContentType) -> UUID {
        let item: MemoryEditorContentItem
        switch type {
        case .richText:
            item = .richText(MemoryEditorRichTextContent())
        case .checklist:
            item = .checklist(MemoryEditorChecklistContent())
        case .photos:
            item = .photos(MemoryEditorPhotosContent())
        case .links:
            item = .links(MemoryEditorLinksContent())
        }
        contentQueue.append(item)
        return item.id
    }

    func removeContent(id: UUID) {
        contentQueue.removeAll { $0.id == id }
    }

    func updateRichText(id: UUID, text: String) {
        guard let index = contentQueue.firstIndex(where: { $0.id == id }) else { return }
        contentQueue[index].mutateRichText { richText in
            richText.text = text
        }
    }

    func addChecklistItem(to contentID: UUID, title: String, detail: String = "") {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        let trimmedDetail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let index = contentQueue.firstIndex(where: { $0.id == contentID }) else { return }
        contentQueue[index].mutateChecklist { checklist in
            let nextOrder = (checklist.items.map(\.sortOrder).max() ?? -1) + 1
            let item = CheckItemDraft(
                title: trimmedTitle,
                detail: trimmedDetail,
                sortOrder: nextOrder
            )
            checklist.items.append(item)
        }
    }

    func removeChecklistItem(contentID: UUID, itemID: UUID) {
        guard let index = contentQueue.firstIndex(where: { $0.id == contentID }) else { return }
        contentQueue[index].mutateChecklist { checklist in
            checklist.items.removeAll { $0.id == itemID }
            reindexChecklist(in: &checklist)
        }
    }

    func toggleChecklistCompletion(for itemID: UUID) {
        guard let index = contentQueue.firstIndex(where: { item in
            item.checklistContent?.items.contains(where: { $0.id == itemID }) ?? false
        }) else { return }
        contentQueue[index].mutateChecklist { checklist in
            guard let itemIndex = checklist.items.firstIndex(where: { $0.id == itemID }) else { return }
            checklist.items[itemIndex].isCompleted.toggle()
            checklist.items[itemIndex].completedAt = checklist.items[itemIndex].isCompleted
                ? (checklist.items[itemIndex].completedAt ?? Date())
                : nil
        }
    }

    @MainActor
    func addPhotoAttachment(data: Data, to contentID: UUID) -> MemoryModel.Attachment? {
        guard let index = contentQueue.firstIndex(where: { $0.id == contentID }) else { return nil }
        var addedAttachment: MemoryModel.Attachment?
        contentQueue[index].mutatePhotos { photos in
            let attachment = MemoryModel.Attachment(
                id: UUID(),
                kind: .photo,
                data: data,
                createdAt: Date()
            )
            photos.attachments.append(attachment)
            addedAttachment = attachment
        }
        return addedAttachment
    }

    @MainActor
    func addLinkAttachment(url: URL, to contentID: UUID) -> MemoryModel.Attachment? {
        guard let index = contentQueue.firstIndex(where: { $0.id == contentID }) else { return nil }
        var addedAttachment: MemoryModel.Attachment?
        contentQueue[index].mutateLinks { linksContent in
            let alreadyExists = linksContent.links.contains { $0.url?.absoluteString == url.absoluteString }
            guard !alreadyExists else { return }

            let attachment = MemoryModel.Attachment(
                id: UUID(),
                kind: .link,
                data: Data(),
                createdAt: Date(),
                url: url
            )
            linksContent.links.append(attachment)
            addedAttachment = attachment
        }
        return addedAttachment
    }

    @MainActor
    func removePhotoAttachment(id: UUID, from contentID: UUID) {
        guard let index = contentQueue.firstIndex(where: { $0.id == contentID }) else { return }
        contentQueue[index].mutatePhotos { photos in
            photos.attachments.removeAll { $0.id == id }
        }
    }

    @MainActor
    func removeLinkAttachment(id: UUID, from contentID: UUID) {
        guard let index = contentQueue.firstIndex(where: { $0.id == contentID }) else { return }
        contentQueue[index].mutateLinks { linksContent in
            linksContent.links.removeAll { $0.id == id }
        }
    }

    @MainActor
    func syncAttachments(withReferencedIDs ids: Set<UUID>) {
        guard !ids.isEmpty else {
            contentQueue = contentQueue.map { item in
                switch item {
                case .photos:
                    return .photos(MemoryEditorPhotosContent(id: item.id, attachments: []))
                case .links:
                    return .links(MemoryEditorLinksContent(id: item.id, links: []))
                default:
                    return item
                }
            }
            return
        }

        contentQueue = contentQueue.map { item in
            switch item {
            case .photos(var content):
                content.attachments.removeAll { !ids.contains($0.id) }
                return .photos(content)
            case .links(var content):
                content.links.removeAll { !ids.contains($0.id) }
                return .links(content)
            default:
                return item
            }
        }
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
        let trimmedBody = aggregatedBody.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitizedChecklist = sanitizedChecklistItems()
        let memoryContents = contentsRepresentation()

        isSaving = true
        defer { isSaving = false }

        do {
            let persistenceOutcome = try await persistMemory(
                trimmedTitle: trimmedTitle,
                trimmedBody: trimmedBody,
                sanitizedChecklist: sanitizedChecklist
            )
            persistenceIdentity = persistenceOutcome

            let attachments = allPhotoAttachments
            let links = allLinkAttachments
            let bundleAttachment = try MemoryContentCodec.attachment(from: memoryContents)
            var allAttachments: [MemoryModel.Attachment] = []
            if let bundleAttachment {
                allAttachments.append(bundleAttachment)
            }
            allAttachments.append(contentsOf: attachments)
            allAttachments.append(contentsOf: links)
            if let targetID = persistenceOutcome.id {
                try await attachmentStore.replaceAttachments(for: targetID, with: allAttachments)
            }
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
            selectedSpaceID = defaultSpace?.id ?? environment.spaceService.defaultSpace()?.id
            contentQueue = []
            applyTemplate(template)
        }
    }

    func apply(memory: MemoryModel) {
        persistenceIdentity = MemoryPersistenceIdentity(id: memory.id, origin: memory.metadata.origin)
        title = memory.title
        selectedSpaceID = memory.space?.id
        status = memory.status
        priority = memory.priority ?? .medium
        isPinned = memory.isPinned
        dueDateEnabled = memory.dueDate != nil
        dueDate = memory.dueDate ?? Date().addingTimeInterval(3600)
        triggers = memory.triggers.map { draft(from: $0) }
        autoCompleteChecklist = memory.metadata.autoCompleteOnChecklistCompletion

        let attachments = memory.attachments
        let contents = memory.contents.isEmpty
        ? MemoryContent.legacyContents(
            body: memory.body,
            checkItems: memory.checkItems,
            photoAttachments: attachments.filter { $0.kind == .photo },
            linkAttachments: attachments.filter { $0.kind == .link }
        )
        : memory.contents

        rebuildContentQueue(from: contents, attachments: attachments)
    }

    func apply(reminder: ReminderModel, attachments: [MemoryModel.Attachment]) {
        let trimmedTitle = reminder.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty {
            title = trimmedTitle
        }
        priority = MemoryPriority(rawValue: reminder.priority.rawValue) ?? .medium
        status = reminder.status == .archived ? .archived : (reminder.status == .completed ? .completed : .active)
        triggers = reminder.triggers.map { draft(from: $0) }
        isPinned = false
        if let folder = reminder.folder,
           let space = environment.spaceService.resolveSpace(for: folder) {
            selectedSpaceID = space.id
        } else {
            selectedSpaceID = nil
        }

        rebuildContentQueueUsingAttachments(
            attachments,
            fallbackBody: reminder.notes,
            fallbackChecklist: []
        )
    }

    func apply(note: NoteModel, attachments: [MemoryModel.Attachment]) {
        if let trimmedTitle = note.title?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty {
            title = trimmedTitle
        }
        isPinned = note.isPinned
        if let folder = note.folder,
           let space = environment.spaceService.resolveSpace(for: folder) {
            selectedSpaceID = space.id
        } else {
            selectedSpaceID = nil
        }

        rebuildContentQueueUsingAttachments(
            attachments,
            fallbackBody: note.content,
            fallbackChecklist: []
        )
    }

    func apply(todoList: TodoListModel, attachments: [MemoryModel.Attachment]) {
        let trimmedTitle = todoList.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty {
            title = trimmedTitle
        }
        isPinned = todoList.isPinned
        status = todoList.isArchived ? .archived : (todoList.isCompleted ? .completed : .active)
        dueDateEnabled = todoList.dueDate != nil
        dueDate = todoList.dueDate ?? Date().addingTimeInterval(3600)
        autoCompleteChecklist = existingMemory?.metadata.autoCompleteOnChecklistCompletion ?? autoCompleteChecklist
        if let folder = todoList.folder,
           let space = environment.spaceService.resolveSpace(for: folder) {
            selectedSpaceID = space.id
        } else {
            selectedSpaceID = nil
        }

        let checklistModels: [CheckItemModel] = todoList.items
            .sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder {
                    return lhs.sortOrder < rhs.sortOrder
                }
                return lhs.createdAt < rhs.createdAt
            }
            .map { item in
                CheckItemModel(
                    id: item.id,
                    title: item.title,
                    detail: item.detail,
                    isCompleted: item.isCompleted,
                    sortOrder: item.sortOrder,
                    createdAt: item.createdAt,
                    updatedAt: item.completedAt ?? item.createdAt,
                    completedAt: item.completedAt
                )
            }

        rebuildContentQueueUsingAttachments(
            attachments,
            fallbackBody: todoList.notes,
            fallbackChecklist: checklistModels
        )
    }

    func applyTemplate(_ template: MemoryEditorTemplate) {
        switch template {
        case .blank:
            break
        case .checklist:
            if !contentQueue.contains(where: { $0.contentType == .checklist }) {
                contentQueue.append(.checklist(MemoryEditorChecklistContent()))
            }
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

    func reindexChecklist(in content: inout MemoryEditorChecklistContent) {
        for index in content.items.indices {
            content.items[index].sortOrder = index
        }
    }

    func sanitizedChecklistItems() -> [CheckItemDraft] {
        var sanitized: [CheckItemDraft] = []
        for item in contentQueue {
            guard let checklist = item.checklistContent else { continue }
            for draft in checklist.items {
                let trimmed = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                var normalized = draft
                normalized.title = trimmed
                normalized.detail = draft.detail.trimmingCharacters(in: .whitespacesAndNewlines)
                normalized.sortOrder = sanitized.count
                sanitized.append(normalized)
            }
        }
        return sanitized
    }

    func persistMemory(trimmedTitle: String,
                       trimmedBody: String,
                       sanitizedChecklist: [CheckItemDraft]) async throws -> MemoryPersistenceIdentity {
        if let id = persistenceIdentity.id {
            return try await updateExistingMemory(
                id: id,
                origin: persistenceIdentity.origin,
                sanitizedChecklist: sanitizedChecklist
            )
        } else {
            return try await createNewMemory(
                trimmedTitle: trimmedTitle,
                trimmedBody: trimmedBody,
                sanitizedChecklist: sanitizedChecklist
            )
        }
    }

    func updateExistingMemory(id: UUID,
                              origin: MemoryModel.Metadata.Origin?,
                              sanitizedChecklist: [CheckItemDraft]) async throws -> MemoryPersistenceIdentity {
        if let origin {
            switch origin {
            case .reminder:
                let identifier = try await updateReminder(id: id)
                return MemoryPersistenceIdentity(id: identifier, origin: .reminder(identifier))
            case .note:
                let identifier = try await updateNote(id: id)
                return MemoryPersistenceIdentity(id: identifier, origin: .note(identifier))
            case .todoList:
                let identifier = try await updateTodoList(id: id, sanitizedChecklist: sanitizedChecklist)
                return MemoryPersistenceIdentity(id: identifier, origin: .todoList(identifier))
            }
        }

        if environment.reminderService.fetchReminderWithRelationships(id: id) != nil {
            let identifier = try await updateReminder(id: id)
            return MemoryPersistenceIdentity(id: identifier, origin: .reminder(identifier))
        }

        if environment.noteService.fetchNoteWithRelationships(id: id) != nil {
            let identifier = try await updateNote(id: id)
            return MemoryPersistenceIdentity(id: identifier, origin: .note(identifier))
        }

        if environment.todoService.fetchListWithItems(id: id) != nil {
            let identifier = try await updateTodoList(id: id, sanitizedChecklist: sanitizedChecklist)
            return MemoryPersistenceIdentity(id: identifier, origin: .todoList(identifier))
        }

        return try await createNewMemory(
            trimmedTitle: title.trimmingCharacters(in: .whitespacesAndNewlines),
            trimmedBody: aggregatedBody.trimmingCharacters(in: .whitespacesAndNewlines),
            sanitizedChecklist: sanitizedChecklist
        )
    }

    func createNewMemory(trimmedTitle: String,
                         trimmedBody: String,
                         sanitizedChecklist: [CheckItemDraft]) async throws -> MemoryPersistenceIdentity {
        if !triggers.isEmpty {
            let reminderID = try await createReminder(trimmedTitle: trimmedTitle, trimmedBody: trimmedBody)
            return MemoryPersistenceIdentity(id: reminderID, origin: .reminder(reminderID))
        } else if !sanitizedChecklist.isEmpty || dueDateEnabled {
            let listID = try await createTodoList(trimmedTitle: trimmedTitle,
                                                  trimmedBody: trimmedBody,
                                                  sanitizedChecklist: sanitizedChecklist)
            return MemoryPersistenceIdentity(id: listID, origin: .todoList(listID))
        } else {
            let noteID = try await createNote(trimmedTitle: trimmedTitle, trimmedBody: trimmedBody)
            return MemoryPersistenceIdentity(id: noteID, origin: .note(noteID))
        }
    }

    func updateReminder(id: UUID) async throws -> UUID {
        guard var reminder = environment.reminderService.fetchReminderWithRelationships(id: id)
                ?? environment.reminderService.reminders.first(where: { $0.id == id }) else {
            throw MemoryService.MemoryServiceError.memoryNotFound
        }

        reminder.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        reminder.notes = aggregatedBody.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
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
        let trimmedContent = aggregatedBody.trimmingCharacters(in: .whitespacesAndNewlines)

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
        list.notes = aggregatedBody.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
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
            return nil
        }

        if selectedSpaceID == SpaceModel.allSpacesIdentifier || selectedSpaceID == SpaceModel.inboxIdentifier {
            return environment.folderService.defaultFolder(for: audience)
        }

        if let space = environment.spaceService.space(id: selectedSpaceID) ?? selectedSpace,
           let folder = space.legacyFolder,
           folder.audience == audience {
            return folder
        }

        if let folder = environment.folderService.folders.first(where: { $0.id == selectedSpaceID && $0.audience == audience }) {
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

    func rebuildContentQueue(from contents: [MemoryContent],
                             attachments: [MemoryModel.Attachment]) {
        let attachmentLookup = Dictionary(uniqueKeysWithValues: attachments.map { ($0.id, $0) })
        var queue: [MemoryEditorContentItem] = []
        queue.reserveCapacity(contents.count)

        for content in contents {
            switch content {
            case .richText(let payload):
                queue.append(.richText(MemoryEditorRichTextContent(id: payload.id, text: payload.text)))
            case .checklist(let payload):
                let drafts = payload.items.sorted(by: { $0.sortOrder < $1.sortOrder }).map { item in
                    CheckItemDraft(
                        id: item.id,
                        title: item.title,
                        detail: item.detail,
                        isCompleted: item.isCompleted,
                        sortOrder: item.sortOrder,
                        createdAt: item.createdAt,
                        completedAt: item.completedAt
                    )
                }
                queue.append(.checklist(MemoryEditorChecklistContent(id: payload.id, items: drafts)))
            case .photos(let payload):
                let attachmentsForContent = payload.attachmentIDs.compactMap { attachmentLookup[$0] }
                queue.append(.photos(MemoryEditorPhotosContent(id: payload.id, attachments: attachmentsForContent)))
            case .links(let payload):
                let attachmentsForContent = payload.attachmentIDs.compactMap { attachmentLookup[$0] }
                queue.append(.links(MemoryEditorLinksContent(id: payload.id, links: attachmentsForContent)))
            }
        }

        contentQueue = queue
    }

    func contentsRepresentation() -> [MemoryContent] {
        contentQueue.map { item in
            switch item {
            case .richText(let content):
                return .richText(MemoryContent.RichTextContent(id: content.id, text: content.text))
            case .checklist(let content):
                let items = content.items.enumerated().map { index, draft in
                    MemoryContent.ChecklistContent.Item(
                        id: draft.id,
                        title: draft.title,
                        detail: draft.detail,
                        isCompleted: draft.isCompleted,
                        sortOrder: index,
                        createdAt: draft.createdAt,
                        updatedAt: draft.completedAt ?? draft.createdAt,
                        completedAt: draft.completedAt
                    )
                }
                return .checklist(MemoryContent.ChecklistContent(id: content.id, items: items))
            case .photos(let content):
                return .photos(MemoryContent.PhotosContent(id: content.id, attachmentIDs: content.attachments.map(\.id)))
            case .links(let content):
                return .links(MemoryContent.LinksContent(id: content.id, attachmentIDs: content.links.map(\.id)))
            }
        }
    }

    func rebuildContentQueueUsingAttachments(_ attachments: [MemoryModel.Attachment],
                                             fallbackBody: String?,
                                             fallbackChecklist: [CheckItemModel]) {
        let decodeResult = MemoryContentCodec.extractContents(from: attachments)
        let photoAttachments = decodeResult.remainingAttachments.filter { $0.kind == .photo }
        let linkAttachments = decodeResult.remainingAttachments.filter { $0.kind == .link }

        let contents: [MemoryContent]
        if decodeResult.contents.isEmpty {
            contents = MemoryContent.legacyContents(
                body: fallbackBody,
                checkItems: fallbackChecklist,
                photoAttachments: photoAttachments,
                linkAttachments: linkAttachments
            )
        } else {
            contents = decodeResult.contents
        }

        let referencedIDs = Set(contents.referencedAttachmentIDs())
        let filteredAttachments: [MemoryModel.Attachment]
        if referencedIDs.isEmpty {
            filteredAttachments = decodeResult.remainingAttachments
        } else {
            filteredAttachments = decodeResult.remainingAttachments.filter { referencedIDs.contains($0.id) }
        }

        rebuildContentQueue(from: contents, attachments: filteredAttachments)
    }
}
