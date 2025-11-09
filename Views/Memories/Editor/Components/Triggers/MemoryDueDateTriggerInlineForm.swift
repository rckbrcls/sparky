import SwiftUI

struct MemoryDueDateTriggerInlineForm: View {
    @ObservedObject var viewModel: MemoryEditorViewModel
    @Binding var showSheet: Bool

    var body: some View {
        Group {
            if viewModel.dueDateEnabled {
                configuredButton
                    .swipeActions {
                        Button(role: .destructive) {
                            viewModel.dueDateEnabled = false
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            } else {
                addButton
            }
        }
    }

    private var configuredButton: some View {
        Button {
            showSheet = true
        } label: {
            HStack {
                Label("Due: " + viewModel.dueDate.formatted(date: .abbreviated, time: .shortened),
                      systemImage: "calendar")
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.glass)
    }

    private var addButton: some View {
        Button {
            showSheet = true
        } label: {
            Label("Add due date", systemImage: "calendar.badge.plus")
                .foregroundStyle(.accent)
                .font(.caption.bold())
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.glass)
    }
}
