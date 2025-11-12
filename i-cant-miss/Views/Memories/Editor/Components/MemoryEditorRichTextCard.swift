import SwiftUI

struct MemoryEditorRichTextCard: View {
    @Binding var text: String
    var isEditable: Bool = true

    var body: some View {
        MemoryEditorContentCard {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled(false)
                    .frame(minHeight: 160)
                    .padding(.top, 4)
                    .padding(.horizontal, -4)
                    .disabled(!isEditable)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)

                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(isEditable ? "Write something memorable…" : "No notes captured for this memory.")
                        .foregroundStyle(.secondary)
                        .padding(.top, 12)
                        .padding(.horizontal, 8)
                }
            }
        }
    }
}
