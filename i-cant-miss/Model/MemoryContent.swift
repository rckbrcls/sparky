//
//  MemoryContent.swift
//  i-cant-miss
//
//  Created by Codex on 12/11/25.
//

import Foundation

struct MemoryContentBundle: Codable, Hashable, Sendable {
    var contents: [MemoryContent]
}

enum MemoryContent: Identifiable, Hashable, Sendable {
    case richText(RichTextContent)
    case checklist(ChecklistContent)
    case photos(PhotosContent)
    case links(LinksContent)

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
}

extension MemoryContent {
    struct RichTextContent: Identifiable, Hashable, Codable, Sendable {
        var id: UUID
        var text: String
    }

    struct ChecklistContent: Identifiable, Hashable, Codable, Sendable {
        struct Item: Identifiable, Hashable, Codable, Sendable {
            var id: UUID
            var title: String
            var detail: String
            var isCompleted: Bool
            var sortOrder: Int
            var createdAt: Date
            var updatedAt: Date
            var completedAt: Date?
        }

        var id: UUID
        var items: [Item]
    }

    struct PhotosContent: Identifiable, Hashable, Codable, Sendable {
        var id: UUID
        var attachmentIDs: [UUID]
    }

    struct LinksContent: Identifiable, Hashable, Codable, Sendable {
        var id: UUID
        var attachmentIDs: [UUID]
    }
}

extension MemoryContent: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case payload
    }

    private enum ContentType: String, Codable {
        case richText
        case checklist
        case photos
        case links
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ContentType.self, forKey: .type)

        switch type {
        case .richText:
            let payload = try container.decode(RichTextContent.self, forKey: .payload)
            self = .richText(payload)
        case .checklist:
            let payload = try container.decode(ChecklistContent.self, forKey: .payload)
            self = .checklist(payload)
        case .photos:
            let payload = try container.decode(PhotosContent.self, forKey: .payload)
            self = .photos(payload)
        case .links:
            let payload = try container.decode(LinksContent.self, forKey: .payload)
            self = .links(payload)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let type: ContentType

        switch self {
        case .richText(let content):
            type = .richText
            try container.encode(content, forKey: .payload)
        case .checklist(let content):
            type = .checklist
            try container.encode(content, forKey: .payload)
        case .photos(let content):
            type = .photos
            try container.encode(content, forKey: .payload)
        case .links(let content):
            type = .links
            try container.encode(content, forKey: .payload)
        }

        try container.encode(type, forKey: .type)
    }
}

extension MemoryContent {
    static func legacyContents(body: String?,
                               checkItems: [CheckItemModel],
                               photoAttachments: [MemoryModel.Attachment],
                               linkAttachments: [MemoryModel.Attachment]) -> [MemoryContent] {
        var contents: [MemoryContent] = []

        if let rawBody = body?.trimmingCharacters(in: .whitespacesAndNewlines), !rawBody.isEmpty {
            contents.append(.richText(RichTextContent(id: UUID(), text: rawBody)))
        }

        if !checkItems.isEmpty {
            let sortedItems = checkItems.sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder {
                    return lhs.sortOrder < rhs.sortOrder
                }
                return lhs.createdAt < rhs.createdAt
            }
            let items = sortedItems.enumerated().map { index, item in
                ChecklistContent.Item(
                    id: item.id,
                    title: item.title,
                    detail: item.detail ?? "",
                    isCompleted: item.isCompleted,
                    sortOrder: index,
                    createdAt: item.createdAt,
                    updatedAt: item.updatedAt,
                    completedAt: item.completedAt
                )
            }
            contents.append(.checklist(ChecklistContent(id: UUID(), items: items)))
        }

        if !photoAttachments.isEmpty {
            let identifiers = photoAttachments.map(\.id)
            contents.append(.photos(PhotosContent(id: UUID(), attachmentIDs: identifiers)))
        }

        if !linkAttachments.isEmpty {
            let identifiers = linkAttachments.map(\.id)
            contents.append(.links(LinksContent(id: UUID(), attachmentIDs: identifiers)))
        }

        return contents
    }
}

extension Array where Element == MemoryContent {
    func aggregatedBodyText() -> String? {
        let texts = self.compactMap { content -> String? in
            guard case .richText(let payload) = content else { return nil }
            let trimmed = payload.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        guard !texts.isEmpty else { return nil }
        return texts.joined(separator: "\n\n")
    }

    func flattenedChecklistItems() -> [CheckItemModel] {
        var aggregated: [CheckItemModel] = []
        for content in self {
            guard case .checklist(let payload) = content else { continue }
            let sorted = payload.items.sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder {
                    return lhs.sortOrder < rhs.sortOrder
                }
                return lhs.createdAt < rhs.createdAt
            }

            for item in sorted {
                let normalized = CheckItemModel(
                    id: item.id,
                    title: item.title,
                    detail: item.detail.isEmpty ? nil : item.detail,
                    isCompleted: item.isCompleted,
                    sortOrder: aggregated.count,
                    createdAt: item.createdAt,
                    updatedAt: item.updatedAt,
                    completedAt: item.completedAt
                )
                aggregated.append(normalized)
            }
        }
        return aggregated
    }

    func referencedAttachmentIDs() -> [UUID] {
        var identifiers: [UUID] = []
        for content in self {
            switch content {
            case .photos(let payload):
                identifiers.append(contentsOf: payload.attachmentIDs)
            case .links(let payload):
                identifiers.append(contentsOf: payload.attachmentIDs)
            default:
                continue
            }
        }
        return identifiers
    }
}
