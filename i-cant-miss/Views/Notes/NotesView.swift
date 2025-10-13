//
//  NotesView.swift
//  i-cant-miss
//
//  Created by Codex on 13/10/25.
//

import SwiftUI

struct NotesView: View {
    @StateObject private var viewModel: NotesViewModel
    let environment: AppEnvironment
    let onCreateNote: () -> Void
    let onEditNote: (NoteModel) -> Void

    init(environment: AppEnvironment,
         onCreateNote: @escaping () -> Void,
         onEditNote: @escaping (NoteModel) -> Void) {
        self.environment = environment
        self.onCreateNote = onCreateNote
        self.onEditNote = onEditNote
        _viewModel = StateObject(wrappedValue: NotesViewModel(environment: environment))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    folderChips
                        .padding(.horizontal)

                    if viewModel.notes.isEmpty {
                        EmptyStateView(systemImage: "note.text",
                                       title: "Capture ideas fast",
                                       message: "Create a new note to see it organized here.")
                            .frame(maxWidth: .infinity)
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ForEach(viewModel.notes, id: \.id) { note in
                                NoteCardView(note: note)
                                    .onTapGesture {
                                        onEditNote(note)
                                    }
                                    .contextMenu {
                                        Button(note.isPinned ? "Unpin" : "Pin", systemImage: "pin") {
                                            viewModel.togglePin(note: note)
                                        }
                                        Button("Delete", systemImage: "trash", role: .destructive) {
                                            viewModel.delete(note: note)
                                            viewModel.refresh(force: true)
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 32)
                    }
                }
                .padding(.top)
            }
            .navigationTitle("Notes")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: onCreateNote) {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .searchable(text: $viewModel.searchText, placement: .navigationBarDrawer(displayMode: .always))
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Toggle(isOn: $viewModel.showPinnedOnly) {
                        Label("Pinned", systemImage: "pin.fill")
                    }
                }
            }
        }
        .onAppear {
            viewModel.refresh(force: false)
        }
    }

    private var folderChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                folderChip(title: "All", isSelected: viewModel.selectedFolderID == nil) {
                    viewModel.selectedFolderID = nil
                }

                for folder in viewModel.folders {
                    folderChip(title: folder.name,
                               icon: folder.iconName,
                               colorHex: folder.colorHex,
                               isSelected: viewModel.selectedFolderID == folder.id) {
                        viewModel.selectedFolderID = folder.id
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func folderChip(title: String,
                            icon: String? = nil,
                            colorHex: String? = nil,
                            isSelected: Bool,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                }
                Text(title)
            }
            .font(.caption)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(
                Capsule()
                    .fill(isSelected ? (Color(hex: colorHex ?? "#6366F1") ?? .accentColor).opacity(0.2) : Color(.systemGray6))
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let environment = AppEnvironment(persistence: PersistenceController.preview)
    environment.bootstrap()
    return NotesView(environment: environment, onCreateNote: {}, onEditNote: { _ in })
}
