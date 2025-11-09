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

struct ChecklistNewItemRow: View {
    @Binding var draft: ChecklistDraftRow
    let focus: FocusState<UUID?>.Binding
    let onSubmit: (UUID) -> Void
    let onTitleChange: (UUID, String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "circle")
                    .foregroundStyle(.secondary)
                TextField("New item", text: $draft.title)
                    .submitLabel(.next)
                    .focused(focus, equals: draft.id)
                    .onSubmit { onSubmit(draft.id) }
                    .onChange(of: draft.title) { _, newValue in
                        onTitleChange(draft.id, newValue)
                    }

                if shouldShowClear {
                    Button {
                        draft.title = ""
                        draft.detail = ""
                        onTitleChange(draft.id, "")
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                }
            }

            if shouldShowDetailField {
                TextField("Details", text: $draft.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .submitLabel(.next)
                    .onSubmit { onSubmit(draft.id) }
            }
        }
        .padding(.vertical, 4)
    }

    private var shouldShowClear: Bool {
        !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !draft.detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var shouldShowDetailField: Bool {
        shouldShowClear
    }
}

struct ChecklistDraftRow: Identifiable, Equatable {
    let id: UUID
    var title: String
    var detail: String

    init(id: UUID = UUID(), title: String = "", detail: String = "") {
        self.id = id
        self.title = title
        self.detail = detail
    }

    var isEffectivelyEmpty: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
