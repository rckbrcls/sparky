import SwiftUI

struct MemoryEditorRichTextCard: View {
    @Binding var text: String
    @ObservedObject var controller: RichTextEditorController
    var onRemove: (() -> Void)?

    var body: some View {
        MemoryEditorContentCard(
            removeLabel: "Remove rich text",
            onRemove: onRemove
        ) {
            ZStack(alignment: .topLeading) {
                RichTextEditor(
                    text: $text,
                    controller: controller
                )
                .frame(minHeight: 160)

                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Write something memorable…")
                        .foregroundStyle(.secondary)
                        .padding(.top, 12)
                }
            }
        }
    }
}
