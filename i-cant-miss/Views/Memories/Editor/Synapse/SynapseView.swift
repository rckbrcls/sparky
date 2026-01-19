
import SwiftUI
import UIKit

struct SynapseView: View {
    @Binding var item: CheckItemDraft
    let isEditable: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void
    @FocusState.Binding var focusedField: UUID?
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Button {
                    feedbackGenerator.impactOccurred()
                    onToggle()
                } label: {
                    Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(item.isCompleted ? .green : .secondary)
                }
                .buttonStyle(.plain)
                
                TextField("Title", text: $item.title, axis: .vertical)
                    .font(.callout)
                    .foregroundStyle(item.isCompleted ? .secondary : .primary)
                    .strikethrough(item.isCompleted, color: .secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .disabled(!isEditable)
                    .submitLabel(.next)
                    .focused($focusedField, equals: item.id)

                if isEditable {
                    Button {
                        feedbackGenerator.impactOccurred()
                        withAnimation {
                            onDelete()
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if !isEditable || focusedField != item.id {
                    feedbackGenerator.impactOccurred()
                    onToggle()
                }
            }

            TextField("Description", text: $item.detail, axis: .vertical)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .strikethrough(item.isCompleted, color: .secondary)
                .disabled(!isEditable)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
    }
}
