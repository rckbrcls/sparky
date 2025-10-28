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

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        guard let supportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Unable to locate application support directory for attachments.")
        }

        self.rootDirectory = supportDirectory.appendingPathComponent("MemoryAttachments", isDirectory: true)
        try? Self.ensureDirectoryExists(fileManager: fileManager, at: rootDirectory)
    }

    func attachments(for memoryID: UUID) -> [MemoryModel.Attachment] {
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

        var attachments: [MemoryModel.Attachment] = []
        attachments.reserveCapacity(contents.count)

        for url in contents {
            guard url.pathExtension.lowercased() == "jpg" || url.pathExtension.lowercased() == "jpeg" else {
                continue
            }

            guard let data = try? Data(contentsOf: url) else { continue }
            let metadata = try? url.resourceValues(forKeys: resourceKeys)
            let createdAt = metadata?.creationDate ?? Date()
            let identifier = UUID(uuidString: url.deletingPathExtension().lastPathComponent) ?? UUID()

            attachments.append(
                MemoryModel.Attachment(
                    id: identifier,
                    kind: MemoryModel.AttachmentKind(rawValue: "photo"),
                    data: data,
                    createdAt: createdAt
                )
            )
        }

        return attachments.sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.id.uuidString < rhs.id.uuidString
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
            let filename = "\(attachment.id.uuidString).jpg"
            let url = directory.appendingPathComponent(filename, isDirectory: false)
            try attachment.data.write(to: url, options: .atomic)
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
