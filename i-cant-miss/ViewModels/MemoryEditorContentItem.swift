import Foundation

struct MemoryEditorRichTextContent: Identifiable, Hashable {
    var id: UUID = UUID()
    var text: String = ""
}

struct MemoryEditorChecklistContent: Identifiable, Hashable {
    var id: UUID = UUID()
    var items: [CheckItemDraft] = []
}

struct MemoryEditorPhotosContent: Identifiable, Hashable {
    var id: UUID = UUID()
    var attachments: [MemoryModel.Attachment] = []
}

struct MemoryEditorLinksContent: Identifiable, Hashable {
    var id: UUID = UUID()
    var links: [MemoryModel.Attachment] = []
}

enum MemoryEditorContentItem: Identifiable, Hashable {
    case richText(MemoryEditorRichTextContent)
    case checklist(MemoryEditorChecklistContent)
    case photos(MemoryEditorPhotosContent)
    case links(MemoryEditorLinksContent)

    var id: UUID {
        switch self {
        case .richText(let content):
            return content.id
        case .checklist(let content):
            return content.id
        case .photos(let content):
            return content.id
        case .links(let content):
            return content.id
        }
    }

    var contentType: MemoryEditorContentType {
        switch self {
        case .richText:
            return .richText
        case .checklist:
            return .checklist
        case .photos:
            return .photos
        case .links:
            return .links
        }
    }

    var richTextContent: MemoryEditorRichTextContent? {
        guard case .richText(let content) = self else { return nil }
        return content
    }

    var checklistContent: MemoryEditorChecklistContent? {
        guard case .checklist(let content) = self else { return nil }
        return content
    }

    var photosContent: MemoryEditorPhotosContent? {
        guard case .photos(let content) = self else { return nil }
        return content
    }

    var linksContent: MemoryEditorLinksContent? {
        guard case .links(let content) = self else { return nil }
        return content
    }

    mutating func mutateRichText(_ mutate: (inout MemoryEditorRichTextContent) -> Void) {
        guard case .richText(var content) = self else { return }
        mutate(&content)
        self = .richText(content)
    }

    mutating func mutateChecklist(_ mutate: (inout MemoryEditorChecklistContent) -> Void) {
        guard case .checklist(var content) = self else { return }
        mutate(&content)
        self = .checklist(content)
    }

    mutating func mutatePhotos(_ mutate: (inout MemoryEditorPhotosContent) -> Void) {
        guard case .photos(var content) = self else { return }
        mutate(&content)
        self = .photos(content)
    }

    mutating func mutateLinks(_ mutate: (inout MemoryEditorLinksContent) -> Void) {
        guard case .links(var content) = self else { return }
        mutate(&content)
        self = .links(content)
    }
}
