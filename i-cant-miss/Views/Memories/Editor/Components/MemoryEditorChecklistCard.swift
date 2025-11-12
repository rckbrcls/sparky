import SwiftUI

struct MemoryEditorChecklistCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        MemoryEditorContentCard(content: content)
    }
}
