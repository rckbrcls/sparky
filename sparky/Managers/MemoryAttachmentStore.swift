//
//  MemoryAttachmentStore.swift
//  sparky
//
//  Created by Codex on 28/11/25.
//

import Foundation

actor MemoryAttachmentStore {
    private let fileManager: FileManager
    private let rootDirectory: URL
    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()
    private let photoKindRawValue = "photo"
    private let linkKindRawValue = "link"
    private let audioKindRawValue = "audio"
    private let fileKindRawValue = "file"
    private let audioExtensions: Set<String> = ["m4a", "mp3", "wav", "aac", "aiff", "aif", "caf"]

    private struct AttachmentResource: Sendable {
        let id: UUID
        let kindRawValue: String
        let data: Data
        let url: URL?
        let createdAt: Date
        let filename: String?
    }

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

    func attachments(for memoryID: UUID) async -> [Memory.Attachment] {
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

        let resources: [AttachmentResource] = contents.compactMap { url in
            let fileExtension = url.pathExtension.lowercased()
            let metadata = try? url.resourceValues(forKeys: resourceKeys)
            let createdAt = metadata?.creationDate ?? Date()
            let identifier = UUID(uuidString: url.deletingPathExtension().lastPathComponent) ?? UUID()
            let filename = url.lastPathComponent

            if let fileResource = parseFileAttachment(url: url, createdAt: createdAt) {
                return fileResource
            }

            switch fileExtension {
            case "jpg", "jpeg":
                guard let data = try? Data(contentsOf: url) else { return nil }
                return AttachmentResource(
                    id: identifier,
                    kindRawValue: photoKindRawValue,
                    data: data,
                    url: nil,
                    createdAt: createdAt,
                    filename: nil
                )
            case "json":
                guard let data = try? Data(contentsOf: url),
                      let payload = try? jsonDecoder.decode(LinkAttachmentPayload.self, from: data) else {
                    return nil
                }
                return AttachmentResource(
                    id: identifier,
                    kindRawValue: linkKindRawValue,
                    data: Data(),
                    url: payload.url,
                    createdAt: createdAt,
                    filename: nil
                )
            case _ where audioExtensions.contains(fileExtension):
                guard let data = try? Data(contentsOf: url) else { return nil }
                return AttachmentResource(
                    id: identifier,
                    kindRawValue: audioKindRawValue,
                    data: data,
                    url: url,
                    createdAt: createdAt,
                    filename: filename
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
                Memory.Attachment(
                    id: resource.id,
                    kind: Memory.AttachmentKind(rawValue: resource.kindRawValue),
                    data: resource.data,
                    createdAt: resource.createdAt,
                    url: resource.url,
                    filename: resource.filename
                )
            }
        }
    }

    func replaceAttachments(for memoryID: UUID,
                             with attachments: [Memory.Attachment]) throws {
        let directory = directoryURL(for: memoryID)

        if fileManager.fileExists(atPath: directory.path) {
            try fileManager.removeItem(at: directory)
        }

        guard !attachments.isEmpty else { return }

        try Self.ensureDirectoryExists(fileManager: fileManager, at: directory)
        for attachment in attachments {
            let kindRawValue = attachment.kind.rawValue
            if kindRawValue == photoKindRawValue {
                let filename = "\(attachment.id.uuidString).jpg"
                let url = directory.appendingPathComponent(filename, isDirectory: false)
                try attachment.data.write(to: url, options: .atomic)
            } else if kindRawValue == linkKindRawValue {
                guard let linkURL = attachment.url else { continue }
                let filename = "\(attachment.id.uuidString).json"
                let url = directory.appendingPathComponent(filename, isDirectory: false)
                let payload = LinkAttachmentPayload(url: linkURL)
                let data = try jsonEncoder.encode(payload)
                try data.write(to: url, options: .atomic)
            } else if kindRawValue == audioKindRawValue {
                guard !attachment.data.isEmpty else { continue }
                let preferredExtension = attachment.url?.pathExtension.isEmpty == false
                    ? attachment.url!.pathExtension.lowercased()
                    : "m4a"
                let filename = "\(attachment.id.uuidString).\(preferredExtension)"
                let url = directory.appendingPathComponent(filename, isDirectory: false)
                try attachment.data.write(to: url, options: .atomic)
            } else if kindRawValue == fileKindRawValue {
                guard !attachment.data.isEmpty else { continue }
                let preferredName = sanitizedFilename(
                    attachment.filename ?? attachment.url?.lastPathComponent ?? "file"
                )
                let finalName = preferredName.contains(".") ? preferredName : "\(preferredName).bin"
                let filename = "\(attachment.id.uuidString)_file_\(finalName)"
                let url = directory.appendingPathComponent(filename, isDirectory: false)
                try attachment.data.write(to: url, options: .atomic)
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

    private func sanitizedFilename(_ filename: String) -> String {
        let trimmed = filename.trimmingCharacters(in: .whitespacesAndNewlines)
        let clean = trimmed.replacingOccurrences(of: "/", with: "-")
        return clean.isEmpty ? "file" : clean
    }

    private func parseFileAttachment(url: URL, createdAt: Date) -> AttachmentResource? {
        let filename = url.lastPathComponent
        guard filename.contains("_file_") else { return nil }

        let parts = filename.components(separatedBy: "_file_")
        guard let idPart = parts.first else { return nil }
        let identifier = UUID(uuidString: idPart) ?? UUID()
        let displayName = parts.dropFirst().joined(separator: "_file_")
        guard let data = try? Data(contentsOf: url) else { return nil }

        return AttachmentResource(
            id: identifier,
            kindRawValue: fileKindRawValue,
            data: data,
            url: url,
            createdAt: createdAt,
            filename: displayName.isEmpty ? nil : displayName
        )
    }
}
