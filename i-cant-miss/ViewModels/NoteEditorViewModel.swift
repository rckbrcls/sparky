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
    @Published var title: String = ""
    @Published var content: String = ""
    @Published var isPinned: Bool = false
    @Published var selectedFolderID: UUID?
    @Published var selectedTagIDs: Set<UUID> = []
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?

    let environment: AppEnvironment
    private let existingNoteID: UUID?

    init(environment: AppEnvironment, note: NoteModel?) {
        self.environment = environment
        self.existingNoteID = note?.id

        // Load data immediately in init to ensure it's available when view appears
        // First try to fetch fresh data from Core Data with relationships
        if let noteId = note?.id,
           let freshNote = environment.noteService.fetchNoteWithRelationships(id: noteId) {
            self.title = freshNote.title ?? ""
            self.content = freshNote.content
            self.isPinned = freshNote.isPinned
            self.selectedFolderID = freshNote.folder?.id
            self.selectedTagIDs = Set(freshNote.tags.map(\.id))
        } else if let noteId = note?.id,
                  let existingNote = environment.noteService.notes.first(where: { $0.id == noteId }) {
            self.title = existingNote.title ?? ""
            self.content = existingNote.content
            self.isPinned = existingNote.isPinned
            self.selectedFolderID = existingNote.folder?.id
            self.selectedTagIDs = Set(existingNote.tags.map(\.id))
        } else {
            // New note - use defaults
            self.title = note?.title ?? ""
            self.content = note?.content ?? ""
            self.isPinned = note?.isPinned ?? false
            self.selectedFolderID = note?.folder?.id
            self.selectedTagIDs = Set(note?.tags.map(\.id) ?? [])
        }
    }
    func loadData() {
        // Reload data from the existing note to ensure all relationships are populated
        if let noteId = existingNoteID,
           let updatedNote = environment.noteService.notes.first(where: { $0.id == noteId }) {
            self.title = updatedNote.title ?? ""
            self.content = updatedNote.content
            self.isPinned = updatedNote.isPinned
            self.selectedFolderID = updatedNote.folder?.id
            self.selectedTagIDs = Set(updatedNote.tags.map(\.id))
        }
    }

    var existingNote: NoteModel? {
        guard let noteId = existingNoteID else { return nil }
        return environment.noteService.notes.first(where: { $0.id == noteId })
    }

    var isNewNote: Bool {
        existingNoteID == nil
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
