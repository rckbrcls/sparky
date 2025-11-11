import SwiftUI

struct MemoryEditorChecklistCard<Content: View>: View {
    var onRemove: (() -> Void)?
    @ViewBuilder var content: () -> Content

    var body: some View {
        MemoryEditorContentCard(
            removeLabel: "Remove checklist",
            onRemove: onRemove,
            content: content
        )
    }
}
