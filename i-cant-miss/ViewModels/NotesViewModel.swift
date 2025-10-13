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
    @Published var selectedFolderID: UUID? {
        didSet { updateNotesSnapshot() }
    }
    @Published var showPinnedOnly = false {
        didSet { updateNotesSnapshot() }
    }
    @Published var searchText = "" {
        didSet { updateNotesSnapshot() }
    }
    @Published private(set) var notes: [NoteModel] = []
    @Published private(set) var folders: [FolderModel] = []
    @Published private(set) var tags: [TagModel] = []

    private let environment: AppEnvironment
    private var cancellables = Set<AnyCancellable>()

    init(environment: AppEnvironment) {
        self.environment = environment
        bind()
        updateNotesSnapshot()
    }

    func refresh(force: Bool) {
        Task {
            async let notesRefresh = environment.noteService.refresh(force: force)
            async let foldersRefresh = environment.folderService.refreshFolders(force: force)
            async let tagsRefresh = environment.folderService.refreshTags(force: force)
            _ = await (notesRefresh, foldersRefresh, tagsRefresh)
            updateNotesSnapshot()
        }
    }

    func delete(note: NoteModel) {
        Task {
            _ = try? await environment.noteService.deleteNote(id: note.id)
            await environment.noteService.refresh(force: true)
        }
    }

    func togglePin(note: NoteModel) {
        Task {
            _ = try? await environment.noteService.togglePin(noteID: note.id)
            await environment.noteService.refresh(force: true)
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
    }

    private func updateNotesSnapshot() {
        var filtered = environment.noteService.notes

        if let folderID = selectedFolderID {
            filtered = filtered.filter { $0.folder?.id == folderID }
        }

        if showPinnedOnly {
            filtered = filtered.filter(\.isPinned)
        }

        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            let query = searchText.lowercased()
            filtered = filtered.filter { note in
                note.content.lowercased().contains(query) ||
                (note.title?.lowercased().contains(query) ?? false)
            }
        }

        notes = filtered
    }
}
