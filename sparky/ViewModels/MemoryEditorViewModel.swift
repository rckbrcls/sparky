//
//  MemoryEditorViewModel.swift
//  sparky
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
    @Published var selectedLobeID: UUID?
    @Published var status: MemoryStatus = .active
    @Published var isPinned: Bool = false
    @Published var autoCompleteChecklist: Bool
    @Published var triggers: [MemoryTriggerDraft] = []
    // Fixed content properties (replacing dynamic contentQueue)
    @Published var note: String = ""
    @Published var checkItems: [CheckItemDraft] = []
    @Published var photoAttachments: [Memory.Attachment] = []
    @Published var linkAttachments: [Memory.Attachment] = []
    @Published var audioAttachments: [Memory.Attachment] = []
    @Published var fileAttachments: [Memory.Attachment] = []
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?

    let environment: AppEnvironment
    private let attachmentStore: MemoryAttachmentStore
    private var existingMemory: Memory?
    private var persistedMemoryID: UUID?
    private let template: MemoryEditorTemplate
    private let defaultLobe: Space?

    init(environment: AppEnvironment,
         attachmentStore: MemoryAttachmentStore,
         memory: Memory?,
         defaultLobe: Space?,
         template: MemoryEditorTemplate,
         initialTitle: String = "") {
        self.environment = environment
        self.attachmentStore = attachmentStore
        self.existingMemory = memory
        self.template = template
        self.defaultLobe = defaultLobe
        self.autoCompleteChecklist = memory?.autoCompleteOnChecklistCompletion ?? false
        self.persistedMemoryID = memory?.id
        self.title = initialTitle
        configureInitialState()
    }

    var availableLobes: [Space] {
        environment.lobeService.lobes
    }

    var editingMemoryID: UUID? {
        persistedMemoryID ?? existingMemory?.id
    }

    var selectedLobe: Space? {
        guard let id = selectedLobeID else { return nil }
        if let lobe = environment.lobeService.lobe(id: id) {
            return lobe
        }
        if id == Space.allSpacesIdentifier {
            return Space.allSpaces
        }
        if id == Space.inboxIdentifier {
            return Space.inbox
        }
        return nil
    }

    var canToggleAutoComplete: Bool {
        !checkItems.isEmpty
    }



    var hasAnyAttachment: Bool {
        !photoAttachments.isEmpty || !linkAttachments.isEmpty || !audioAttachments.isEmpty || !fileAttachments.isEmpty
    }

    var hasAnyTrigger: Bool {
        triggers.contains { $0.type == .scheduled } ||
        triggers.contains { $0.type == .location }
    }

    var hasScheduleTrigger: Bool {
        triggers.contains { $0.type == .scheduled }
    }

    var hasLocationTrigger: Bool {
        triggers.contains { $0.type == .location }
    }

    /// Returns the current schedule configuration as a draft for editing
    var scheduleConfig: ScheduleConfigDraft? {
        guard let trigger = triggers.first(where: { $0.type == .scheduled }) else { return nil }
        return ScheduleConfigDraft(
            id: trigger.id,
            fireDate: trigger.fireDate,
            startDate: trigger.startDate,
            recurrenceRule: trigger.recurrenceRule,
            timeZoneIdentifier: trigger.timeZoneIdentifier,
            weekdayMask: trigger.weekdayMask,
            isActive: trigger.isActive,
            isAllDay: trigger.isAllDay
        )
    }

    /// Returns the current location configuration as a draft for editing
    var locationConfig: LocationConfigDraft? {
        guard let trigger = triggers.first(where: { $0.type == .location }),
              let location = trigger.location else { return nil }
        return LocationConfigDraft(
            latitude: location.latitude,
            longitude: location.longitude,
            radius: location.radius,
            name: location.name,
            event: location.event
        )
    }

    var currentMemory: Memory? {
        guard let memoryID = editingMemoryID else { return nil }
        return environment.memoryService.memory(id: memoryID)
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
        if selectedLobeID != original.lobe?.id { return true }
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

    private var allAttachments: [Memory.Attachment] {
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
    func addPhotoAttachment(data: Data) -> Memory.Attachment {
        let attachment = Memory.Attachment(
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
    func addLinkAttachment(url: URL) -> Memory.Attachment? {
        let alreadyExists = linkAttachments.contains { $0.url?.absoluteString == url.absoluteString }
        guard !alreadyExists else { return nil }

        let attachment = Memory.Attachment(
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
    func addAudioAttachment(data: Data, sourceURL: URL?) -> Memory.Attachment {
        let attachment = Memory.Attachment(
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
    func addFileAttachment(data: Data, filename: String?, sourceURL: URL?) -> Memory.Attachment {
        let attachment = Memory.Attachment(
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

    /// Convenience method to set schedule config (same as setScheduledTrigger but with different naming for views)
    func setScheduleConfig(
        fireDate: Date?,
        recurrence: RecurrenceRule?,
        weekdaySelection: Set<Int>,
        referenceTime: Date,
        isAllDay: Bool = false
    ) {
        setScheduledTrigger(
            fireDate: fireDate,
            recurrence: recurrence,
            weekdaySelection: weekdaySelection,
            referenceTime: referenceTime,
            isAllDay: isAllDay
        )
    }

    /// Removes the schedule trigger
    func removeScheduleConfig() {
        triggers.removeAll { $0.type == .scheduled }
    }

    /// Sets or updates the location trigger configuration
    func setLocationConfig(name: String, latitude: Double, longitude: Double, radius: Double, event: LocationEvent) {
        // Remove existing location trigger first
        triggers.removeAll { $0.type == .location }
        // Add new one
        addLocationTrigger(name: name, latitude: latitude, longitude: longitude, radius: radius, event: event)
    }

    /// Removes the location trigger
    func removeLocationConfig() {
        triggers.removeAll { $0.type == .location }
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
            lobeID: selectedLobeID,
            triggers: triggerModels,
            note: trimmedNote.isEmpty ? nil : trimmedNote,
            checkItems: checkItems,
            photoAttachmentIDs: photoAttachments.map(\.id),
            linkAttachmentIDs: linkAttachments.map(\.id),
            audioAttachmentIDs: audioAttachments.map(\.id),
            fileAttachmentIDs: fileAttachments.map(\.id),
            attachments: allAttachments,
            autoCompleteOnChecklistCompletion: autoCompleteChecklist,
            completedDates: existingMemory?.completedDates ?? []
        )

        isSaving = true
        defer { isSaving = false }

        do {
            let savedMemory: Memory
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
            lobeID: selectedLobeID,
            triggers: triggerModels,
            note: trimmedNote.isEmpty ? nil : trimmedNote,
            checkItems: checkItems,
            photoAttachmentIDs: photoAttachments.map(\.id),
            linkAttachmentIDs: linkAttachments.map(\.id),
            audioAttachmentIDs: audioAttachments.map(\.id),
            fileAttachmentIDs: fileAttachments.map(\.id),
            attachments: allAttachments,
            autoCompleteOnChecklistCompletion: autoCompleteChecklist,
            completedDates: existingMemory.completedDates
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
            // When creating a new memory, prefer the provided defaultLobe (if any)
            // so that creations from a specific lobe/sublobe are scoped correctly.
            // If it's the "All" lobe, default to no lobe (nil)
            if defaultLobe?.isAllSpaces == true {
                selectedLobeID = nil
            } else {
                selectedLobeID = defaultLobe?.id
            }
            applyTemplate(template)
        }
    }

    func apply(memory: Memory) {
        persistedMemoryID = memory.id
        title = memory.title
        selectedLobeID = memory.lobe?.id
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
        let location = model.location.map {
            MemoryTriggerModel.TriggerLocation(
                latitude: $0.latitude,
                longitude: $0.longitude,
                radius: $0.radius,
                name: $0.name,
                event: $0.event
            )
        }



        return MemoryTriggerDraft(
            id: model.id,
            type: model.type,
            fireDate: model.fireDate,
            startDate: model.startDate,
            recurrenceRule: model.recurrenceRule,
            timeZoneIdentifier: model.timeZoneIdentifier,
            weekdayMask: model.weekdayMask,
            isActive: model.isActive,
            isAllDay: model.isAllDay,
            location: location,
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
