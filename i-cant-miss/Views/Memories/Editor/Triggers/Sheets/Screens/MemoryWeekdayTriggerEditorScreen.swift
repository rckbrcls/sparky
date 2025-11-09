import SwiftUI

struct MemoryWeekdayTriggerEditorScreen: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: MemoryEditorViewModel
    @State private var selectedDays: Set<Int>
    @State private var referenceTime: Date

    private var existingTrigger: MemoryTriggerDraft? {
        viewModel.triggers.first(where: { $0.type == .dayOfWeek })
    }

    init(viewModel: MemoryEditorViewModel) {
        self.viewModel = viewModel
        let weekdayTrigger = viewModel.triggers.first(where: { $0.type == .dayOfWeek })
        let timeTrigger = viewModel.triggers.first(where: { $0.type == .time })
        let initialSelection = Self.initialWeekdaySelection(from: weekdayTrigger?.weekdayMask ?? 0)
        let defaultReference = weekdayTrigger?.fireDate ?? timeTrigger?.fireDate ?? Date().addingTimeInterval(3600)
        _selectedDays = State(initialValue: initialSelection)
        _referenceTime = State(initialValue: defaultReference)
    }

    var body: some View {
        Form {
            Section("Weekday Routine") {
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
            }
        }
        .navigationTitle("Weekday Routine")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(existingTrigger == nil ? "Add" : "Save") {
                    applyChanges()
                }
                .disabled(selectedDays.isEmpty)
            }
        }
    }

    private var summaryText: String {
        let mask = Self.mask(from: selectedDays)
        return weekdayMaskSummary(mask: mask)
    }

    private func applyChanges() {
        guard !selectedDays.isEmpty else { return }
        viewModel.setWeekdayTrigger(weekdaySelection: selectedDays, referenceTime: referenceTime)
        dismiss()
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

    private static func mask(from set: Set<Int>) -> Int16 {
        set.reduce(into: Int16(0)) { result, day in
            result |= Int16(1 << day)
        }
    }

    private static func currentWeekday() -> Int {
        Calendar.current.component(.weekday, from: Date())
    }
}


