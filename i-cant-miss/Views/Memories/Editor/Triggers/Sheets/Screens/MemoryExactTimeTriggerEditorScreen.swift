import SwiftUI

struct MemoryExactTimeTriggerEditorScreen: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: MemoryEditorViewModel
    @State private var fireDate: Date
    @State private var selectedFrequency: RecurrenceRule.Frequency?
    @State private var repeatInterval: Int

    private var existingTrigger: MemoryTriggerDraft? {
        viewModel.triggers.first(where: { $0.type == .time })
    }

    init(viewModel: MemoryEditorViewModel) {
        self.viewModel = viewModel
        let timeTrigger = viewModel.triggers.first(where: { $0.type == .time })
        let weekdayTrigger = viewModel.triggers.first(where: { $0.type == .dayOfWeek })
        let defaultDate = timeTrigger?.fireDate ?? weekdayTrigger?.fireDate ?? Date().addingTimeInterval(3600)
        _fireDate = State(initialValue: defaultDate)
        _selectedFrequency = State(initialValue: timeTrigger?.recurrenceRule?.frequency)
        _repeatInterval = State(initialValue: max(timeTrigger?.recurrenceRule?.interval ?? 1, 1))
    }

    var body: some View {
        Form {
            Section("Exact Time") {
                DatePicker("Date", selection: $fireDate, displayedComponents: [.date])
                DatePicker("Time", selection: $fireDate, displayedComponents: [.hourAndMinute])

                Picker("Repeat", selection: $selectedFrequency) {
                    Text("Never").tag(nil as RecurrenceRule.Frequency?)
                    ForEach(RecurrenceRule.Frequency.allCases, id: \.self) { frequency in
                        Text(frequency.title).tag(Optional(frequency))
                    }
                }

                if selectedFrequency != nil {
                    Stepper(value: $repeatInterval, in: 1...30) {
                        Text("Every \(repeatInterval) interval\(repeatInterval == 1 ? "" : "s")")
                    }
                }
            }
        }
        .navigationTitle("Exact Time")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(action: applyChanges) {
                    Image(systemName: confirmationIconName)
                }
                .accessibilityLabel(confirmationAccessibilityLabel)
            }
        }
    }

    private func applyChanges() {
        let recurrence = selectedFrequency.map { RecurrenceRule(frequency: $0, interval: repeatInterval) }
        viewModel.setTimeTrigger(fireDate: fireDate, recurrence: recurrence)
        dismiss()
    }

    private var confirmationIconName: String {
        existingTrigger == nil ? "plus" : "checkmark"
    }

    private var confirmationAccessibilityLabel: String {
        existingTrigger == nil ? "Add" : "Save"
    }
}
