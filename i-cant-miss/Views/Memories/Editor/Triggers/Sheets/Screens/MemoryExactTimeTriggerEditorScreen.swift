import SwiftUI

struct MemoryExactTimeTriggerEditorScreen: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: MemoryEditorViewModel
    private let showsCloseButton: Bool
    @State private var fireDate: Date
    @State private var selectedFrequency: RecurrenceFrequency?
    @State private var repeatInterval: Int

    private var existingTrigger: MemoryTriggerDraft? {
        viewModel.triggers.first(where: { $0.type == .time })
    }

    init(viewModel: MemoryEditorViewModel, showsCloseButton: Bool = true) {
        self.viewModel = viewModel
        self.showsCloseButton = showsCloseButton
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
                    Text("Never").tag(nil as RecurrenceFrequency?)
                    ForEach(RecurrenceFrequency.allCases, id: \.self) { frequency in
                        Text(frequency.rawValue.capitalized).tag(Optional(frequency))
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
            if showsCloseButton {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: dismiss.callAsFunction) {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close")
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(role: .confirm, action: applyChanges) {
                    Image(systemName: confirmationIconName)
                }
                .accessibilityLabel(confirmationAccessibilityLabel)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if existingTrigger != nil {
                    Button(role: .destructive, action: removeTrigger) {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Remove exact time trigger")
                }
            }
        }
    }

    private func applyChanges() {
        let recurrence = selectedFrequency.map { RecurrenceRule(frequency: $0, interval: repeatInterval) }
        viewModel.setTimeTrigger(fireDate: fireDate, recurrence: recurrence)
        dismiss()
    }

    private func removeTrigger() {
        guard let trigger = existingTrigger else { return }
        viewModel.removeTrigger(id: trigger.id)
        dismiss()
    }

    private var confirmationIconName: String { "checkmark" }

    private var confirmationAccessibilityLabel: String {
        existingTrigger == nil ? "Add" : "Save"
    }
}
