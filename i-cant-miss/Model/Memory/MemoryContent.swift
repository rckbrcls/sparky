//
//  MemoryContent.swift
//  i-cant-miss
//

import Foundation

enum MemoryContent: Codable, Hashable {
    case richText(String)
    case checklist([CheckItemModel])
    case photos([UUID])
    case links([UUID])
    case audio([UUID])
    case files([UUID])

    private enum CodingKeys: String, CodingKey {
        case type
        case text
        case items
        case attachmentIDs
    }

    private enum ContentType: String, Codable {
        case richText
        case checklist
        case photos
        case links
        case audio
        case files
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ContentType.self, forKey: .type)

        switch type {
        case .richText:
            let text = try container.decode(String.self, forKey: .text)
            self = .richText(text)
        case .checklist:
            let items = try container.decode([CheckItemModel].self, forKey: .items)
            self = .checklist(items)
        case .photos:
            let ids = try container.decode([UUID].self, forKey: .attachmentIDs)
            self = .photos(ids)
        case .links:
            let ids = try container.decode([UUID].self, forKey: .attachmentIDs)
            self = .links(ids)
        case .audio:
            let ids = try container.decode([UUID].self, forKey: .attachmentIDs)
            self = .audio(ids)
        case .files:
            let ids = try container.decode([UUID].self, forKey: .attachmentIDs)
            self = .files(ids)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .richText(let text):
            try container.encode(ContentType.richText, forKey: .type)
            try container.encode(text, forKey: .text)
        case .checklist(let items):
            try container.encode(ContentType.checklist, forKey: .type)
            try container.encode(items, forKey: .items)
        case .photos(let ids):
            try container.encode(ContentType.photos, forKey: .type)
            try container.encode(ids, forKey: .attachmentIDs)
        case .links(let ids):
            try container.encode(ContentType.links, forKey: .type)
            try container.encode(ids, forKey: .attachmentIDs)
        case .audio(let ids):
            try container.encode(ContentType.audio, forKey: .type)
            try container.encode(ids, forKey: .attachmentIDs)
        case .files(let ids):
            try container.encode(ContentType.files, forKey: .type)
            try container.encode(ids, forKey: .attachmentIDs)
        }
    }
}

// MARK: - Array Extensions

extension Array where Element == MemoryContent {
    func aggregatedBodyText() -> String? {
        let textContents = self.compactMap { content -> String? in
            switch content {
            case .richText(let text):
                return text
            default:
                return nil
            }
        }
        let combined = textContents.joined(separator: "\n\n")
        return combined.isEmpty ? nil : combined
    }

    func referencedAttachmentIDs() -> [UUID] {
        return self.flatMap { content -> [UUID] in
            switch content {
            case .photos(let attachmentIDs):
                return attachmentIDs
            case .links(let attachmentIDs):
                return attachmentIDs
            case .audio(let attachmentIDs):
                return attachmentIDs
            case .files(let attachmentIDs):
                return attachmentIDs
            default:
                return []
            }
        }
    }

    func flattenedChecklistItems() -> [CheckItemModel] {
        return self.compactMap { content -> [CheckItemModel]? in
            if case .checklist(let items) = content {
                return items
            }
            return nil
        }.flatMap { $0 }
    }
}
