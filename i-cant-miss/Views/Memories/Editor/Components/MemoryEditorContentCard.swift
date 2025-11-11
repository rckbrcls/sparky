import SwiftUI

struct MemoryEditorContentCard<Content: View>: View {
    let removeLabel: String
    var onRemove: (() -> Void)?
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .liquidGlass(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .contextMenu {
                if let onRemove {
                    Button(role: .destructive) {
                        onRemove()
                    } label: {
                        Label(removeLabel, systemImage: "trash")
                    }
                }
            }
    }
}
