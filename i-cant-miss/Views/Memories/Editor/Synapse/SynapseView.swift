
import SwiftUI

struct SynapseView: View {
    @Binding var item: CheckItemDraft
    let isEditable: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void
    @FocusState.Binding var focusedField: UUID?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
             // Card Style Background
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {

                    TextField("Title", text: $item.title, axis: .vertical)
                        .font(.custom("Vollkorn-Regular", size: 17))
                        .foregroundStyle(item.isCompleted ? .secondary : .primary)
                        .strikethrough(item.isCompleted, color: .secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .disabled(!isEditable)
                        .submitLabel(.next)
                        .focused($focusedField, equals: item.id)

                    Spacer()

                    Button {
                        if isEditable {
                            onToggle()
                        }
                    } label: {
                        Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(item.isCompleted ? .green : .secondary)
                    }
                    .buttonStyle(.plain)
                }

                TextField("Description", text: $item.detail, axis: .vertical)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .strikethrough(item.isCompleted, color: .secondary)
                    .disabled(!isEditable)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.primary.opacity(0.03))
                    )
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(.secondarySystemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )

        }
    }
}
