import SwiftUI

enum ScheduleType: String, CaseIterable {
    case weekdays = "Weekdays"
    case exactDate = "Exact Date"
}

struct MemoryDateAndTimeTriggerEditorScreen: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: MemoryEditorViewModel
    private let showsCloseButton: Bool
    @State private var fireDate: Date
    @State private var scheduleType: ScheduleType
    @State private var selectedFrequency: RecurrenceFrequency?
    @State private var repeatInterval: Int
    @State private var selectedDays: Set<Int>

    private var existingTrigger: MemoryTriggerDraft? {
        viewModel.triggers.first(where: { $0.type == .scheduled })
    }

    init(viewModel: MemoryEditorViewModel, showsCloseButton: Bool = true) {
        self.viewModel = viewModel
        self.showsCloseButton = showsCloseButton
        let scheduledTrigger = viewModel.triggers.first(where: { $0.type == .scheduled })
        let defaultDate = scheduledTrigger?.fireDate ?? Date().addingTimeInterval(3600)
        _fireDate = State(initialValue: defaultDate)

        // Detect schedule type based on existing trigger
        let hasWeekdayMask = (scheduledTrigger?.weekdayMask ?? 0) != 0
        let detectedType: ScheduleType = hasWeekdayMask ? .weekdays : .exactDate
        _scheduleType = State(initialValue: detectedType)

        // Initialize frequency and interval
        _selectedFrequency = State(initialValue: scheduledTrigger?.recurrenceRule?.frequency)
        _repeatInterval = State(initialValue: max(scheduledTrigger?.recurrenceRule?.interval ?? 1, 1))

        // Initialize weekday selection
        let initialSelection = Self.initialWeekdaySelection(from: scheduledTrigger?.weekdayMask ?? 0)
        _selectedDays = State(initialValue: initialSelection)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Summary Card
            summaryCard
                .padding()

            Form {
                // Section 1: Time
                Section("Time") {
                    DatePicker("Time", selection: $fireDate, displayedComponents: [.hourAndMinute])
                }

                // Section 2: Schedule Type
                Section {
                    Picker("Type", selection: $scheduleType) {
                        ForEach(ScheduleType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: scheduleType) { oldValue, newValue in
                        // Reset states when switching types
                        if newValue == .exactDate {
                            selectedDays.removeAll()
                            // If switching to exact date, keep frequency if it's monthly/yearly
                            if let freq = selectedFrequency, freq != .monthly && freq != .yearly {
                                selectedFrequency = nil
                            }
                        } else if newValue == .weekdays {
                            // If switching to weekdays, clear frequency but keep interval for weeks
                            selectedFrequency = nil
                            if selectedDays.isEmpty {
                                selectedDays.insert(Calendar.current.component(.weekday, from: Date()))
                            }
                        }
                    }
                }

                // Section 3: Weekdays or Date
                if scheduleType == .weekdays {
                    Section("Weekdays") {
                        MemoryWeekdaySelectionView(selectedDays: $selectedDays)

                        if selectedDays.isEmpty {
                            Text("Select at least one weekday to keep this trigger active.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        // Interval for weekdays (weeks)
                        Stepper(value: $repeatInterval, in: 1...30) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Every \(repeatInterval) week\(repeatInterval == 1 ? "" : "s")")
                                    .font(.body)
                                Text(repeatInterval == 1
                                    ? "Triggers every week"
                                    : "Skips \(repeatInterval - 1) week\(repeatInterval == 2 ? "" : "s") between reminders")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } else {
                    Section("Date") {
                        DatePicker("Date", selection: $fireDate, displayedComponents: [.date])
                    }
                }

                // Section 4: Repeat (only for Exact Date)
                if scheduleType == .exactDate {
                    Section("Repeat") {
                        Picker("Repeat", selection: $selectedFrequency) {
                            Text("Never").tag(nil as RecurrenceFrequency?)
                            Text("Monthly").tag(Optional(RecurrenceFrequency.monthly))
                            Text("Yearly").tag(Optional(RecurrenceFrequency.yearly))
                        }

                        if selectedFrequency != nil {
                            let intervalLabel: String = {
                                switch selectedFrequency {
                                case .monthly:
                                    return "Every \(repeatInterval) month\(repeatInterval == 1 ? "" : "s")"
                                case .yearly:
                                    return "Every \(repeatInterval) year\(repeatInterval == 1 ? "" : "s")"
                                default:
                                    return ""
                                }
                            }()

                            let intervalDescription: String = {
                                switch selectedFrequency {
                                case .monthly:
                                    return repeatInterval == 1
                                        ? "Triggers every month on the same date"
                                        : "Skips \(repeatInterval - 1) month\(repeatInterval == 2 ? "" : "s") between reminders"
                                case .yearly:
                                    return repeatInterval == 1
                                        ? "Triggers every year on the same date"
                                        : "Skips \(repeatInterval - 1) year\(repeatInterval == 2 ? "" : "s") between reminders"
                                default:
                                    return ""
                                }
                            }()

                            Stepper(value: $repeatInterval, in: 1...30) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(intervalLabel)
                                        .font(.body)
                                    Text(intervalDescription)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
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
                .disabled(scheduleType == .weekdays && selectedDays.isEmpty)
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

    // MARK: - Summary View

    private var summaryCard: some View {
        summaryText
            .font(.subheadline)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(24)
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }

    private var summaryText: Text {
        if scheduleType == .weekdays {
            let mask = selectedDays.reduce(into: Int16(0)) { partialResult, day in
                partialResult |= Int16(1 << day)
            }
            let weekdaySummary = weekdayMaskSummary(mask: mask)
            let timeText = fireDate.formatted(date: .omitted, time: .shortened)
            let frequencyText = selectedDays.isEmpty ? "" : " • Every \(repeatInterval) week\(repeatInterval == 1 ? "" : "s")"

            let fullText = "\(scheduleType.rawValue) • \(weekdaySummary) • \(timeText)\(frequencyText)"
            var attributedString = AttributedString(fullText)

            // Apply accent color and bold to weekdaySummary
            if let range = attributedString.range(of: weekdaySummary) {
                attributedString[range].foregroundColor = .accentColor
                attributedString[range].font = .subheadline.bold()
            }

            // Apply accent color and bold to frequencyText if present
            if !frequencyText.isEmpty {
                let freqOnly = String(frequencyText.dropFirst(3)) // Remove " • "
                if let range = attributedString.range(of: freqOnly) {
                    attributedString[range].foregroundColor = .accentColor
                    attributedString[range].font = .subheadline.bold()
                }
            }

            return Text(attributedString)
        } else {
            let dateText = fireDate.formatted(date: .abbreviated, time: .omitted)
            let timeText = fireDate.formatted(date: .omitted, time: .shortened)

            if let frequency = selectedFrequency {
                let frequencyText: String = {
                    switch frequency {
                    case .monthly:
                        return "Every \(repeatInterval) month\(repeatInterval == 1 ? "" : "s")"
                    case .yearly:
                        return "Every \(repeatInterval) year\(repeatInterval == 1 ? "" : "s")"
                    default:
                        return frequency.rawValue.capitalized
                    }
                }()

                let fullText = "\(scheduleType.rawValue) • \(dateText) • \(timeText) • \(frequencyText)"
                var attributedString = AttributedString(fullText)

                // Apply accent color and bold to dateText
                if let range = attributedString.range(of: dateText) {
                    attributedString[range].foregroundColor = .accentColor
                    attributedString[range].font = .subheadline.bold()
                }

                // Apply accent color and bold to frequencyText
                if let range = attributedString.range(of: frequencyText) {
                    attributedString[range].foregroundColor = .accentColor
                    attributedString[range].font = .subheadline.bold()
                }

                return Text(attributedString)
            } else {
                let fullText = "\(scheduleType.rawValue) • \(dateText) • \(timeText)"
                var attributedString = AttributedString(fullText)

                // Apply accent color and bold to dateText
                if let range = attributedString.range(of: dateText) {
                    attributedString[range].foregroundColor = .accentColor
                    attributedString[range].font = .subheadline.bold()
                }

                return Text(attributedString)
            }
        }
    }

    // MARK: - Actions

    private func applyChanges() {
        guard !(scheduleType == .weekdays && selectedDays.isEmpty) else { return }

        let recurrence: RecurrenceRule?
        let weekdaySelection: Set<Int>

        if scheduleType == .weekdays {
            // For weekdays, we use weekly recurrence with the interval
            // and set the weekday selection
            recurrence = RecurrenceRule(frequency: .weekly, interval: repeatInterval)
            weekdaySelection = selectedDays
        } else {
            // For exact date, use the selected frequency (if any)
            recurrence = selectedFrequency.map { RecurrenceRule(frequency: $0, interval: repeatInterval) }
            weekdaySelection = []
        }

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

    // MARK: - Helper Methods

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
