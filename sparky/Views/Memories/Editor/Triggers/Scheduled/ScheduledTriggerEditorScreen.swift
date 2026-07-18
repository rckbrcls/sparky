import SwiftUI

// MARK: - Main View

struct ScheduledTriggerEditorScreen: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: MemoryEditorViewModel
    private let showsCloseButton: Bool

    // State
    @State private var fireDate: Date
    @State private var timeOfDayType: TimeOfDayType

    // Repeat state
    @State private var isRepeating: Bool
    @State private var frequency: RecurrenceFrequency
    @State private var interval: Int
    @State private var endType: RecurrenceEndType
    @State private var endDate: Date
    @State private var occurrenceCount: Int
    @State private var selectedWeekdays: Set<Int>
    @State private var selectedMonthDays: Set<Int>

    private var existingConfig: ScheduleConfigDraft? {
        viewModel.scheduleConfig
    }

    init(viewModel: MemoryEditorViewModel, showsCloseButton: Bool = true) {
        self.viewModel = viewModel
        self.showsCloseButton = showsCloseButton

        let scheduleConfig = viewModel.scheduleConfig
        let defaultDate = scheduleConfig?.fireDate ?? Date().addingTimeInterval(3600)
        _fireDate = State(initialValue: defaultDate)

        let detectedTimeOfDay: TimeOfDayType = scheduleConfig?.isAllDay == true ? .allDay : .specificTime
        _timeOfDayType = State(initialValue: detectedTimeOfDay)

        // Detect repeat state from existing config
        let hasRecurrence = scheduleConfig?.recurrenceRule != nil || (scheduleConfig?.weekdayMask ?? 0) != 0
        _isRepeating = State(initialValue: hasRecurrence)

        let existingRule = scheduleConfig?.recurrenceRule
        _frequency = State(initialValue: existingRule?.frequency ?? .daily)
        _interval = State(initialValue: existingRule?.interval ?? 1)

        // Detect end type
        let detectedEndType = scheduleConfig?.recurrenceEndType ?? .never
        _endType = State(initialValue: detectedEndType)
        _endDate = State(initialValue: existingRule?.endDate ?? Calendar.current.date(byAdding: .month, value: 1, to: defaultDate) ?? defaultDate)
        _occurrenceCount = State(initialValue: existingRule?.occurrenceCount ?? 5)

        // Initialize weekday/month day selections
        let initialWeekdays = Self.weekdaySet(from: scheduleConfig?.weekdayMask ?? 0)
        _selectedWeekdays = State(initialValue: initialWeekdays)
        _selectedMonthDays = State(initialValue: [])
    }

    var body: some View {
        Form {
            // Section 1: Time & Date
            Section {
                Picker("Time of Day", selection: $timeOfDayType) {
                    ForEach(TimeOfDayType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }

                if timeOfDayType == .specificTime {
                    DatePicker("Date & Time", selection: $fireDate, displayedComponents: [.date, .hourAndMinute])
                } else {
                    DatePicker("Date", selection: $fireDate, displayedComponents: [.date])
                }
            }

            // Section 2: Repeat
            Section {
                Toggle("Repeat", isOn: $isRepeating.animation(.easeInOut(duration: 0.2)))

                if isRepeating {
                    // Frequency picker
                    Picker("Frequency", selection: $frequency) {
                        ForEach(RecurrenceFrequency.userVisible, id: \.self) { freq in
                            Text(freq.displayName).tag(freq)
                        }
                    }

                    HStack {
                        Text("Every")

                        Spacer()

                        BoundedIntegerField(
                            value: $interval,
                            in: 1...999,
                            accessibilityLabel: "Repeat interval"
                        )

                        Text(interval == 1 ? frequency.singularUnitLabel : frequency.unitLabel)
                    }

                    // Weekday selection for weekly
                    if frequency == .weekly {
                        MemoryWeekdaySelectionView(selectedDays: $selectedWeekdays)
                    }

                    // Month day selection for monthly
                    if frequency == .monthly {
                        MonthDaySelectionView(selectedDays: $selectedMonthDays)
                    }

                    // End condition
                    Picker("Ends", selection: $endType.animation(.easeInOut(duration: 0.2))) {
                        ForEach(RecurrenceEndType.allCases) { type in
                            Text(type.label).tag(type)
                        }
                    }

                    if endType == .untilDate {
                        DatePicker("End Date", selection: $endDate, in: fireDate..., displayedComponents: [.date])
                    }

                    if endType == .afterCount {
                        HStack {
                            Text("After")

                            Spacer()

                            BoundedIntegerField(
                                value: $occurrenceCount,
                                in: 1...999,
                                accessibilityLabel: "Number of occurrences"
                            )

                            Text(occurrenceCount == 1 ? "time" : "times")
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
                    Image(systemName: "checkmark")
                }
                .disabled(!isValid)
                .accessibilityLabel(existingConfig == nil ? "Add" : "Save")
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if existingConfig != nil {
                    Button(role: .destructive, action: removeConfig) {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Remove date & time trigger")
                }
            }
        }
    }

    // MARK: - Validation

    private var isValid: Bool {
        if isRepeating && frequency == .weekly && !selectedWeekdays.isEmpty {
            return true
        }
        if isRepeating && frequency == .monthly && !selectedMonthDays.isEmpty {
            return true
        }
        return true
    }

    // MARK: - Actions

    private func applyChanges() {
        guard isValid else { return }

        var adjustedFireDate = fireDate
        if timeOfDayType == .allDay {
            let calendar = Calendar.current
            adjustedFireDate = calendar.startOfDay(for: fireDate)
        }

        let recurrence: RecurrenceRule?
        var weekdaySelection: Set<Int> = []
        var resolvedEndType: RecurrenceEndType = .never

        if isRepeating {
            let ruleEndDate: Date?
            let ruleOccurrenceCount: Int?

            switch endType {
            case .never:
                ruleEndDate = nil
                ruleOccurrenceCount = nil
            case .untilDate:
                ruleEndDate = endDate
                ruleOccurrenceCount = nil
            case .afterCount:
                ruleEndDate = nil
                ruleOccurrenceCount = occurrenceCount
            }

            resolvedEndType = endType

            recurrence = RecurrenceRule(
                frequency: frequency,
                interval: interval,
                endDate: ruleEndDate,
                occurrenceCount: ruleOccurrenceCount
            )

            if frequency == .weekly {
                weekdaySelection = selectedWeekdays
            }

            if frequency == .monthly, let firstDay = selectedMonthDays.sorted().first {
                var calendar = Calendar.current
                calendar.timeZone = TimeZone.current
                var components = calendar.dateComponents([.year, .month, .hour, .minute], from: adjustedFireDate)
                components.day = firstDay
                if let newDate = calendar.date(from: components) {
                    adjustedFireDate = newDate
                }
            }
        } else {
            recurrence = nil
        }

        viewModel.setScheduleConfig(
            fireDate: adjustedFireDate,
            recurrence: recurrence,
            weekdaySelection: weekdaySelection,
            referenceTime: adjustedFireDate,
            isAllDay: timeOfDayType == .allDay,
            endType: resolvedEndType
        )
        dismiss()
    }

    private func removeConfig() {
        viewModel.removeScheduleConfig()
        dismiss()
    }

    // MARK: - Helper Methods

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
}

// MARK: - Month Day Selection View

struct MonthDaySelectionView: View {
    @Binding var selectedDays: Set<Int>
    private let columns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(1...31, id: \.self) { day in
                    let isSelected = selectedDays.contains(day)
                    Button {
                        toggle(day)
                    } label: {
                        Text("\(day)")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(isSelected ? Color.Theme.accentForeground : .primary)
                            .frame(width: 36, height: 36)
                            .background(isSelected ? Color.accentColor : Color.Theme.elementBackground)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Day \(day)")
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                }
            }

            Text(summaryText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var summaryText: String {
        if selectedDays.isEmpty {
            return "No days selected."
        }
        let sortedDays = selectedDays.sorted()
        if sortedDays.count <= 5 {
            return "Day \(sortedDays.map(String.init).joined(separator: ", "))"
        } else {
            return "\(sortedDays.count) days selected"
        }
    }

    private func toggle(_ day: Int) {
        if selectedDays.contains(day) {
            selectedDays.remove(day)
        } else {
            selectedDays.insert(day)
        }
    }
}
