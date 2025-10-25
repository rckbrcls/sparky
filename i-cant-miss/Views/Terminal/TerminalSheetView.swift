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
                Text("Use o terminal para anotar rapidamente qualquer memory. Comandos e parsing inteligente chegam em breve.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                editor

                helperFooter
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color(uiColor: .systemBackground))
            .navigationTitle("Terminal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar", role: .cancel) { onClose() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Limpar") {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            text.removeAll()
                        }
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    isEditorFocused = true
                }
            }
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
                Text("Digite aqui... (ex: \"/today cancelar reuniao\" ou \"comprar cafe\")")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(20)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Text("\(text.count) caracteres")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(10)
        }
    }

    private var helperFooter: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundStyle(Color.accentColor)

            Text("Em breve: comandos com \"/\" e parsing automatico.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }
}

#Preview {
    TerminalSheetView(text: .constant("Example draft"), onClose: {})
}
