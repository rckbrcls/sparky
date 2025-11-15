import SwiftUI

struct MemoryDateAndTimeTriggerEditorScreen: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: MemoryEditorViewModel
    private let showsCloseButton: Bool
    @State private var fireDate: Date
    @State private var selectedFrequency: RecurrenceFrequency?
    @State private var repeatInterval: Int
    @State private var selectedDays: Set<Int>
    @State private var showWeekdaySelection: Bool

    private var existingTrigger: MemoryTriggerDraft? {
        viewModel.triggers.first(where: { $0.type == .scheduled })
    }

    init(viewModel: MemoryEditorViewModel, showsCloseButton: Bool = true) {
        self.viewModel = viewModel
        self.showsCloseButton = showsCloseButton
        let scheduledTrigger = viewModel.triggers.first(where: { $0.type == .scheduled })
        let defaultDate = scheduledTrigger?.fireDate ?? Date().addingTimeInterval(3600)
        _fireDate = State(initialValue: defaultDate)
        _selectedFrequency = State(initialValue: scheduledTrigger?.recurrenceRule?.frequency)
        _repeatInterval = State(initialValue: max(scheduledTrigger?.recurrenceRule?.interval ?? 1, 1))

        let initialSelection = Self.initialWeekdaySelection(from: scheduledTrigger?.weekdayMask ?? 0)
        _selectedDays = State(initialValue: initialSelection)
        let hasRecurrence = scheduledTrigger?.recurrenceRule != nil
        _showWeekdaySelection = State(initialValue: hasRecurrence && !initialSelection.isEmpty)
    }

    var body: some View {
        Form {
            Section("Date & Time") {
                DatePicker("Date", selection: $fireDate, displayedComponents: [.date])
                DatePicker("Time", selection: $fireDate, displayedComponents: [.hourAndMinute])

                Picker("Repeat", selection: $selectedFrequency) {
                    Text("Never").tag(nil as RecurrenceFrequency?)
                    ForEach(RecurrenceFrequency.allCases, id: \.self) { frequency in
                        Text(frequency.rawValue.capitalized).tag(Optional(frequency))
                    }
                }
                .onChange(of: selectedFrequency) { oldValue, newValue in
                    if newValue != nil && selectedDays.isEmpty {
                        // Se recorrência foi selecionada e não há dias selecionados, mostrar seleção
                        showWeekdaySelection = true
                        if selectedDays.isEmpty {
                            selectedDays.insert(Calendar.current.component(.weekday, from: Date()))
                        }
                    } else if newValue == nil {
                        // Se recorrência foi removida, limpar seleção de dias
                        showWeekdaySelection = false
                        selectedDays.removeAll()
                    }
                }

                if selectedFrequency != nil {
                    Stepper(value: $repeatInterval, in: 1...30) {
                        Text("Every \(repeatInterval) interval\(repeatInterval == 1 ? "" : "s")")
                    }

                    Toggle("Select specific weekdays", isOn: $showWeekdaySelection)
                        .onChange(of: showWeekdaySelection) { oldValue, newValue in
                            if newValue && selectedDays.isEmpty {
                                selectedDays.insert(Calendar.current.component(.weekday, from: Date()))
                            } else if !newValue {
                                selectedDays.removeAll()
                            }
                        }

                    if showWeekdaySelection {
                        MemoryWeekdaySelectionView(selectedDays: $selectedDays)

                        if selectedDays.isEmpty {
                            Text("Select at least one weekday to keep this trigger active.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Date & Time")
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
                .disabled(showWeekdaySelection && selectedDays.isEmpty)
                .accessibilityLabel(confirmationAccessibilityLabel)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if existingTrigger != nil {
                    Button(role: .destructive, action: removeTrigger) {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Remove date & time trigger")
                }
            }
        }
    }

    private func applyChanges() {
        guard !(showWeekdaySelection && selectedDays.isEmpty) else { return }

        let recurrence = selectedFrequency.map { RecurrenceRule(frequency: $0, interval: repeatInterval) }
        let weekdaySelection = showWeekdaySelection ? selectedDays : []

        viewModel.setScheduledTrigger(
            fireDate: fireDate,
            recurrence: recurrence,
            weekdaySelection: weekdaySelection,
            referenceTime: fireDate
        )
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

    private static func initialWeekdaySelection(from mask: Int16) -> Set<Int> {
        var set = weekdaySet(from: mask)
        if set.isEmpty {
            set.insert(currentWeekday())
        }
        return set
    }

    private static func weekdaySet(from mask: Int16) -> Set<Int> {
        var set = Set<Int>()
        for day in 1...7 {
            let bit = Int16(1 << day)
            if mask & bit != 0 {
                set.insert(day)
            }
        }
        return set
    }

    private static func currentWeekday() -> Int {
        Calendar.current.component(.weekday, from: Date())
    }
}
