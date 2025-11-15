import SwiftUI

struct MemoryTriggerAddBadge: View {
    enum DisplayStyle {
        case inline
        case toolbar
    }

    @Binding var isPresented: Bool
    var displayStyle: DisplayStyle = .inline

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Label("Add Trigger", systemImage: "bolt.fill")
                .font(.caption.bold())
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
        }
        .buttonStyle(.glassProminent)
        .accessibilityLabel("Add trigger")

    }  
}
