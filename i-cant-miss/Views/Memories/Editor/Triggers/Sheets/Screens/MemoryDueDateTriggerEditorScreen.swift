import SwiftUI

struct MemoryDueDateTriggerEditorScreen: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: MemoryEditorViewModel
    @State private var dueDate: Date
    private let showsCloseButton: Bool

    init(viewModel: MemoryEditorViewModel, showsCloseButton: Bool = true) {
        self.viewModel = viewModel
        self.showsCloseButton = showsCloseButton
        _dueDate = State(initialValue: viewModel.dueDate)
    }

    var body: some View {
        Form {
            Section("Due Date") {
                DatePicker("Date", selection: $dueDate, displayedComponents: [.date])
                DatePicker("Time", selection: $dueDate, displayedComponents: [.hourAndMinute])
            }
        }
        .navigationTitle("Due Date")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsCloseButton {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: dismiss.callAsFunction) {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close")
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(action: applyChanges) {
                    Image(systemName: "checkmark")
                }
                .accessibilityLabel("Save")
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if viewModel.dueDateEnabled {
                    Button(role: .destructive, action: removeDueDate) {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Remove due date")
                }
            }
        }
    }

    private func applyChanges() {
        viewModel.dueDate = dueDate
        viewModel.dueDateEnabled = true
        dismiss()
    }

    private func removeDueDate() {
        viewModel.dueDateEnabled = false
        dismiss()
    }
}
