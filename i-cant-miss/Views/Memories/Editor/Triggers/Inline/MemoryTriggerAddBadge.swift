import SwiftUI

struct MemoryTriggerAddBadge: View {
    @Binding var isPresented: Bool

    var body: some View {
        Button {
            isPresented = true
        } label: {
            HStack {
                Label("Add Trigger", systemImage: "plus")
                    .font(.caption.bold())
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.glassProminent)
    }
}


