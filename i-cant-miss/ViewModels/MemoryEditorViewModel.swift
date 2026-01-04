//
//  MemoryEditorViewModel.swift
//  i-cant-miss
//
//  Created by Codex on 09/03/24.
//

import Foundation
import Combine
import SwiftUI

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
    @Published var isPinned: Bool = false
    @Published var autoCompleteChecklist: Bool
    @Published var triggers: [MemoryTriggerDraft] = []
    // Fixed content properties (replacing dynamic contentQueue)
    @Published var note: String = ""
    @Published var checkItems: [CheckItemDraft] = []
    @Published var photoAttachments: [MemoryModel.Attachment] = []
    @Published var linkAttachments: [MemoryModel.Attachment] = []
    @Published var audioAttachments: [MemoryModel.Attachment] = []
    @Published var fileAttachments: [MemoryModel.Attachment] = []
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
         template: MemoryEditorTemplate,
         initialTitle: String = "") {
        self.environment = environment
        self.attachmentStore = attachmentStore
        self.existingMemory = memory
        self.template = template
        self.defaultSpace = defaultSpace
        self.autoCompleteChecklist = memory?.autoCompleteOnChecklistCompletion ?? false
        self.persistedMemoryID = memory?.id
        self.title = initialTitle
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
        !checkItems.isEmpty
    }

    var sequentialTrigger: MemoryTriggerDraft? {
        triggers.first(where: { $0.type == .sequential })
    }

    var hasAnyAttachment: Bool {
        !photoAttachments.isEmpty || !linkAttachments.isEmpty || !audioAttachments.isEmpty || !fileAttachments.isEmpty
    }

    var hasAnyTrigger: Bool {
        triggers.contains { $0.type == .scheduled } ||
        triggers.contains { $0.type == .location } ||
        triggers.contains { $0.type == .location } ||
        sequentialTrigger?.sequential != nil
    }

    var aggregatedBody: String {
        note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Returns true if the current editor state differs from the original memory.
    /// For new memories (create mode), always returns true since there's nothing to compare.
    var hasChanges: Bool {
        guard let original = existingMemory else {
            // Create mode - always allow saving if title is valid
            return true
        }

        // Compare all editable fields with the original memory
        if title != original.title { return true }
        if status != original.status { return true }
        if isPinned != original.isPinned { return true }
        if selectedSpaceID != original.space?.id { return true }
        if autoCompleteChecklist != original.autoCompleteOnChecklistCompletion { return true }

        // Compare note
        let originalNote = original.note ?? ""
        if note != originalNote { return true }

        // Compare check items
        let originalCheckItems = original.checkItems.sorted(by: { $0.sortOrder < $1.sortOrder })
        if checkItems.count != originalCheckItems.count { return true }
        for (current, original) in zip(checkItems, originalCheckItems) {
            if current.id != original.id ||
               current.title != original.title ||
               current.detail != (original.detail ?? "") ||
               current.isCompleted != original.isCompleted ||
               current.sortOrder != original.sortOrder {
                return true
            }
        }

        // Compare triggers
        let originalTriggers = original.triggers
        if triggers.count != originalTriggers.count { return true }
        for (currentTrigger, originalTrigger) in zip(triggers, originalTriggers) {
            if currentTrigger.id != originalTrigger.id ||
               currentTrigger.type != originalTrigger.type ||
               currentTrigger.fireDate != originalTrigger.fireDate ||
               currentTrigger.recurrenceRule != originalTrigger.recurrenceRule ||
               currentTrigger.weekdayMask != originalTrigger.weekdayMask ||
               currentTrigger.isActive != originalTrigger.isActive ||
               currentTrigger.isAllDay != originalTrigger.isAllDay {
                return true
            }
        }

        // Compare attachments
        let originalPhotoIDs = Set(original.photoAttachmentIDs)
        let currentPhotoIDs = Set(photoAttachments.map(\.id))
        if originalPhotoIDs != currentPhotoIDs { return true }

        let originalLinkIDs = Set(original.linkAttachmentIDs)
        let currentLinkIDs = Set(linkAttachments.map(\.id))
        if originalLinkIDs != currentLinkIDs { return true }

        let originalAudioIDs = Set(original.audioAttachmentIDs)
        let currentAudioIDs = Set(audioAttachments.map(\.id))
        if originalAudioIDs != currentAudioIDs { return true }

        let originalFileIDs = Set(original.fileAttachmentIDs)
        let currentFileIDs = Set(fileAttachments.map(\.id))
        if originalFileIDs != currentFileIDs { return true }

        return false
    }

    private var allAttachments: [MemoryModel.Attachment] {
        photoAttachments + linkAttachments + audioAttachments + fileAttachments
    }

    func loadLatestDataIfNeeded() async {
        guard let id = editingMemoryID else { return }
        guard let latest = environment.memoryService.memory(id: id) else { return }
        apply(memory: latest)
    }

    // MARK: - Checklist Methods

    func addChecklistItem(title: String, detail: String = "") {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDetail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        let nextOrder = (checkItems.map(\.sortOrder).max() ?? -1) + 1
        let item = CheckItemDraft(
            title: trimmedTitle,
            detail: trimmedDetail,
            sortOrder: nextOrder
        )
        checkItems.append(item)
    }

    func removeChecklistItem(itemID: UUID) {
        checkItems.removeAll { $0.id == itemID }
        reindexCheckItems()
    }

    func toggleChecklistCompletion(for itemID: UUID) {
        guard let index = checkItems.firstIndex(where: { $0.id == itemID }) else { return }
        checkItems[index].isCompleted.toggle()
        checkItems[index].completedAt = checkItems[index].isCompleted
            ? (checkItems[index].completedAt ?? Date())
            : nil
    }

    private func reindexCheckItems() {
        for i in checkItems.indices {
            checkItems[i].sortOrder = i
        }
    }

    func moveChecklistItem(from source: IndexSet, to destination: Int) {
        checkItems.move(fromOffsets: source, toOffset: destination)
        reindexCheckItems()
    }

    // MARK: - Photo Attachment Methods

    @MainActor
    func addPhotoAttachment(data: Data) -> MemoryModel.Attachment {
        let attachment = MemoryModel.Attachment(
            id: UUID(),
            kind: .photo,
            data: data,
            createdAt: Date()
        )
        photoAttachments.append(attachment)
        return attachment
    }

    @MainActor
    func removePhotoAttachment(id: UUID) {
        photoAttachments.removeAll { $0.id == id }
    }

    // MARK: - Link Attachment Methods

    @MainActor
    func addLinkAttachment(url: URL) -> MemoryModel.Attachment? {
        let alreadyExists = linkAttachments.contains { $0.url?.absoluteString == url.absoluteString }
        guard !alreadyExists else { return nil }

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
    func removeLinkAttachment(id: UUID) {
        linkAttachments.removeAll { $0.id == id }
    }

    // MARK: - Audio Attachment Methods

    @MainActor
    func addAudioAttachment(data: Data, sourceURL: URL?) -> MemoryModel.Attachment {
        let attachment = MemoryModel.Attachment(
            id: UUID(),
            kind: .audio,
            data: data,
            createdAt: Date(),
            url: sourceURL
        )
        audioAttachments.append(attachment)
        return attachment
    }

    @MainActor
    func removeAudioAttachment(id: UUID) {
        audioAttachments.removeAll { $0.id == id }
    }

    // MARK: - File Attachment Methods

    @MainActor
    func addFileAttachment(data: Data, filename: String?, sourceURL: URL?) -> MemoryModel.Attachment {
        let attachment = MemoryModel.Attachment(
            id: UUID(),
            kind: .file,
            data: data,
            createdAt: Date(),
            url: sourceURL,
            filename: filename
        )
        fileAttachments.append(attachment)
        return attachment
    }

    @MainActor
    func removeFileAttachment(id: UUID) {
        fileAttachments.removeAll { $0.id == id }
    }

    // MARK: - Sync Attachments

    @MainActor
    func syncAttachments(withReferencedIDs ids: Set<UUID>) {
        guard !ids.isEmpty else {
            photoAttachments = []
            linkAttachments = []
            audioAttachments = []
            fileAttachments = []
            return
        }
        photoAttachments.removeAll { !ids.contains($0.id) }
        linkAttachments.removeAll { !ids.contains($0.id) }
        audioAttachments.removeAll { !ids.contains($0.id) }
        fileAttachments.removeAll { !ids.contains($0.id) }
    }

    func updateSchedule(
        fireDate: Date?,
        recurrence: RecurrenceRule?,
        weekdaySelection: Set<Int>,
        weekdayReferenceTime: Date,
        isAllDay: Bool = false
    ) {
        setScheduledTrigger(
            fireDate: fireDate,
            recurrence: recurrence,
            weekdaySelection: weekdaySelection,
            referenceTime: weekdayReferenceTime,
            isAllDay: isAllDay
        )
    }

    func setScheduledTrigger(
        fireDate: Date?,
        recurrence: RecurrenceRule?,
        weekdaySelection: Set<Int>,
        referenceTime: Date,
        isAllDay: Bool = false
    ) {
        updateScheduledTrigger(
            fireDate: fireDate,
            recurrence: recurrence,
            weekdaySelection: weekdaySelection,
            referenceTime: referenceTime,
            isAllDay: isAllDay
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

    func updateSequentialTrigger(sequenceID: UUID, stepIndex: Int, startDate: Date? = nil, currentStepIndex: Int = 0) {
        let sequential = MemoryTriggerModel.TriggerSequential(
            sequenceID: sequenceID,
            stepIndex: stepIndex,
            startDate: startDate,
            currentStepIndex: currentStepIndex
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

        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let triggerModels = triggers.map { $0.toModel() }

        let draft = MemoryDraft(
            id: editingMemoryID ?? UUID(),
            title: trimmedTitle,
            status: status,
            isPinned: isPinned,
            dueDate: nil,
            spaceID: selectedSpaceID,
            triggers: triggerModels,
            note: trimmedNote.isEmpty ? nil : trimmedNote,
            checkItems: checkItems,
            photoAttachmentIDs: photoAttachments.map(\.id),
            linkAttachmentIDs: linkAttachments.map(\.id),
            audioAttachmentIDs: audioAttachments.map(\.id),
            fileAttachmentIDs: fileAttachments.map(\.id),
            attachments: allAttachments,
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

        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let triggerModels = triggers.map { $0.toModel() }

        let draft = MemoryDraft(
            id: memoryID,
            title: existingMemory.title,
            status: status,
            isPinned: isPinned,
            dueDate: nil,
            spaceID: selectedSpaceID,
            triggers: triggerModels,
            note: trimmedNote.isEmpty ? nil : trimmedNote,
            checkItems: checkItems,
            photoAttachmentIDs: photoAttachments.map(\.id),
            linkAttachmentIDs: linkAttachments.map(\.id),
            audioAttachmentIDs: audioAttachments.map(\.id),
            fileAttachmentIDs: fileAttachments.map(\.id),
            attachments: allAttachments,
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
            // If it's the "All" space, default to no space (nil)
            if defaultSpace?.isAllSpaces == true {
                selectedSpaceID = nil
            } else {
                selectedSpaceID = defaultSpace?.id
            }
            applyTemplate(template)
        }
    }

    func apply(memory: MemoryModel) {
        persistedMemoryID = memory.id
        title = memory.title
        selectedSpaceID = memory.space?.id
        status = memory.status
        isPinned = memory.isPinned
        triggers = memory.triggers.map { draft(from: $0) }
        autoCompleteChecklist = memory.autoCompleteOnChecklistCompletion

        // Load fixed content fields
        note = memory.note ?? ""
        checkItems = memory.checkItems.sorted(by: { $0.sortOrder < $1.sortOrder }).map { item in
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

        // Load attachments by type
        let attachmentLookup = Dictionary(uniqueKeysWithValues: memory.attachments.map { ($0.id, $0) })
        photoAttachments = memory.photoAttachmentIDs.compactMap { attachmentLookup[$0] }
        linkAttachments = memory.linkAttachmentIDs.compactMap { attachmentLookup[$0] }
        audioAttachments = memory.audioAttachmentIDs.compactMap { attachmentLookup[$0] }
        fileAttachments = memory.fileAttachmentIDs.compactMap { attachmentLookup[$0] }
    }

    func applyTemplate(_ template: MemoryEditorTemplate) {
        switch template {
        case .blank:
            break
        case .checklist:
            // No need to add anything - checklist will be shown if checkItems exist or in editing mode
            break
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
            isAllDay: model.isAllDay,
            location: model.location,

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
        referenceTime: Date,
        isAllDay: Bool = false
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
            isActive: true,
            isAllDay: isAllDay
        )

        if let existingIndex {
            triggers[existingIndex] = draft
        } else {
            triggers.append(draft)
        }
    }
}
