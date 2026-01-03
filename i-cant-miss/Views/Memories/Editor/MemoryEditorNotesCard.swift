//
//  MemoryEditorNotesCard.swift
//  i-cant-miss
//
//  Created by Codex on 09/03/24.
//

import SwiftUI

struct MemoryEditorNotesCard: View {
    @ObservedObject var viewModel: MemoryEditorViewModel
    var isEditingEnabled: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $viewModel.note)
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled(false)
                .frame(minHeight: 120)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .disabled(!isEditingEnabled)
                .scrollContentBackground(.hidden)
                .background(Color.clear)

            if viewModel.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(isEditingEnabled ? "Write something memorable…" : "No notes captured for this memory.")
                    .foregroundStyle(Color(uiColor: .placeholderText))
                    .padding(.top, 16)
                    .padding(.horizontal, 16)
                    .allowsHitTesting(false)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .padding(.horizontal, 20)
        .listRowSeparator(.hidden)
        .listRowInsets(.init(top: 0, leading: 0, bottom: 16, trailing: 0))
        .listRowBackground(Color.clear)
    }
}
