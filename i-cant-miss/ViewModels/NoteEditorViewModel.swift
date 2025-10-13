//
//  NoteEditorViewModel.swift
//  i-cant-miss
//
//  Created by Codex on 13/10/25.
//

import Foundation
import Combine

@MainActor
final class NoteEditorViewModel: ObservableObject {
    @Published var title: String
    @Published var content: String
    @Published var isPinned: Bool
    @Published var selectedFolderID: UUID?
    @Published var selectedTagIDs: Set<UUID>
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?

    let environment: AppEnvironment
    private let existingNote: NoteModel?

    init(environment: AppEnvironment, note: NoteModel?) {
        self.environment = environment
        self.existingNote = note
        self.title = note?.title ?? ""
        self.content = note?.content ?? ""
        self.isPinned = note?.isPinned ?? false
        self.selectedFolderID = note?.folder?.id
        self.selectedTagIDs = Set(note?.tags.map(\.id) ?? [])
    }

    func toggleTag(id: UUID) {
        if selectedTagIDs.contains(id) {
            selectedTagIDs.remove(id)
        } else {
            selectedTagIDs.insert(id)
        }
    }

    func save() async -> Bool {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Note content cannot be empty."
            return false
        }

        isSaving = true
        defer { isSaving = false }

        do {
            if let note = existingNote {
                var updated = note
                updated.title = title
                updated.content = content
                updated.isPinned = isPinned
                updated.folder = environment.folderService.folders.first(where: { $0.id == selectedFolderID })
                updated.tags = environment.folderService.tags.filter { selectedTagIDs.contains($0.id) }
                updated.updatedAt = Date()
                _ = try await environment.noteService.updateNote(updated)
            } else {
                let folderID = selectedFolderID
                let tagIDs = Array(selectedTagIDs)
                _ = try await environment.noteService.createNote(title: title.isEmpty ? nil : title,
                                                                 content: content,
                                                                 folderID: folderID,
                                                                 tagIDs: tagIDs,
                                                                 isPinned: isPinned)
            }

            await environment.noteService.refresh(force: true)
            return true
        } catch {
            errorMessage = "Unable to save note."
            return false
        }
    }
}
