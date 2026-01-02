//
//  MemoryContentBundle.swift
//  i-cant-miss
//

import Foundation

/// Namespace for Memory-related domain types
struct MemoryDomain {
    /// New content bundle with fixed fields (used for persistence)
    struct MemoryContentBundle: Codable {
        var note: String?
        var checkItems: [CheckItemModel]?
        var photoAttachmentIDs: [UUID]?
        var linkAttachmentIDs: [UUID]?
        var audioAttachmentIDs: [UUID]?
        var fileAttachmentIDs: [UUID]?
        /// Dates on which this memory was marked as completed (for recurring memories)
        var completedDates: [Date]?
        // Legacy field for backwards compatibility during migration
        var contents: [MemoryContent]?

        init(note: String? = nil,
             checkItems: [CheckItemModel]? = nil,
             photoAttachmentIDs: [UUID]? = nil,
             linkAttachmentIDs: [UUID]? = nil,
             audioAttachmentIDs: [UUID]? = nil,
             fileAttachmentIDs: [UUID]? = nil,
             completedDates: [Date]? = nil) {
            self.note = note
            self.checkItems = checkItems
            self.photoAttachmentIDs = photoAttachmentIDs
            self.linkAttachmentIDs = linkAttachmentIDs
            self.audioAttachmentIDs = audioAttachmentIDs
            self.fileAttachmentIDs = fileAttachmentIDs
            self.completedDates = completedDates
            self.contents = nil
        }
    }
}
