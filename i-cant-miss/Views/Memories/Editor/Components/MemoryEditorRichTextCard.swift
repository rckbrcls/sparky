import SwiftUI

struct MemoryEditorRichTextCard: View {
    @Binding var text: String
    @ObservedObject var controller: RichTextEditorController
    var isEditable: Bool = true

    var body: some View {
        MemoryEditorContentCard {
            ZStack(alignment: .topLeading) {
                RichTextEditor(
                    text: $text,
                    controller: controller,
                    isEditable: isEditable
                )
                .frame(minHeight: 160)

                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(isEditable ? "Write something memorable…" : "No notes captured for this memory.")
                        .foregroundStyle(.secondary)
                        .padding(.top, 12)
                }
            }
        }
    }
}
