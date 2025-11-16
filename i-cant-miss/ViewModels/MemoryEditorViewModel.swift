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
    @Published var autoCompleteChecklist: Bool
    @Published var triggers: [MemoryTriggerDraft] = []
    @Published var contentQueue: [MemoryEditorContentItem] = []
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?

    let environment: AppEnvironment
    private let attachmentStore: MemoryAttachmentStore
    private var existingMemory: MemoryModel?
    private var persistedMemoryID: UUID?
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
        self.autoCompleteChecklist = memory?.autoCompleteOnChecklistCompletion ?? false
        self.persistedMemoryID = memory?.id
        configureInitialState()
    }

    var availableSpaces: [SpaceModel] {
        environment.spaceService.spaces
    }

    var editingMemoryID: UUID? {
        persistedMemoryID ?? existingMemory?.id
    }

    var selectedSpace: SpaceModel? {
        guard let id = selectedSpaceID else { return nil }
        if let space = environment.spaceService.space(id: id) {
            return space
        }
        if id == SpaceModel.allSpacesIdentifier {
            return SpaceModel.allSpaces
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

    var allAudioAttachments: [MemoryModel.Attachment] {
        contentQueue.flatMap { $0.audioContent?.clips ?? [] }
    }

    var allFileAttachments: [MemoryModel.Attachment] {
        contentQueue.flatMap { $0.filesContent?.files ?? [] }
    }

    private var allAttachments: [MemoryModel.Attachment] {
        allPhotoAttachments + allLinkAttachments + allAudioAttachments + allFileAttachments
    }

    func loadLatestDataIfNeeded() async {
        guard let id = editingMemoryID else { return }
        guard let latest = environment.memoryService.memory(id: id) else { return }
        apply(memory: latest)
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
        case .audio:
            item = .audio(MemoryEditorAudioContent())
        case .files:
            item = .files(MemoryEditorFilesContent())
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
    func addAudioAttachment(data: Data, sourceURL: URL?, to contentID: UUID) -> MemoryModel.Attachment? {
        guard let index = contentQueue.firstIndex(where: { $0.id == contentID }) else { return nil }
        var addedAttachment: MemoryModel.Attachment?
        contentQueue[index].mutateAudio { audioContent in
            let attachment = MemoryModel.Attachment(
                id: UUID(),
                kind: .audio,
                data: data,
                createdAt: Date(),
                url: sourceURL
            )
            audioContent.clips.append(attachment)
            addedAttachment = attachment
        }
        return addedAttachment
    }

    @MainActor
    func removeAudioAttachment(id: UUID, from contentID: UUID) {
        guard let index = contentQueue.firstIndex(where: { $0.id == contentID }) else { return }
        contentQueue[index].mutateAudio { audioContent in
            audioContent.clips.removeAll { $0.id == id }
        }
    }

    @MainActor
    func addFileAttachment(data: Data, filename: String?, sourceURL: URL?, to contentID: UUID) -> MemoryModel.Attachment? {
        guard let index = contentQueue.firstIndex(where: { $0.id == contentID }) else { return nil }
        var addedAttachment: MemoryModel.Attachment?
        contentQueue[index].mutateFiles { filesContent in
            let attachment = MemoryModel.Attachment(
                id: UUID(),
                kind: .file,
                data: data,
                createdAt: Date(),
                url: sourceURL,
                filename: filename
            )
            filesContent.files.append(attachment)
            addedAttachment = attachment
        }
        return addedAttachment
    }

    @MainActor
    func removeFileAttachment(id: UUID, from contentID: UUID) {
        guard let index = contentQueue.firstIndex(where: { $0.id == contentID }) else { return }
        contentQueue[index].mutateFiles { filesContent in
            filesContent.files.removeAll { $0.id == id }
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
            case .audio:
                return .audio(MemoryEditorAudioContent(id: item.id, clips: []))
            case .files:
                return .files(MemoryEditorFilesContent(id: item.id, files: []))
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
            case .audio(var content):
                content.clips.removeAll { !ids.contains($0.id) }
                return .audio(content)
            case .files(var content):
                content.files.removeAll { !ids.contains($0.id) }
                return .files(content)
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
        setScheduledTrigger(
            fireDate: fireDate,
            recurrence: recurrence,
            weekdaySelection: weekdaySelection,
            referenceTime: weekdayReferenceTime
        )
    }

    func setScheduledTrigger(
        fireDate: Date?,
        recurrence: RecurrenceRule?,
        weekdaySelection: Set<Int>,
        referenceTime: Date
    ) {
        updateScheduledTrigger(
            fireDate: fireDate,
            recurrence: recurrence,
            weekdaySelection: weekdaySelection,
            referenceTime: referenceTime
        )
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
        triggers.removeAll { $0.type == .scheduled }
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

        let contents = contentsRepresentation()
        let attachments = allAttachments
        let triggerModels = triggers.map { $0.toModel() }

        let draft = MemoryDraft(
            id: editingMemoryID ?? UUID(),
            title: trimmedTitle,
            status: status,
            priority: priority,
            isPinned: isPinned,
            dueDate: nil,
            spaceID: selectedSpaceID,
            triggers: triggerModels,
            contents: contents,
            attachments: attachments,
            autoCompleteOnChecklistCompletion: autoCompleteChecklist
        )

        isSaving = true
        defer { isSaving = false }

        do {
            let savedMemory: MemoryModel
            if editingMemoryID != nil {
                savedMemory = try await environment.memoryService.updateMemory(from: draft)
            } else {
                savedMemory = try await environment.memoryService.createMemory(from: draft)
            }
            existingMemory = savedMemory
            persistedMemoryID = savedMemory.id
            return true
        } catch {
            errorMessage = "Unable to save memory."
            return false
        }
    }

    func saveMetadataOnly() async -> Bool {
        guard let memoryID = editingMemoryID else {
            return false
        }

        guard let existingMemory = existingMemory else {
            return false
        }

        let contents = contentsRepresentation()
        let attachments = allAttachments
        let triggerModels = triggers.map { $0.toModel() }

        let draft = MemoryDraft(
            id: memoryID,
            title: existingMemory.title,
            status: status,
            priority: priority,
            isPinned: isPinned,
            dueDate: nil,
            spaceID: selectedSpaceID,
            triggers: triggerModels,
            contents: contents,
            attachments: attachments,
            autoCompleteOnChecklistCompletion: autoCompleteChecklist
        )

        isSaving = true
        defer { isSaving = false }

        do {
            let savedMemory = try await environment.memoryService.updateMemory(from: draft)
            self.existingMemory = savedMemory
            persistedMemoryID = savedMemory.id
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
            // When creating a new memory, prefer the provided defaultSpace (if any)
            // so that creations from a specific space/subspace are scoped correctly.
            selectedSpaceID = defaultSpace?.id
            contentQueue = []
            applyTemplate(template)
        }
    }

    func apply(memory: MemoryModel) {
        persistedMemoryID = memory.id
        title = memory.title
        selectedSpaceID = memory.space?.id
        status = memory.status
        priority = memory.priority ?? .medium
        isPinned = memory.isPinned
        triggers = memory.triggers.map { draft(from: $0) }
        autoCompleteChecklist = memory.autoCompleteOnChecklistCompletion

        let attachments = memory.attachments
        let contents = memory.contents

        rebuildContentQueue(from: contents, attachments: attachments)
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
                type: .scheduled,
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

    func updateScheduledTrigger(
        fireDate: Date?,
        recurrence: RecurrenceRule?,
        weekdaySelection: Set<Int>,
        referenceTime: Date
    ) {
        let mask = weekdaySelection.reduce(into: Int16(0)) { partialResult, day in
            partialResult |= Int16(1 << day)
        }

        // If there's no fireDate, remove trigger
        guard let fireDate = fireDate else {
            triggers.removeAll { $0.type == .scheduled }
            return
        }

        let existingIndex = triggers.firstIndex { $0.type == .scheduled }
        let identifier = existingIndex.map { triggers[$0].id } ?? UUID()

        let draft = MemoryTriggerDraft(
            id: identifier,
            type: .scheduled,
            fireDate: fireDate,
            startDate: fireDate,
            recurrenceRule: recurrence,
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
            case .richText(let text):
                queue.append(.richText(MemoryEditorRichTextContent(id: UUID(), text: text)))
            case .checklist(let items):
                let drafts = items.sorted(by: { $0.sortOrder < $1.sortOrder }).map { item in
                    CheckItemDraft(
                        id: item.id,
                        title: item.title,
                        detail: item.detail ?? "",
                        isCompleted: item.isCompleted,
                        sortOrder: item.sortOrder,
                        createdAt: item.createdAt,
                        completedAt: item.completedAt
                    )
                }
                queue.append(.checklist(MemoryEditorChecklistContent(id: UUID(), items: drafts)))
            case .photos(let attachmentIDs):
                let attachmentsForContent = attachmentIDs.compactMap { attachmentLookup[$0] }
                queue.append(.photos(MemoryEditorPhotosContent(id: UUID(), attachments: attachmentsForContent)))
            case .links(let attachmentIDs):
                let attachmentsForContent = attachmentIDs.compactMap { attachmentLookup[$0] }
                queue.append(.links(MemoryEditorLinksContent(id: UUID(), links: attachmentsForContent)))
            case .audio(let attachmentIDs):
                let attachmentsForContent = attachmentIDs.compactMap { attachmentLookup[$0] }
                queue.append(.audio(MemoryEditorAudioContent(id: UUID(), clips: attachmentsForContent)))
            case .files(let attachmentIDs):
                let attachmentsForContent = attachmentIDs.compactMap { attachmentLookup[$0] }
                queue.append(.files(MemoryEditorFilesContent(id: UUID(), files: attachmentsForContent)))
            }
        }

        contentQueue = queue
    }

    func contentsRepresentation() -> [MemoryContent] {
        contentQueue.map { item in
            switch item {
            case .richText(let content):
                return .richText(content.text)
            case .checklist(let content):
                let items = content.items.enumerated().map { index, draft in
                    CheckItemModel(
                        id: draft.id,
                        title: draft.title,
                        detail: draft.detail.isEmpty ? nil : draft.detail,
                        isCompleted: draft.isCompleted,
                        sortOrder: index,
                        createdAt: draft.createdAt,
                        updatedAt: draft.completedAt ?? draft.createdAt,
                        completedAt: draft.completedAt
                    )
                }
                return .checklist(items)
            case .photos(let content):
                return .photos(content.attachments.map(\.id))
            case .links(let content):
                return .links(content.links.map(\.id))
            case .audio(let content):
                return .audio(content.clips.map(\.id))
            case .files(let content):
                return .files(content.files.map(\.id))
            }
        }
    }

}
