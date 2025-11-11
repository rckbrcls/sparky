import SwiftUI

struct MemoryEditorChecklistCard<Content: View>: View {
    var subtitle: String? = nil
    var onRemove: (() -> Void)?
    @ViewBuilder var content: () -> Content

    var body: some View {
        MemoryEditorContentCard(
            iconName: MemoryEditorContentType.checklist.iconName,
            title: MemoryEditorContentType.checklist.title,
            subtitle: subtitle,
            onRemove: onRemove,
            content: content
        )
    }
}
