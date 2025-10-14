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
    private static let defaultFolderColorHex = "#6366F1"
    private static let defaultFolderIconName = "folder.fill"

    @State private var showingCreateFolder = false
    @State private var newFolderName = ""
    @State private var newFolderIcon = Self.defaultFolderIconName
    @State private var newFolderColor = Self.defaultFolderColorHex
    @State private var editingFolder: FolderModel?
    @State private var editFolderName = ""
    @State private var editFolderIcon = Self.defaultFolderIconName
    @State private var editFolderColor = Self.defaultFolderColorHex
    private let accentColor = Color("AccentColor")
    private let gridColumns = Array(repeating: GridItem(.flexible()), count: 4)

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
            List {
                // All Notes folder
                NavigationLink(destination: FolderNotesView(
                    folderName: "All Notes",
                    notes: viewModel.allNotes,
                    onCreateNote: onCreateNote,
                    onEditNote: onEditNote,
                    onDeleteNote: { note in
                        viewModel.delete(note: note)
                    },
                    onTogglePin: { note in
                        viewModel.togglePin(note: note)
                    }
                )) {
                    HStack(spacing: 12) {
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.title2)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("All Notes")
                                .font(.headline)
                            Text("\(viewModel.allNotes.count) note\(viewModel.allNotes.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "folder.fill")
                            .foregroundStyle(.secondary)
                            .font(.title3)
                    }
                    .padding(.vertical, 4)
                }

                // Folder sections
                ForEach(viewModel.folders) { folder in
                    NavigationLink(destination: FolderNotesView(
                        folderName: folder.name,
                        notes: viewModel.notes(in: folder),
                        onCreateNote: onCreateNote,
                        onEditNote: onEditNote,
                        onDeleteNote: { note in
                            viewModel.delete(note: note)
                        },
                        onTogglePin: { note in
                            viewModel.togglePin(note: note)
                        }
                    )) {
                        HStack(spacing: 12) {
                            Image(systemName: folder.iconName ?? Self.defaultFolderIconName)
                                .font(.title2)
                                .foregroundStyle(Color(hex: folder.colorHex ?? Self.defaultFolderColorHex) ?? .blue)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(folder.name)
                                    .font(.headline)
                                Text("\(viewModel.notes(in: folder).count) note\(viewModel.notes(in: folder).count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "folder.fill")
                                .foregroundStyle(.secondary)
                                .font(.title3)
                        }
                        .padding(.vertical, 4)
                    }
                    .contextMenu {
                        Button {
                            prepareFolderEditing(with: folder)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            viewModel.deleteFolder(folder)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button {
                            prepareFolderEditing(with: folder)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(accentColor)
                        
                        Button(role: .destructive) {
                            viewModel.deleteFolder(folder)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Notes")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: onCreateNote) {
                            Label("New Note", systemImage: "square.and.pencil")
                        }
                        .tint(accentColor)
                        Button(action: { showingCreateFolder = true }) {
                            Label("New Folder", systemImage: "folder.badge.plus")
                        }
                        .tint(accentColor)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .tint(accentColor)
                    .accessibilityLabel("Create Note or Folder")
                }
            }
            .sheet(isPresented: $showingCreateFolder) {
                createFolderSheet
            }
            .sheet(item: $editingFolder) { folder in
                editFolderSheet(for: folder)
            }
        }
        .onAppear {
            viewModel.refresh(force: false)
        }
    }

    private var createFolderSheet: some View {
        NavigationStack {
            Form {
                Section("Folder Details") {
                    TextField("Folder Name", text: $newFolderName)
                }

                Section("Icon") {
                    iconSelectionGrid(selection: $newFolderIcon)
                }

                Section("Color") {
                    LazyVGrid(columns: gridColumns, spacing: 12) {
                        ForEach(Color.PresetColors.all) { presetColor in
                            Button(action: {
                                newFolderColor = presetColor.hex
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(presetColor.color)
                                        .frame(width: 50, height: 50)

                                    if newFolderColor == presetColor.hex {
                                        Circle()
                                            .strokeBorder(.white, lineWidth: 3)
                                            .frame(width: 50, height: 50)
                                            .shadow(radius: 2)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("New Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingCreateFolder = false
                        resetFolderForm()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        viewModel.createFolder(
                            name: newFolderName,
                            colorHex: newFolderColor,
                            iconName: newFolderIcon
                        )
                        showingCreateFolder = false
                        resetFolderForm()
                    }
                    .disabled(newFolderName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func editFolderSheet(for folder: FolderModel) -> some View {
        NavigationStack {
            Form {
                Section("Folder Details") {
                    TextField("Folder Name", text: $editFolderName)
                }

                Section("Icon") {
                    iconSelectionGrid(selection: $editFolderIcon)
                }

                Section("Color") {
                    LazyVGrid(columns: gridColumns, spacing: 12) {
                        ForEach(Color.PresetColors.all) { presetColor in
                            Button(action: {
                                editFolderColor = presetColor.hex
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(presetColor.color)
                                        .frame(width: 50, height: 50)

                                    if editFolderColor == presetColor.hex {
                                        Circle()
                                            .strokeBorder(.white, lineWidth: 3)
                                            .frame(width: 50, height: 50)
                                            .shadow(radius: 2)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Edit Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        resetEditFolderForm()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.updateFolder(
                            folder,
                            name: editFolderName,
                            colorHex: editFolderColor,
                            iconName: editFolderIcon
                        )
                        resetEditFolderForm()
                    }
                    .disabled(editFolderName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func resetFolderForm() {
        newFolderName = ""
        newFolderIcon = Self.defaultFolderIconName
        newFolderColor = Self.defaultFolderColorHex
    }

    private func prepareFolderEditing(with folder: FolderModel) {
        editFolderName = folder.name
        let icon = folder.iconName ?? Self.defaultFolderIconName
        editFolderIcon = folderIcons.contains(icon) ? icon : Self.defaultFolderIconName
        editFolderColor = folder.colorHex ?? Self.defaultFolderColorHex
        editingFolder = folder
    }

    private func resetEditFolderForm() {
        editingFolder = nil
        editFolderName = ""
        editFolderIcon = Self.defaultFolderIconName
        editFolderColor = Self.defaultFolderColorHex
    }

    @ViewBuilder
    private func iconSelectionGrid(selection: Binding<String>) -> some View {
        LazyVGrid(columns: gridColumns, spacing: 12) {
            ForEach(folderIcons, id: \.self) { icon in
                Button {
                    selection.wrappedValue = icon
                } label: {
                    ZStack {
                        Circle()
                            .fill(selection.wrappedValue == icon ? accentColor.opacity(0.18) : Color(.systemGray6))
                            .frame(width: 50, height: 50)
                        Image(systemName: icon)
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(selection.wrappedValue == icon ? accentColor : Color.primary)
                    }
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(iconAccessibilityLabel(for: icon)))
            }
        }
        .padding(.vertical, 8)
    }

    private let folderIcons = [
        "folder.fill",
        "folder.badge.person.crop",
        "briefcase.fill",
        "house.fill",
        "heart.fill",
        "star.fill",
        "flag.fill",
        "book.fill",
        "lightbulb.fill",
        "cart.fill"
    ]

    private let iconDisplayNames: [String: String] = [
        "folder.fill": "Folder",
        "folder.badge.person.crop": "Shared Folder",
        "briefcase.fill": "Briefcase",
        "house.fill": "House",
        "heart.fill": "Heart",
        "star.fill": "Star",
        "flag.fill": "Flag",
        "book.fill": "Book",
        "lightbulb.fill": "Lightbulb",
        "cart.fill": "Cart"
    ]

    private func iconAccessibilityLabel(for icon: String) -> String {
        iconDisplayNames[icon] ?? icon.replacingOccurrences(of: ".", with: " ")
    }
}

// MARK: - Folder Notes View
struct FolderNotesView: View {
    let folderName: String
    let notes: [NoteModel]
    let onCreateNote: () -> Void
    let onEditNote: (NoteModel) -> Void
    let onDeleteNote: (NoteModel) -> Void
    let onTogglePin: (NoteModel) -> Void

    @State private var searchText = ""

    var filteredNotes: [NoteModel] {
        if searchText.isEmpty {
            return notes
        }
        let query = searchText.lowercased()
        return notes.filter { note in
            note.content.lowercased().contains(query) ||
            (note.title?.lowercased().contains(query) ?? false)
        }
    }

    var body: some View {
        Group {
            if filteredNotes.isEmpty {
                ScrollView {
                    EmptyStateView(
                        systemImage: "note.text",
                        title: "No Notes",
                        message: searchText.isEmpty ? "Create a new note to see it here." : "No notes match your search."
                    )
                    .frame(maxWidth: .infinity)
                }
            } else {
                List {
                    ForEach(Array(filteredNotes.enumerated()), id: \.element.id) { index, note in
                        NoteCardView(note: note)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onEditNote(note)
                            }
                            .contextMenu {
                                Button(note.isPinned ? "Unpin" : "Pin", systemImage: "pin") {
                                    onTogglePin(note)
                                }
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    onDeleteNote(note)
                                }
                            }
                            .listRowSeparator(index == filteredNotes.count - 1 ? .hidden : .visible, edges: .bottom)
                            .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(folderName)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: onCreateNote) {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
    }
}

#Preview {
    let environment = AppEnvironment(persistence: PersistenceController.preview)
    environment.bootstrap()
    return NotesView(environment: environment, onCreateNote: {}, onEditNote: { _ in })
}
