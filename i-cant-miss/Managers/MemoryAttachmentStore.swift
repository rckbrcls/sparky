//
//  MemoryAttachmentStore.swift
//  i-cant-miss
//
//  Created by Codex on 28/11/25.
//

import Foundation

actor MemoryAttachmentStore {
    private let fileManager: FileManager
    private let rootDirectory: URL
    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()

    private struct LinkAttachmentPayload: Codable {
        let url: URL
    }

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        guard let supportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Unable to locate application support directory for attachments.")
        }

        self.rootDirectory = supportDirectory.appendingPathComponent("MemoryAttachments", isDirectory: true)
        try? Self.ensureDirectoryExists(fileManager: fileManager, at: rootDirectory)
    }

    func attachments(for memoryID: UUID) async -> [MemoryModel.Attachment] {
        let directory = directoryURL(for: memoryID)
        guard fileManager.fileExists(atPath: directory.path) else { return [] }

        let resourceKeys: Set<URLResourceKey> = [.creationDateKey]

        guard let contents = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        struct AttachmentResource: Sendable {
            let id: UUID
            let kind: MemoryModel.AttachmentKind
            let data: Data
            let url: URL?
            let createdAt: Date
        }

        let resources: [AttachmentResource] = contents.compactMap { url in
            let fileExtension = url.pathExtension.lowercased()
            let metadata = try? url.resourceValues(forKeys: resourceKeys)
            let createdAt = metadata?.creationDate ?? Date()
            let identifier = UUID(uuidString: url.deletingPathExtension().lastPathComponent) ?? UUID()

            switch fileExtension {
            case "jpg", "jpeg":
                guard let data = try? Data(contentsOf: url) else { return nil }
                return AttachmentResource(
                    id: identifier,
                    kind: .photo,
                    data: data,
                    url: nil,
                    createdAt: createdAt
                )
            case "json":
                guard let data = try? Data(contentsOf: url),
                      let payload = try? jsonDecoder.decode(LinkAttachmentPayload.self, from: data) else {
                    return nil
                }
                return AttachmentResource(
                    id: identifier,
                    kind: .link,
                    data: Data(),
                    url: payload.url,
                    createdAt: createdAt
                )
            default:
                return nil
            }
        }

        guard !resources.isEmpty else { return [] }

        let sortedResources = resources.sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }

        return await MainActor.run {
            sortedResources.map { resource in
                MemoryModel.Attachment(
                    id: resource.id,
                    kind: resource.kind,
                    data: resource.data,
                    createdAt: resource.createdAt,
                    url: resource.url
                )
            }
        }
    }

    func replaceAttachments(for memoryID: UUID,
                             with attachments: [MemoryModel.Attachment]) throws {
        let directory = directoryURL(for: memoryID)

        if fileManager.fileExists(atPath: directory.path) {
            try fileManager.removeItem(at: directory)
        }

        guard !attachments.isEmpty else { return }

        try Self.ensureDirectoryExists(fileManager: fileManager, at: directory)

        for attachment in attachments {
            if attachment.kind == .photo {
                let filename = "\(attachment.id.uuidString).jpg"
                let url = directory.appendingPathComponent(filename, isDirectory: false)
                try attachment.data.write(to: url, options: .atomic)
            } else if attachment.kind == .link {
                guard let linkURL = attachment.url else { continue }
                let filename = "\(attachment.id.uuidString).json"
                let url = directory.appendingPathComponent(filename, isDirectory: false)
                let payload = LinkAttachmentPayload(url: linkURL)
                let data = try jsonEncoder.encode(payload)
                try data.write(to: url, options: .atomic)
            } else {
                continue
            }
        }
    }

    func deleteAllAttachments(for memoryID: UUID) throws {
        let directory = directoryURL(for: memoryID)
        guard fileManager.fileExists(atPath: directory.path) else { return }
        try fileManager.removeItem(at: directory)
    }

    // MARK: - Helpers

    private func directoryURL(for memoryID: UUID) -> URL {
        rootDirectory.appendingPathComponent(memoryID.uuidString, isDirectory: true)
    }

    private static func ensureDirectoryExists(fileManager: FileManager, at url: URL) throws {
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
}
