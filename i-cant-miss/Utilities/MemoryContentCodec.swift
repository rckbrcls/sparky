//
//  MemoryContentCodec.swift
//  i-cant-miss
//
//  Created by Codex on 12/11/25.
//

import Foundation

enum MemoryContentCodec {
    struct DecodeResult {
        var contents: [MemoryContent]
        var remainingAttachments: [MemoryModel.Attachment]
    }

    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    static func attachment(from contents: [MemoryContent]) throws -> MemoryModel.Attachment? {
        guard !contents.isEmpty else { return nil }
        let bundle = MemoryContentBundle(contents: contents)
        let data = try encoder.encode(bundle)
        return MemoryModel.Attachment(
            id: UUID(),
            kind: .contentBundle,
            data: data,
            createdAt: Date()
        )
    }

    static func extractContents(from attachments: [MemoryModel.Attachment]) -> DecodeResult {
        guard let index = attachments.firstIndex(where: { $0.kind == .contentBundle }) else {
            return DecodeResult(contents: [], remainingAttachments: attachments)
        }

        let bundleAttachment = attachments[index]
        let remaining = attachments.enumerated()
            .filter { $0.offset != index }
            .map(\.element)

        guard let contents = try? decoder.decode(MemoryContentBundle.self, from: bundleAttachment.data).contents else {
            return DecodeResult(contents: [], remainingAttachments: remaining)
        }

        return DecodeResult(contents: contents, remainingAttachments: remaining)
    }
}
