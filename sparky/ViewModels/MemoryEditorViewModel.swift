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
    // New config-based trigger properties
    @Published var scheduleConfig: ScheduleConfigDraft?
    @Published var locationConfig: LocationConfigDraft?
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

    var hasScheduleTrigger: Bool {
        scheduleConfig?.isActive ?? false
    }

    var hasLocationTrigger: Bool {
        locationConfig?.isActive ?? false
    }

    var hasAnyTrigger: Bool {
        hasScheduleTrigger || hasLocationTrigger
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

        // Compare schedule config
        let hasOriginalSchedule = original.scheduleConfig != nil
        let hasCurrentSchedule = scheduleConfig != nil
        if hasOriginalSchedule != hasCurrentSchedule { return true }
        if let origSchedule = original.scheduleConfig, let currSchedule = scheduleConfig {
            if origSchedule.id != currSchedule.id ||
               origSchedule.fireDate != currSchedule.fireDate ||
               origSchedule.recurrenceRule != currSchedule.recurrenceRule ||
               origSchedule.weekdayMask != currSchedule.weekdayMask ||
               origSchedule.isActive != currSchedule.isActive ||
               origSchedule.isAllDay != currSchedule.isAllDay {
                return true
            }
        }

        // Compare location config
        let hasOriginalLocation = original.locationConfig != nil
        let hasCurrentLocation = locationConfig != nil
        if hasOriginalLocation != hasCurrentLocation { return true }
        if let origLocation = original.locationConfig, let currLocation = locationConfig {
            if origLocation.id != currLocation.id ||
               origLocation.latitude != currLocation.latitude ||
               origLocation.longitude != currLocation.longitude ||
               origLocation.radius != currLocation.radius ||
               origLocation.event != currLocation.event ||
               origLocation.isActive != currLocation.isActive {
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

    // MARK: - Schedule Config Methods

    func setScheduleConfig(
        fireDate: Date?,
        recurrence: RecurrenceRule?,
        weekdaySelection: Set<Int>,
        referenceTime: Date,
        isAllDay: Bool = false
    ) {
        guard let fireDate = fireDate else {
            removeScheduleConfig()
            return
        }

        let mask = weekdaySelection.reduce(into: Int16(0)) { partialResult, day in
            partialResult |= Int16(1 << day)
        }

        let existingID = scheduleConfig?.id ?? UUID()

        scheduleConfig = ScheduleConfigDraft(
            id: existingID,
            fireDate: fireDate,
            startDate: fireDate,
            recurrenceRule: recurrence,
            timeZoneIdentifier: TimeZone.current.identifier,
            weekdayMask: mask,
            isActive: true,
            isAllDay: isAllDay
        )
    }

    func removeScheduleConfig() {
        scheduleConfig = nil
    }

    // MARK: - Location Config Methods

    func setLocationConfig(name: String, latitude: Double, longitude: Double, radius: Double, event: LocationEvent) {
        let existingID = locationConfig?.id ?? UUID()

        locationConfig = LocationConfigDraft(
            id: existingID,
            latitude: latitude,
            longitude: longitude,
            radius: radius,
            name: name,
            event: event,
            isActive: true
        )
    }

    func removeLocationConfig() {
        locationConfig = nil
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

        let draft = MemoryDraft(
            id: editingMemoryID ?? UUID(),
            title: trimmedTitle,
            status: status,
            isPinned: isPinned,
            dueDate: nil,
            lobeID: selectedLobeID,
            scheduleConfigDraft: scheduleConfig,
            locationConfigDraft: locationConfig,
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

        let draft = MemoryDraft(
            id: memoryID,
            title: existingMemory.title,
            status: status,
            isPinned: isPinned,
            dueDate: nil,
            lobeID: selectedLobeID,
            scheduleConfigDraft: scheduleConfig,
            locationConfigDraft: locationConfig,
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
        autoCompleteChecklist = memory.autoCompleteOnChecklistCompletion

        // Load trigger configs
        if let schedule = memory.scheduleConfig {
            scheduleConfig = ScheduleConfigDraft.from(schedule)
        } else {
            scheduleConfig = nil
        }

        if let location = memory.locationConfig {
            locationConfig = LocationConfigDraft.from(location)
        } else {
            locationConfig = nil
        }

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
            scheduleConfig = ScheduleConfigDraft(
                fireDate: fireDate,
                startDate: fireDate,
                timeZoneIdentifier: TimeZone.current.identifier,
                isActive: true
            )
        }
    }
}
