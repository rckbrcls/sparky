import SwiftUI

struct MemoryWeekdayTriggerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: MemoryEditorViewModel
    @State private var isEnabled: Bool
    @State private var selectedDays: Set<Int>
    @State private var referenceTime: Date

    private var existingTrigger: MemoryTriggerDraft? {
        viewModel.triggers.first(where: { $0.type == .dayOfWeek })
    }

    init(viewModel: MemoryEditorViewModel) {
        self.viewModel = viewModel
        let weekdayTrigger = viewModel.triggers.first(where: { $0.type == .dayOfWeek })
        let timeTrigger = viewModel.triggers.first(where: { $0.type == .time })
        let initialSet = Self.weekdaySet(from: weekdayTrigger?.weekdayMask ?? 0)
        let defaultReference = weekdayTrigger?.fireDate ?? timeTrigger?.fireDate ?? Date().addingTimeInterval(3600)
        _isEnabled = State(initialValue: !initialSet.isEmpty)
        _selectedDays = State(initialValue: initialSet)
        _referenceTime = State(initialValue: defaultReference)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Weekday Routine") {
                    Toggle("Enable weekday schedule", isOn: $isEnabled.animation())
                    if isEnabled {
                        MemoryWeekdaySelectionView(selectedDays: $selectedDays)

                        DatePicker("Time", selection: $referenceTime, displayedComponents: [.hourAndMinute])

                        if selectedDays.isEmpty {
                            Text("Select at least one weekday to keep this trigger active.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(summaryText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else if existingTrigger != nil {
                        Text("This memory already repeats on weekdays. Disabling removes it.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Weekday Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        applyChanges()
                    }
                    .disabled(isSaveDisabled)
                }
            }
            .onChange(of: isEnabled) { _, newValue in
                if !newValue {
                    selectedDays.removeAll()
                } else if selectedDays.isEmpty {
                    selectedDays.insert(Self.currentWeekday())
                }
            }
        }
    }

    private var isSaveDisabled: Bool {
        isEnabled && selectedDays.isEmpty
    }

    private var summaryText: String {
        let mask = Self.mask(from: selectedDays)
        return weekdayMaskSummary(mask: mask)
    }

    private func applyChanges() {
        if isEnabled && !selectedDays.isEmpty {
            viewModel.setWeekdayTrigger(weekdaySelection: selectedDays, referenceTime: referenceTime)
        } else {
            viewModel.setWeekdayTrigger(weekdaySelection: [], referenceTime: referenceTime)
        }
        dismiss()
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

    private static func mask(from set: Set<Int>) -> Int16 {
        set.reduce(into: Int16(0)) { result, day in
            result |= Int16(1 << day)
        }
    }

    private static func currentWeekday() -> Int {
        Calendar.current.component(.weekday, from: Date())
    }
}
