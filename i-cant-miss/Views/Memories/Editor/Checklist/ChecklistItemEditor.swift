import SwiftUI

struct ChecklistItemEditor: View {
    @Binding var item: CheckItemDraft
    let isEditable: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        if isEditable {
            editableBody
        } else {
            readOnlyBody
        }
    }

    private var editableBody: some View {
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

    private var readOnlyBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: onToggle) {
                HStack(spacing: 8) {
                    Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(item.isCompleted ? .green : .secondary)
                    Text(readOnlyTitle)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .strikethrough(item.isCompleted, color: item.isCompleted ? .secondary : nil)
                }
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .accessibilityLabel(readOnlyTitle)
            .accessibilityHint("Toggle checklist item completion")
            .accessibilityValue(item.isCompleted ? "Completed" : "Pending")

            if let detail = readOnlyDetail {
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(.vertical, 6)
    }

    private var shouldShowDelete: Bool {
        let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let detail = item.detail.trimmingCharacters(in: .whitespacesAndNewlines)
        return !title.isEmpty || !detail.isEmpty
    }

    private var readOnlyTitle: String {
        let trimmed = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled Item" : trimmed
    }

    private var readOnlyDetail: String? {
        let trimmed = item.detail.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
