//
//  TerminalSheetView.swift
//  i-cant-miss
//
//  Created by Codex on 18/03/25.
//

import SwiftUI

struct TerminalSheetView: View {
    @Binding var text: String
    var onClose: () -> Void

    @FocusState private var isEditorFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                editor
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .navigationTitle("Terminal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Botão de fechar (fica na extrema esquerda)
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark") // ícone de fechar
                    }
                }

                // Outro botão à esquerda, mas separado do anterior
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            text.removeAll()
                        }
                    } label: {
                        Image(systemName: "trash.fill") // ícone de limpar
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                // Botão de concluir no lado direito
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            text.removeAll()
                        }
                    } label: {
                        Image(systemName: "checkmark") // ícone de confirmar
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
//            .onAppear {
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
//                    isEditorFocused = true
//                }
//            }
        }
        .interactiveDismissDisabled(false)
    }

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(uiColor: .secondarySystemBackground))

            TextEditor(text: $text)
                .focused($isEditorFocused)
                .font(.system(.body, design: .monospaced))
                .padding(12)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .tint(.accentColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topLeading) {
            if text.isEmpty {
                Text("Type here... (e.g. \"/today cancel meeting\" or \"buy coffee\")")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(20)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Text("\(text.count) characters")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(10)
        }
    }
}

#Preview {
    TerminalSheetView(text: .constant("Example draft"), onClose: {})
}
