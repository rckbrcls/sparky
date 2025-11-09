import SwiftUI

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


