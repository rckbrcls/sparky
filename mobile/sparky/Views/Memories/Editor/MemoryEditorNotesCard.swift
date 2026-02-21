//
//  MemoryEditorNotesCard.swift
//  sparky
//
//  Created by Codex on 09/03/24.
//

import SwiftUI

struct MemoryEditorNotesCard: View {
    @ObservedObject var viewModel: MemoryEditorViewModel
    var isEditingEnabled: Bool

    var body: some View {
        VStack(alignment: .leading) {
            if isEditingEnabled {
                TextField("Write something memorable…", text: $viewModel.note, axis: .vertical)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled(false)
                    .disabled(!isEditingEnabled)
            } else if !viewModel.note.isEmpty {
                Text(viewModel.note)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .frame(minHeight: 120, alignment: .top)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
