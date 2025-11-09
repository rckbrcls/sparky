import SwiftUI

struct MemoryDueDateTriggerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: MemoryEditorViewModel
    @State private var isEnabled: Bool
    @State private var dueDate: Date

    init(viewModel: MemoryEditorViewModel) {
        self.viewModel = viewModel
        _isEnabled = State(initialValue: viewModel.dueDateEnabled)
        _dueDate = State(initialValue: viewModel.dueDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Due Date") {
                    Toggle("Enable due date", isOn: $isEnabled.animation())
                    if isEnabled {
                        DatePicker("Date", selection: $dueDate, displayedComponents: [.date])
                        DatePicker("Time", selection: $dueDate, displayedComponents: [.hourAndMinute])
                    } else {
                        Text("Turn this on to convert the memory into a dated checklist.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        applyChanges()
                    }
                }
            }
        }
    }

    private func applyChanges() {
        if isEnabled {
            viewModel.dueDate = dueDate
            viewModel.dueDateEnabled = true
        } else {
            viewModel.dueDateEnabled = false
        }
        dismiss()
    }

    private func removeDueDate() {
        viewModel.dueDateEnabled = false
        dismiss()
    }
}


