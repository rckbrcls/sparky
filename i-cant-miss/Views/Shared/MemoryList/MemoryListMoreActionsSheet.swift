import SwiftUI

struct MemoryListMoreActionsSheet: View {
    let canEdit: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        List {
            if canEdit {
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                }
            }

            Button(role: .destructive, action: onDelete) {
                Label {
                    Text("Delete")
                } icon: {
                    Image(systemName: "trash")
                        .foregroundStyle(Color.red)
                }
            }
        }
        .scrollDisabled(true)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}
