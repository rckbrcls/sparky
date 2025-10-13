//
//  NoteEditorView.swift
//  i-cant-miss
//
//  Created by Codex on 13/10/25.
//

import SwiftUI

struct NoteEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: NoteEditorViewModel
    let environment: AppEnvironment

    init(environment: AppEnvironment, existingNote: NoteModel?) {
        self.environment = environment
        _viewModel = StateObject(wrappedValue: NoteEditorViewModel(environment: environment, note: existingNote))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Content") {
                    TextField("Title (optional)", text: $viewModel.title)
                    TextEditor(text: $viewModel.content)
                        .frame(minHeight: 200)
                }

                Section("Organization") {
                    Toggle("Pin note", isOn: $viewModel.isPinned)

                    Picker("Folder", selection: $viewModel.selectedFolderID) {
                        Text("No folder").tag(UUID?.none)
                        ForEach(environment.folderService.folders, id: \.id) { folder in
                            Text(folder.name).tag(Optional(folder.id))
                        }
                    }
                }

                if !environment.folderService.tags.isEmpty {
                    Section("Tags") {
                        ForEach(environment.folderService.tags, id: \.id) { tag in
                            Button {
                                viewModel.toggleTag(id: tag.id)
                            } label: {
                                HStack {
                                    Text(tag.name)
                                    Spacer()
                                    if viewModel.selectedTagIDs.contains(tag.id) {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .onAppear {
                viewModel.loadData()
            }
            .navigationTitle(viewModelTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            let success = await viewModel.save()
                            if success { dismiss() }
                        }
                    } label: {
                        if viewModel.isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
            .alert("Cannot save", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { _ in viewModel.errorMessage = nil }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private var viewModelTitle: String {
        viewModel.title.isEmpty ? "New Note" : "Edit Note"
    }
}

#Preview {
    let environment = AppEnvironment(persistence: PersistenceController.preview)
    environment.bootstrap()
    return NoteEditorView(environment: environment, existingNote: nil)
}
