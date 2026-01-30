import SwiftUI

struct MemoryEditorContentCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .cardStyle(cornerRadius: 24)
    }
}
