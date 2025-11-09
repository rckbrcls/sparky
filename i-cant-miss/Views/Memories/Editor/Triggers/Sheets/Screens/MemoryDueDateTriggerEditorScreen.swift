import SwiftUI

struct MemoryDueDateTriggerEditorScreen: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: MemoryEditorViewModel
    @State private var dueDate: Date

    init(viewModel: MemoryEditorViewModel) {
        self.viewModel = viewModel
        _dueDate = State(initialValue: viewModel.dueDate)
    }

    var body: some View {
        Form {
            Section("Due Date") {
                DatePicker("Date", selection: $dueDate, displayedComponents: [.date])
                DatePicker("Time", selection: $dueDate, displayedComponents: [.hourAndMinute])
            }

            if viewModel.dueDateEnabled {
                Section {
                    Button("Remove due date", role: .destructive) {
                        removeDueDate()
                    }
                }
            }
        }
        .navigationTitle("Due Date")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(action: applyChanges) {
                    Image(systemName: "checkmark")
                }
                .accessibilityLabel("Save")
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
