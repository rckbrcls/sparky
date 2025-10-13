//
//  NotesViewModel.swift
//  i-cant-miss
//
//  Created by Codex on 13/10/25.
//

import Foundation
import Combine

@MainActor
final class NotesViewModel: ObservableObject {
    @Published private(set) var allNotes: [NoteModel] = []
    @Published private(set) var folders: [FolderModel] = []
    @Published private(set) var tags: [TagModel] = []

    private let environment: AppEnvironment
    private var cancellables = Set<AnyCancellable>()

    init(environment: AppEnvironment) {
        self.environment = environment

        // Don't initialize data here - let bind() handle it
        bind()

        // Force initial update after binding is set up
        updateNotesSnapshot()
    }

    func refresh(force: Bool) {
        // Avoid duplicate refreshes if already loading
        guard !environment.isBootstrapping else { return }

        Task {
            async let notesRefresh = environment.noteService.refresh(force: force)
            async let foldersRefresh = environment.folderService.refreshFolders(force: force)
            async let tagsRefresh = environment.folderService.refreshTags(force: force)
            _ = await (notesRefresh, foldersRefresh, tagsRefresh)
        }
    }

    func notes(in folder: FolderModel) -> [NoteModel] {
        allNotes.filter { $0.folder?.id == folder.id }
    }

    func delete(note: NoteModel) {
        Task {
            _ = try? await environment.noteService.deleteNote(id: note.id)
            // Force immediate refresh to update UI
            _ = await environment.noteService.refresh(force: true)
        }
    }

    func togglePin(note: NoteModel) {
        Task {
            _ = try? await environment.noteService.togglePin(noteID: note.id)
            // Force immediate refresh to update UI
            _ = await environment.noteService.refresh(force: true)
        }
    }

    func createFolder(name: String, colorHex: String, iconName: String) {
        Task {
            _ = try? await environment.folderService.createFolder(
                name: name,
                colorHex: colorHex,
                iconName: iconName,
                isDefault: false
            )
            // Force immediate refresh to update UI
            _ = await environment.folderService.refreshFolders(force: true)
        }
    }

    func deleteFolder(_ folder: FolderModel) {
        Task {
            _ = try? await environment.folderService.deleteFolder(id: folder.id)
            // Force immediate refresh to update UI
            async let folders = environment.folderService.refreshFolders(force: true)
            async let notes = environment.noteService.refresh(force: true)
            _ = await (folders, notes)
        }
    }

    private func bind() {
        environment.noteService.$notes
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateNotesSnapshot()
            }
            .store(in: &cancellables)

        environment.folderService.$folders
            .receive(on: RunLoop.main)
            .sink { [weak self] folders in
                self?.folders = folders
            }
            .store(in: &cancellables)

        environment.folderService.$tags
            .receive(on: RunLoop.main)
            .sink { [weak self] tags in
                self?.tags = tags
            }
            .store(in: &cancellables)

        // Initialize data from services immediately
        self.folders = environment.folderService.folders
        self.tags = environment.folderService.tags
    }

    private func updateNotesSnapshot() {
        allNotes = environment.noteService.notes
    }
}
