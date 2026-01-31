import SwiftUI

// MARK: - Main View

struct ScheduledTriggerEditorScreen: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: MemoryEditorViewModel
    private let showsCloseButton: Bool

    // State
    @State private var fireDate: Date
    @State private var timeOfDayType: TimeOfDayType
    @State private var repeatType: ScheduleRepeatType
    @State private var showCustomRepeatSheet: Bool = false

    // Custom repeat state
    @State private var customRepeatType: CustomRepeatType = .weekly
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

        // Detect time of day type from isAllDay flag
        let detectedTimeOfDay: TimeOfDayType = scheduleConfig?.isAllDay == true ? .allDay : .specificTime
        _timeOfDayType = State(initialValue: detectedTimeOfDay)

        // Detect repeat type from existing config
        let detectedRepeatType = Self.detectRepeatType(from: scheduleConfig)
        _repeatType = State(initialValue: detectedRepeatType)

        // Initialize weekday selection
        let initialWeekdays = Self.weekdaySet(from: scheduleConfig?.weekdayMask ?? 0)
        _selectedWeekdays = State(initialValue: initialWeekdays)

        // Initialize month day selection
        _selectedMonthDays = State(initialValue: [])

        // Set custom repeat type based on existing data
        if !initialWeekdays.isEmpty {
            _customRepeatType = State(initialValue: .weekly)
        } else {
            _customRepeatType = State(initialValue: .weekly)
        }
    }

    var body: some View {
        Form {
            Section {
                // Time of Day
                Picker("Time of Day", selection: $timeOfDayType) {
                    ForEach(TimeOfDayType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }

                // Date & Time (depends on time of day type)
                if timeOfDayType == .specificTime {
                    DatePicker("Date & Time", selection: $fireDate, displayedComponents: [.date, .hourAndMinute])
                } else {
                    DatePicker("Date", selection: $fireDate, displayedComponents: [.date])
                }

                // Repeat
                Picker("Repeat", selection: $repeatType) {
                    ForEach(ScheduleRepeatType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .onChange(of: repeatType) { _, newValue in
                    if newValue == .custom {
                        showCustomRepeatSheet = true
                    }
                }

                // Show custom repeat summary if custom is selected
                if repeatType == .custom {
                    Button {
                        showCustomRepeatSheet = true
                    } label: {
                        HStack {
                            Text(customRepeatSummary)
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
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
        .sheet(isPresented: $showCustomRepeatSheet) {
            CustomRepeatSheet(
                customRepeatType: $customRepeatType,
                selectedWeekdays: $selectedWeekdays,
                selectedMonthDays: $selectedMonthDays
            )
        }
    }

    // MARK: - Validation

    private var isValid: Bool {
        if repeatType == .custom {
            switch customRepeatType {
            case .weekly:
                return !selectedWeekdays.isEmpty
            case .monthly:
                return !selectedMonthDays.isEmpty
            }
        }
        return true
    }


    private var customRepeatSummary: String {
        switch customRepeatType {
        case .weekly:
            if selectedWeekdays.isEmpty {
                return "Select weekdays"
            }
            let mask = selectedWeekdays.reduce(into: Int16(0)) { result, day in
                result |= Int16(1 << day)
            }
            return weekdayMaskSummary(mask: mask)
        case .monthly:
            if selectedMonthDays.isEmpty {
                return "Select days of month"
            }
            let sortedDays = selectedMonthDays.sorted()
            if sortedDays.count <= 3 {
                return "Day \(sortedDays.map(String.init).joined(separator: ", "))"
            } else {
                return "\(sortedDays.count) days of month"
            }
        }
    }

    // MARK: - Actions

    private func applyChanges() {
        guard isValid else { return }

        // Adjust fireDate based on time of day type
        var adjustedFireDate = fireDate
        if timeOfDayType == .allDay {
            // Set time to start of day for all-day events
            let calendar = Calendar.current
            adjustedFireDate = calendar.startOfDay(for: fireDate)
        }

        let recurrence: RecurrenceRule?
        var weekdaySelection: Set<Int> = []

        switch repeatType {
        case .never:
            recurrence = nil
        case .daily:
            recurrence = RecurrenceRule(frequency: .daily, interval: 1)
        case .weekly:
            recurrence = RecurrenceRule(frequency: .weekly, interval: 1)
        case .yearly:
            recurrence = RecurrenceRule(frequency: .yearly, interval: 1)
        case .custom:
            switch customRepeatType {
            case .weekly:
                recurrence = RecurrenceRule(frequency: .weekly, interval: 1)
                weekdaySelection = selectedWeekdays
            case .monthly:
                // For monthly, we store the day selection in a different way
                // Using the fire date's day as the monthly recurrence day
                recurrence = RecurrenceRule(frequency: .monthly, interval: 1)
                // Note: For multiple days per month, this would need model changes
                // For now, we'll use the first selected day
                if let firstDay = selectedMonthDays.sorted().first {
                    var calendar = Calendar.current
                    calendar.timeZone = TimeZone.current
                    var components = calendar.dateComponents([.year, .month, .hour, .minute], from: adjustedFireDate)
                    components.day = firstDay
                    if let newDate = calendar.date(from: components) {
                        adjustedFireDate = newDate
                    }
                }
            }
        }

        viewModel.setScheduleConfig(
            fireDate: adjustedFireDate,
            recurrence: recurrence,
            weekdaySelection: weekdaySelection,
            referenceTime: adjustedFireDate,
            isAllDay: timeOfDayType == .allDay
        )
        dismiss()
    }

    private func removeConfig() {
        viewModel.removeScheduleConfig()
        dismiss()
    }

    // MARK: - Helper Methods

    private static func detectRepeatType(from config: ScheduleConfigDraft?) -> ScheduleRepeatType {
        guard let config = config, let recurrence = config.recurrenceRule else {
            return .never
        }

        // Check if it's a custom repeat (has weekday selection)
        if config.weekdayMask != 0 {
            return .custom
        }

        switch recurrence.frequency {
        case .daily:
            return .daily
        case .weekly:
            return .weekly
        case .yearly:
            return .yearly
        case .monthly:
            return .custom
        default:
            return .never
        }
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
}

// MARK: - Custom Repeat Sheet

struct CustomRepeatSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var customRepeatType: CustomRepeatType
    @Binding var selectedWeekdays: Set<Int>
    @Binding var selectedMonthDays: Set<Int>

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Repeat Every", selection: $customRepeatType) {
                        ForEach(CustomRepeatType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    if customRepeatType == .weekly {
                        MemoryWeekdaySelectionView(selectedDays: $selectedWeekdays)
                    } else {
                        MonthDaySelectionView(selectedDays: $selectedMonthDays)
                    }
                }
            }
            .navigationTitle("Custom Repeat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
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
                            .foregroundStyle(isSelected ? Color(.systemBackground) : .primary)
                            .frame(width: 36, height: 36)
                            .background(isSelected ? Color.accentColor : Color(.tertiarySystemFill))
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
