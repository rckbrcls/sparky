//
//  MemoryDraft.swift
//  i-cant-miss
//

import Foundation

struct MemoryDraft: Identifiable, Hashable {
    let id: UUID
    var title: String
    var status: MemoryStatus
    var isPinned: Bool
    var dueDate: Date?
    var lobeID: UUID?
    var triggers: [MemoryTriggerModel]
    // Fixed content attributes (replacing dynamic contents array)
    var note: String?
    var checkItems: [CheckItemDraft]
    var photoAttachmentIDs: [UUID]
    var linkAttachmentIDs: [UUID]
    var audioAttachmentIDs: [UUID]
    var fileAttachmentIDs: [UUID]
    var attachments: [Memory.Attachment]
    var autoCompleteOnChecklistCompletion: Bool
    /// Dates on which this memory was marked as completed (for recurring memories)
    var completedDates: [Date]

    init(id: UUID = UUID(),
         title: String,
         status: MemoryStatus = .active,
         isPinned: Bool = false,
         dueDate: Date? = nil,
         lobeID: UUID? = nil,
         triggers: [MemoryTriggerModel] = [],
         note: String? = nil,
         checkItems: [CheckItemDraft] = [],
         photoAttachmentIDs: [UUID] = [],
         linkAttachmentIDs: [UUID] = [],
         audioAttachmentIDs: [UUID] = [],
         fileAttachmentIDs: [UUID] = [],
         attachments: [Memory.Attachment] = [],
         autoCompleteOnChecklistCompletion: Bool = false,
         completedDates: [Date] = []) {
        self.id = id
        self.title = title
        self.status = status
        self.isPinned = isPinned
        self.dueDate = dueDate
        self.lobeID = lobeID
        self.triggers = triggers
        self.note = note
        self.checkItems = checkItems
        self.photoAttachmentIDs = photoAttachmentIDs
        self.linkAttachmentIDs = linkAttachmentIDs
        self.audioAttachmentIDs = audioAttachmentIDs
        self.fileAttachmentIDs = fileAttachmentIDs
        self.attachments = attachments
        self.autoCompleteOnChecklistCompletion = autoCompleteOnChecklistCompletion
        self.completedDates = completedDates
    }

    static func == (lhs: MemoryDraft, rhs: MemoryDraft) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
