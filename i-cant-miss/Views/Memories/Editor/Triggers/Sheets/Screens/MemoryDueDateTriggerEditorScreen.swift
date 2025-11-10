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
