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
    @Published var selectedMindID: UUID?
    @Published var status: MemoryStatus = .active
    @Published var isPinned: Bool = false
    @Published var scheduleConfigDraft: ScheduleConfigDraft?
    @Published var locationConfigDraft: LocationConfigDraft?
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
    private let defaultMind: Mind?

    init(environment: AppEnvironment,
         attachmentStore: MemoryAttachmentStore,
         memory: Memory?,
         defaultMind: Mind?,
         template: MemoryEditorTemplate,
         initialTitle: String = "") {
        self.environment = environment
        self.attachmentStore = attachmentStore
        self.existingMemory = memory
        self.template = template
        self.defaultMind = defaultMind
        self.persistedMemoryID = memory?.id
        self.title = initialTitle
        configureInitialState()
    }

    var availableMinds: [Mind] {
        environment.mindService.minds
    }

    var editingMemoryID: UUID? {
        persistedMemoryID ?? existingMemory?.id
    }

    var selectedMind: Mind? {
        guard let id = selectedMindID else { return nil }
        if let mind = environment.mindService.mind(id: id) {
            return mind
        }
        return nil
    }

    var hasAnyAttachment: Bool {
        !photoAttachments.isEmpty || !linkAttachments.isEmpty || !audioAttachments.isEmpty || !fileAttachments.isEmpty
    }

    var hasAnyTrigger: Bool {
        scheduleConfigDraft != nil || locationConfigDraft != nil
    }

    var hasScheduleTrigger: Bool {
        scheduleConfigDraft != nil
    }

    var hasLocationTrigger: Bool {
        locationConfigDraft != nil
    }

    var hasFocusEnabled: Bool {
        scheduleConfigDraft?.focusEnabled == true
    }

    var focusRecipe: FocusRecipe? {
        guard let scheduleConfigDraft else { return nil }
        return FocusRecipe.resolve(draft: scheduleConfigDraft)
    }

    /// Returns the current schedule configuration as a draft for editing
    var scheduleConfig: ScheduleConfigDraft? {
        scheduleConfigDraft
    }

    /// Returns the current location configuration as a draft for editing
    var locationConfig: LocationConfigDraft? {
        locationConfigDraft
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
        if selectedMindID != original.mind?.id { return true }
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
        let origSchedule = original.scheduleConfig
        if (scheduleConfigDraft == nil) != (origSchedule == nil) { return true }
        if let draft = scheduleConfigDraft, let orig = origSchedule {
            if draft.fireDate != orig.fireDate ||
               draft.recurrenceRule != orig.recurrenceRule ||
               draft.weekdayMask != orig.weekdayMask ||
               draft.isActive != orig.isActive ||
               draft.isAllDay != orig.isAllDay ||
               draft.recurrenceEndType != orig.recurrenceEndType ||
               draft.focusEnabled != orig.focusEnabled ||
               draft.focusWorkDurationMinutes != orig.focusWorkDurationMinutes ||
               draft.focusShortBreakDurationMinutes != orig.focusShortBreakDurationMinutes ||
               draft.focusLongBreakDurationMinutes != orig.focusLongBreakDurationMinutes ||
               draft.focusPomodorosUntilLongBreak != orig.focusPomodorosUntilLongBreak ||
               draft.focusAutoContinue != orig.focusAutoContinue {
                return true
            }
        }

        // Compare location config
        let origLocation = original.locationConfig
        if (locationConfigDraft == nil) != (origLocation == nil) { return true }
        if let draft = locationConfigDraft, let orig = origLocation {
            if draft.latitude != orig.latitude ||
               draft.longitude != orig.longitude ||
               draft.radius != orig.radius ||
               draft.isActive != orig.isActive ||
               draft.event != orig.event {
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

    // MARK: - Status

    func toggleStatus() {
        let newStatus: MemoryStatus = status == .active ? .completed : .active
        status = newStatus

        // Cascade status to checklist items (non-recurring only)
        let isRecurring = scheduleConfigDraft?.recurrenceRule != nil
        if !isRecurring && !checkItems.isEmpty {
            let now = Date()
            for i in checkItems.indices {
                switch newStatus {
                case .completed:
                    checkItems[i].isCompleted = true
                    checkItems[i].completedAt = checkItems[i].completedAt ?? now
                case .active:
                    checkItems[i].isCompleted = false
                    checkItems[i].completedAt = nil
                }
            }
        }
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

        // Sync memory status based on checklist state (non-recurring only)
        let isRecurring = scheduleConfigDraft?.recurrenceRule != nil
        if !isRecurring {
            let allCompleted = checkItems.allSatisfy(\.isCompleted)
            if allCompleted && !checkItems.isEmpty && status == .active {
                status = .completed
            } else if !allCompleted && status == .completed {
                status = .active
            }
        }
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
        isAllDay: Bool = false,
        endType: RecurrenceEndType = .never
    ) {
        setScheduleConfig(
            fireDate: fireDate,
            recurrence: recurrence,
            weekdaySelection: weekdaySelection,
            referenceTime: weekdayReferenceTime,
            isAllDay: isAllDay,
            endType: endType
        )
    }


    func clearScheduleTriggers() {
        scheduleConfigDraft = nil
    }

    /// Sets or updates the schedule configuration
    func setScheduleConfig(
        fireDate: Date?,
        recurrence: RecurrenceRule?,
        weekdaySelection: Set<Int>,
        referenceTime: Date,
        isAllDay: Bool = false,
        endType: RecurrenceEndType = .never
    ) {
        let mask = weekdaySelection.reduce(into: Int16(0)) { partialResult, day in
            partialResult |= Int16(1 << day)
        }

        guard let fireDate = fireDate else {
            scheduleConfigDraft = nil
            return
        }

        let existing = scheduleConfigDraft
        scheduleConfigDraft = ScheduleConfigDraft(
            id: existing?.id ?? UUID(),
            fireDate: fireDate,
            startDate: fireDate,
            recurrenceRule: recurrence,
            timeZoneIdentifier: TimeZone.current.identifier,
            weekdayMask: mask,
            isActive: true,
            isAllDay: isAllDay,
            recurrenceEndType: endType,
            focusEnabled: existing?.focusEnabled ?? false,
            focusWorkDurationMinutes: existing?.focusWorkDurationMinutes ?? 0,
            focusShortBreakDurationMinutes: existing?.focusShortBreakDurationMinutes ?? 0,
            focusLongBreakDurationMinutes: existing?.focusLongBreakDurationMinutes ?? 0,
            focusPomodorosUntilLongBreak: existing?.focusPomodorosUntilLongBreak ?? 0,
            focusAutoContinue: existing?.focusAutoContinue ?? true
        )
    }

    /// Removes the schedule config
    func removeScheduleConfig() {
        scheduleConfigDraft = nil
    }

    /// Sets or updates the location trigger configuration
    func setLocationConfig(name: String, latitude: Double, longitude: Double, radius: Double, event: LocationEvent) {
        let existing = locationConfigDraft
        locationConfigDraft = LocationConfigDraft(
            id: existing?.id ?? UUID(),
            latitude: latitude,
            longitude: longitude,
            radius: radius,
            name: name,
            event: event,
            isActive: true
        )
    }

    /// Removes the location trigger
    func removeLocationConfig() {
        locationConfigDraft = nil
    }

    func setFocusEnabled(_ enabled: Bool) {
        guard var schedule = scheduleConfigDraft else { return }
        schedule.focusEnabled = enabled
        if enabled && !schedule.hasConcreteFocusRecipe {
            schedule.applyFocusRecipe(FocusRecipe.from(settings: environment.focusSettings))
        }
        scheduleConfigDraft = schedule
    }

    func setFocusWorkDurationMinutes(_ minutes: Int) {
        updateFocusRecipe { recipe in
            FocusRecipe(
                workDurationMinutes: minutes,
                shortBreakDurationMinutes: recipe.shortBreakDurationMinutes,
                longBreakDurationMinutes: recipe.longBreakDurationMinutes,
                pomodorosUntilLongBreak: recipe.pomodorosUntilLongBreak,
                autoContinue: recipe.autoContinue
            )
        }
    }

    func setFocusShortBreakDurationMinutes(_ minutes: Int) {
        updateFocusRecipe { recipe in
            FocusRecipe(
                workDurationMinutes: recipe.workDurationMinutes,
                shortBreakDurationMinutes: minutes,
                longBreakDurationMinutes: recipe.longBreakDurationMinutes,
                pomodorosUntilLongBreak: recipe.pomodorosUntilLongBreak,
                autoContinue: recipe.autoContinue
            )
        }
    }

    func setFocusLongBreakDurationMinutes(_ minutes: Int) {
        updateFocusRecipe { recipe in
            FocusRecipe(
                workDurationMinutes: recipe.workDurationMinutes,
                shortBreakDurationMinutes: recipe.shortBreakDurationMinutes,
                longBreakDurationMinutes: minutes,
                pomodorosUntilLongBreak: recipe.pomodorosUntilLongBreak,
                autoContinue: recipe.autoContinue
            )
        }
    }

    func setFocusPomodorosUntilLongBreak(_ count: Int) {
        updateFocusRecipe { recipe in
            FocusRecipe(
                workDurationMinutes: recipe.workDurationMinutes,
                shortBreakDurationMinutes: recipe.shortBreakDurationMinutes,
                longBreakDurationMinutes: recipe.longBreakDurationMinutes,
                pomodorosUntilLongBreak: count,
                autoContinue: recipe.autoContinue
            )
        }
    }

    func setFocusAutoContinue(_ enabled: Bool) {
        updateFocusRecipe { recipe in
            FocusRecipe(
                workDurationMinutes: recipe.workDurationMinutes,
                shortBreakDurationMinutes: recipe.shortBreakDurationMinutes,
                longBreakDurationMinutes: recipe.longBreakDurationMinutes,
                pomodorosUntilLongBreak: recipe.pomodorosUntilLongBreak,
                autoContinue: enabled
            )
        }
    }

    private func updateFocusRecipe(_ update: (FocusRecipe) -> FocusRecipe) {
        guard var schedule = scheduleConfigDraft,
              schedule.focusEnabled,
              let recipe = FocusRecipe.resolve(draft: schedule) else {
            return
        }
        schedule.applyFocusRecipe(update(recipe))
        scheduleConfigDraft = schedule
    }

    /// Returns true when the iOS geofence limit is reached and this memory doesn't already have a slot.
    /// Always false on platforms without location execution (Mac v1).
    func isGeofenceLimitReached() -> Bool {
        guard PlatformCapabilities.current.supportsLocationExecution else {
            return false
        }
        #if os(iOS)
        let executor = environment.triggerExecutorCoordinator.location
        if let memoryID = editingMemoryID, executor.isMonitoringMemory(memoryID) {
            return false
        }
        return executor.activeGeofenceCount >= LocationTriggerExecutor.maxGeofences
        #else
        return false
        #endif
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
            mindID: selectedMindID,
            scheduleConfig: scheduleConfigDraft,
            locationConfig: locationConfigDraft,
            note: trimmedNote.isEmpty ? nil : trimmedNote,
            checkItems: checkItems,
            photoAttachmentIDs: photoAttachments.map(\.id),
            linkAttachmentIDs: linkAttachments.map(\.id),
            audioAttachmentIDs: audioAttachments.map(\.id),
            fileAttachmentIDs: fileAttachments.map(\.id),
            attachments: allAttachments,
            autoCompleteOnChecklistCompletion: existingMemory?.autoCompleteOnChecklistCompletion ?? false,
            completedAt: existingMemory?.completedAt,
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
            mindID: selectedMindID,
            scheduleConfig: scheduleConfigDraft,
            locationConfig: locationConfigDraft,
            note: trimmedNote.isEmpty ? nil : trimmedNote,
            checkItems: checkItems,
            photoAttachmentIDs: photoAttachments.map(\.id),
            linkAttachmentIDs: linkAttachments.map(\.id),
            audioAttachmentIDs: audioAttachments.map(\.id),
            fileAttachmentIDs: fileAttachments.map(\.id),
            attachments: allAttachments,
            autoCompleteOnChecklistCompletion: existingMemory.autoCompleteOnChecklistCompletion,
            completedAt: existingMemory.completedAt,
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
            if defaultMind?.isAllMinds == true || defaultMind?.isLimbo == true {
                selectedMindID = nil
            } else {
                selectedMindID = defaultMind?.id
            }
            applyTemplate(template)
        }
    }

    func apply(memory: Memory) {
        persistedMemoryID = memory.id
        title = memory.title
        selectedMindID = memory.mind?.id
        status = memory.status
        isPinned = memory.isPinned
        scheduleConfigDraft = memory.scheduleConfig.map { ScheduleConfigDraft.from($0) }
        locationConfigDraft = memory.locationConfig.map { LocationConfigDraft.from($0) }
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
            break
        case .quickReminder:
            let fireDate = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date()) ?? Date().addingTimeInterval(3600)
            scheduleConfigDraft = ScheduleConfigDraft(
                fireDate: fireDate,
                startDate: fireDate,
                timeZoneIdentifier: TimeZone.current.identifier,
                isActive: true
            )
        }
    }

}
