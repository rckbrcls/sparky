import SwiftUI

struct MemoryExactTimeTriggerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: MemoryEditorViewModel
    @State private var isEnabled: Bool
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
        _isEnabled = State(initialValue: timeTrigger != nil)
        _fireDate = State(initialValue: defaultDate)
        _selectedFrequency = State(initialValue: timeTrigger?.recurrenceRule?.frequency)
        _repeatInterval = State(initialValue: max(timeTrigger?.recurrenceRule?.interval ?? 1, 1))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Exact Time") {
                    Toggle("Enable exact time", isOn: $isEnabled.animation())
                    if isEnabled {
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
                    } else if existingTrigger != nil {
                        Text("This memory currently has a time trigger. Disabling removes it.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Exact Time")
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
            let recurrence = selectedFrequency.map { RecurrenceRule(frequency: $0, interval: repeatInterval) }
            viewModel.setTimeTrigger(fireDate: fireDate, recurrence: recurrence)
        } else {
            viewModel.setTimeTrigger(fireDate: nil, recurrence: nil)
        }
        dismiss()
    }
}
