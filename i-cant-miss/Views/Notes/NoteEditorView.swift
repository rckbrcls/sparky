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

    @State private var isShowingDetails = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case title
        case body
    }

    init(environment: AppEnvironment, existingNote: NoteModel?) {
        self.environment = environment
        _viewModel = StateObject(wrappedValue: NoteEditorViewModel(environment: environment, note: existingNote))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemBackground)
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 12) {
                        metadataSummary
                        Divider()
                            .padding(.top, 12)
                        
                        TextField("Title", text: $viewModel.title)
                            .font(.system(size: 32, weight: .bold, design: .default))
                            .textInputAutocapitalization(.sentences)
                            .disableAutocorrection(false)
                            .focused($focusedField, equals: .title)
                            .submitLabel(.next)
                            .onSubmit {
                                focusedField = .body
                            }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 28)

                    ZStack(alignment: .topLeading) {
                        if viewModel.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("Note")
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 20)
                                .padding(.top, 20)
                        }

                        TextEditor(text: $viewModel.content)
                            .focused($focusedField, equals: .body)
                            .padding(.horizontal, 12)
                            .padding(.top, 12)
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .navigationTitle(viewModelTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isShowingDetails = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Note options")
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
            .sheet(isPresented: $isShowingDetails) {
                NavigationStack {
                    Form {
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
                    .navigationTitle("Note Details")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {
                                isShowingDetails = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium])

            }
            .onAppear {
                viewModel.loadData()
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
    }

    private var viewModelTitle: String {
        viewModel.title.isEmpty ? "New Note" : "Edit Note"
    }

    @ViewBuilder
    private var metadataSummary: some View {
        if viewModel.isNewNote && metadataIsEmpty {
            newNoteDetailsCallout
        } else {
            standardMetadataSummary
        }
    }

    private var metadataIsEmpty: Bool {
        !viewModel.isPinned && viewModel.selectedFolderID == nil && selectedTagNames.isEmpty
    }

    private var newNoteDetailsCallout: some View {
        Button {
            isShowingDetails = true
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
                    .foregroundStyle(.tint)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Note options")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Pin, choose folder or add tags")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.accentColor.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open note options")
    }

    private var standardMetadataSummary: some View {
        HStack(spacing: 12) {
            if viewModel.isPinned {
                Label("Pinned", systemImage: "pin.fill")
            }

            if let folderName = selectedFolderName {
                Label(folderName, systemImage: "folder")
            }

            if !selectedTagNames.isEmpty {
                Label(selectedTagNames.joined(separator: ", "), systemImage: "tag")
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    private var selectedFolderName: String? {
        environment.folderService.folders.first(where: { $0.id == viewModel.selectedFolderID })?.name
    }

    private var selectedTagNames: [String] {
        environment.folderService.tags
            .filter { viewModel.selectedTagIDs.contains($0.id) }
            .map(\.name)
    }
}

#Preview {
    let environment = AppEnvironment(persistence: PersistenceController.preview)
    environment.bootstrap()
    return NoteEditorView(environment: environment, existingNote: nil)
}
