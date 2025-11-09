import SwiftUI

struct ChecklistItemEditor: View {
    @Binding var item: CheckItemDraft
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button(action: onToggle) {
                    Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(item.isCompleted ? .green : .secondary)
                }
                .buttonStyle(.plain)

                TextField("Item title", text: $item.title)
                    .submitLabel(.next)

                if shouldShowDelete {
                    Button(action: onDelete) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                }
            }

            TextField("Details", text: $item.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .submitLabel(.next)
        }
        .padding(.vertical, 4)
    }

    private var shouldShowDelete: Bool {
        let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let detail = item.detail.trimmingCharacters(in: .whitespacesAndNewlines)
        return !title.isEmpty || !detail.isEmpty
    }
}


