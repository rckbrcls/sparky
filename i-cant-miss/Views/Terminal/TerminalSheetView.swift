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
            .background(Color(uiColor: .systemBackground))
            .navigationTitle("Terminal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", role: .cancel) { onClose() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Clear") {
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
