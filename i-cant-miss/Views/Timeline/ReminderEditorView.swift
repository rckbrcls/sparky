//
//  ReminderEditorView.swift
//  i-cant-miss
//
//  Created by Codex on 13/10/25.
//

import SwiftUI
import Contacts

struct ReminderEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ReminderEditorViewModel
    @State private var showContactPicker = false
    @State private var showAccessDeniedAlert = false
    @State private var showLocationPicker = false
    @State private var showScheduleTriggerSheet = false
    @State private var showPersonTriggerSheet = false
    let environment: AppEnvironment

    init(environment: AppEnvironment, existingReminder: ReminderModel?) {
        self.environment = environment
        _viewModel = StateObject(wrappedValue: ReminderEditorViewModel(environment: environment, reminder: existingReminder))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Title", text: $viewModel.title)
                    TextEditor(text: $viewModel.notes)
                        .frame(minHeight: 120)

                    Picker("Priority", selection: $viewModel.priority) {
                        ForEach(ReminderPriority.allCases) { priority in
                            HStack {
                                Image(systemName: priority.iconName)
                                Text(priorityLabel(for: priority))
                            }
                            .tag(priority)
                        }
                    }

                    Picker("Status", selection: $viewModel.status) {
                        ForEach(ReminderStatus.allCases) { status in
                            Text(statusLabel(for: status)).tag(status)
                        }
                    }
                }

                // Schedule Trigger Section
                Section {
                    ScheduleTriggerInlineForm(viewModel: viewModel, showSheet: $showScheduleTriggerSheet)
                } header: {
                    Label("Schedule", systemImage: "calendar.badge.clock")
                }

                // Location Trigger Section
                Section {
                    LocationTriggerInlineForm(viewModel: viewModel, showLocationPicker: $showLocationPicker)
                } header: {
                    Label("Location", systemImage: "mappin.and.ellipse")
                }

                // Person Trigger Section
                Section {
                    PersonTriggerInlineForm(
                        viewModel: viewModel,
                        showSheet: $showPersonTriggerSheet
                    )
                } header: {
                    Label("Person", systemImage: "person.crop.circle")
                }
            }
            .onAppear {
                viewModel.loadData()
            }
            .navigationTitle(navigationTitleText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            let success = await viewModel.save()
                            if success { dismiss() }
                        }
                    } label: {
                        if viewModel.isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(viewModel.isSaving)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { hideKeyboard() }
                }
            }
            .alert("Could not save", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { _ in viewModel.errorMessage = nil }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .sheet(isPresented: $showContactPicker) {
                ContactPickerView { contactName, contactId in
                    if let trigger = viewModel.triggers.first(where: { $0.type == .person }) {
                        var updated = trigger
                        updated.person = .init(name: contactName, contactIdentifier: contactId)
                        viewModel.updateTrigger(id: trigger.id, with: updated)
                    } else {
                        viewModel.addPersonTrigger(name: contactName, identifier: contactId)
                    }
                    showContactPicker = false
                }
            }
            .sheet(isPresented: $showLocationPicker) {
                LocationPickerView { name, latitude, longitude, radius, event in
                    if let trigger = viewModel.triggers.first(where: { $0.type == .location }) {
                        var updated = trigger
                        updated.location = .init(
                            latitude: latitude,
                            longitude: longitude,
                            radius: radius,
                            name: name,
                            event: event
                        )
                        viewModel.updateTrigger(id: trigger.id, with: updated)
                    } else {
                        viewModel.addLocationTrigger(name: name,
                                                     latitude: latitude,
                                                     longitude: longitude,
                                                     radius: radius,
                                                     event: event)
                    }
                    showLocationPicker = false
                }
            }
            .alert("Contacts Access Required", isPresented: $showAccessDeniedAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            } message: {
                Text("Please allow access to contacts in Settings to select a person from your contacts.")
            }
            .sheet(isPresented: $showScheduleTriggerSheet) {
                ScheduleTriggerSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showPersonTriggerSheet) {
                PersonTriggerSheet(
                    viewModel: viewModel,
                    showContactPicker: $showContactPicker,
                    showAccessDeniedAlert: $showAccessDeniedAlert
                )
            }
        }
    }

    private var navigationTitleText: String {
        viewModelTitle(for: viewModel)
    }

    private func priorityLabel(for priority: ReminderPriority) -> String {
        switch priority {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }

    private func statusLabel(for status: ReminderStatus) -> String {
        switch status {
        case .active: return "Active"
        case .completed: return "Completed"
        case .overdue: return "Overdue"
        case .archived: return "Archived"
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

private func viewModelTitle(for viewModel: ReminderEditorViewModel) -> String {
    viewModel.title.isEmpty ? "New Reminder" : "Edit Reminder"
}

private extension View {
    func formRowButton(action: @escaping () -> Void) -> some View {
        self
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(.default, action)
    }
}

// MARK: - Inline Trigger Forms

private struct ScheduleTriggerInlineForm: View {
    @ObservedObject var viewModel: ReminderEditorViewModel
    @Binding var showSheet: Bool

    private var timeTrigger: ReminderTriggerDraft? {
        viewModel.triggers.first(where: { $0.type == .time })
    }

    private var weekdayTrigger: ReminderTriggerDraft? {
        viewModel.triggers.first(where: { $0.type == .dayOfWeek })
    }

    private var hasSchedule: Bool {
        timeTrigger != nil || weekdayTrigger != nil
    }

    var body: some View {
        if hasSchedule {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(schedulePrimaryText)
                        .font(.body)
                        .foregroundStyle(.primary)
                    if let detail = scheduleDetailText {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .formRowButton { showSheet = true }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    viewModel.clearScheduleTriggers()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        } else {
            HStack {
                Label("Add schedule", systemImage: "plus.circle.fill")
                Spacer()
            }
            .foregroundStyle(.accent)
            .formRowButton { showSheet = true }
        }
    }

    private var schedulePrimaryText: String {
        if let date = timeTrigger?.fireDate ?? weekdayTrigger?.fireDate {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
        if let mask = weekdayTrigger?.weekdayMask, mask != 0 {
            return weekdayMaskSummary(mask: mask)
        }
        return "Custom schedule"
    }

    private var scheduleDetailText: String? {
        var parts: [String] = []

        if let recurrence = timeTrigger?.recurrenceRule {
            var text = "Repeats \(recurrence.frequency.title.lowercased())"
            if recurrence.interval > 1 {
                text += " every \(recurrence.interval)"
            }
            parts.append(text)
        }

        if let mask = weekdayTrigger?.weekdayMask,
           mask != 0,
           timeTrigger?.fireDate != nil {
            parts.append(weekdayMaskSummary(mask: mask))
        }

        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }
}

private func weekdayMaskSummary(mask: Int16) -> String {
    guard mask != 0 else { return "No days selected" }
    let formatter = DateFormatter()
    let symbols = formatter.shortWeekdaySymbols ?? []
    guard !symbols.isEmpty else { return "No days selected" }
    let days = (1...7).compactMap { day -> String? in
        let bit = Int16(1 << day)
        guard mask & bit != 0 else { return nil }
        return symbols[(day - 1) % symbols.count]
    }
    return days.isEmpty ? "No days selected" : days.joined(separator: ", ")
}

private struct LocationTriggerInlineForm: View {
    @ObservedObject var viewModel: ReminderEditorViewModel
    @Binding var showLocationPicker: Bool

    private var existingTrigger: ReminderTriggerDraft? {
        viewModel.triggers.first(where: { $0.type == .location })
    }

    var body: some View {
        if let trigger = existingTrigger, let location = trigger.location {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(location.name ?? "Unknown")
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text("\(Int(location.radius))m • \(location.event.label)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .formRowButton { showLocationPicker = true }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    viewModel.removeTrigger(id: trigger.id)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        } else {
            HStack {
                Label("Add location trigger", systemImage: "plus.circle.fill")
                Spacer()
            }
            .foregroundStyle(.accent)
            .formRowButton { showLocationPicker = true }
        }
    }
}

private struct PersonTriggerInlineForm: View {
    @ObservedObject var viewModel: ReminderEditorViewModel
    @Binding var showSheet: Bool

    private var existingTrigger: ReminderTriggerDraft? {
        viewModel.triggers.first(where: { $0.type == .person })
    }

    var body: some View {
        if let trigger = existingTrigger {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trigger.person?.name ?? "No name")
                        .font(.body)
                        .foregroundStyle(.primary)
                    if let contactId = trigger.person?.contactIdentifier, !contactId.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                            Text("Contact linked")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .formRowButton { showSheet = true }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    viewModel.removeTrigger(id: trigger.id)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        } else {
            HStack {
                Label("Add person trigger", systemImage: "plus.circle.fill")
                Spacer()
            }
            .foregroundStyle(.accent)
            .formRowButton { showSheet = true }
        }
    }
}

// MARK: - Trigger Sheets

private struct ScheduleTriggerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ReminderEditorViewModel
    @State private var date: Date
    @State private var selectedFrequency: RecurrenceRule.Frequency?
    @State private var repeatInterval: Int
    @State private var selectedWeekdays: Set<Int>
    @State private var includeTimeTrigger: Bool

    private var timeTrigger: ReminderTriggerDraft? {
        viewModel.triggers.first(where: { $0.type == .time })
    }

    private var weekdayTrigger: ReminderTriggerDraft? {
        viewModel.triggers.first(where: { $0.type == .dayOfWeek })
    }

    private var hasExistingSchedule: Bool {
        timeTrigger != nil || weekdayTrigger != nil
    }

    init(viewModel: ReminderEditorViewModel) {
        self.viewModel = viewModel
        let time = viewModel.triggers.first(where: { $0.type == .time })
        let weekday = viewModel.triggers.first(where: { $0.type == .dayOfWeek })

        let defaultDate = time?.fireDate ?? weekday?.fireDate ?? Date().addingTimeInterval(3600)
        _date = State(initialValue: defaultDate)
        _selectedFrequency = State(initialValue: time?.recurrenceRule?.frequency)
        _repeatInterval = State(initialValue: time?.recurrenceRule?.interval ?? 1)
        _includeTimeTrigger = State(initialValue: time != nil)

        var initialDays = Set<Int>()
        if let mask = weekday?.weekdayMask {
            for day in 1...7 {
                let bit = Int16(1 << day)
                if mask & bit != 0 {
                    initialDays.insert(day)
                }
            }
        }
        _selectedWeekdays = State(initialValue: initialDays)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Time") {
                    Toggle("Specific date & time", isOn: $includeTimeTrigger.animation())
                    if includeTimeTrigger {
                        DatePicker("Date", selection: $date, displayedComponents: [.date])
                    }
                    DatePicker(includeTimeTrigger ? "Time" : "Weekday time",
                               selection: $date,
                               displayedComponents: [.hourAndMinute])
                }

                if includeTimeTrigger {
                    Section("Repeat") {
                        Picker("Frequency", selection: $selectedFrequency) {
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

                Section("Weekdays") {
                    WeekdaySelectionView(selectedDays: $selectedWeekdays)
                }

                if hasExistingSchedule {
                    Section {
                        Button("Remove schedule", role: .destructive) {
                            viewModel.clearScheduleTriggers()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(hasExistingSchedule ? "Edit Schedule" : "Add Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(hasExistingSchedule ? "Save" : "Add") {
                        saveChanges()
                    }
                    .disabled(!includeTimeTrigger && selectedWeekdays.isEmpty)
                }
            }
        }
    }

    private func saveChanges() {
        let recurrence = includeTimeTrigger ? selectedFrequency.map { RecurrenceRule(frequency: $0, interval: repeatInterval) } : nil
        viewModel.updateSchedule(
            fireDate: includeTimeTrigger ? date : nil,
            recurrence: recurrence,
            weekdaySelection: selectedWeekdays,
            weekdayReferenceTime: date
        )
        dismiss()
    }
}

private struct WeekdaySelectionView: View {
    @Binding var selectedDays: Set<Int>

    private let columns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(1...7, id: \.self) { day in
                    let isSelected = selectedDays.contains(day)
                    Button {
                        toggle(day)
                    } label: {
                        Text(symbol(for: day))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(isSelected ? Color.accentColor.opacity(0.15) : Color(.systemFill))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                            )
                            .foregroundStyle(isSelected ? .accent : .primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(fullName(for: day))
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
            return "No weekdays selected."
        }
        let mask = selectedDays.reduce(into: Int16(0)) { partialResult, day in
            partialResult |= Int16(1 << day)
        }
        return weekdayMaskSummary(mask: mask)
    }

    private func toggle(_ day: Int) {
        if selectedDays.contains(day) {
            selectedDays.remove(day)
        } else {
            selectedDays.insert(day)
        }
    }

    private func symbol(for day: Int) -> String {
        let formatter = DateFormatter()
        let symbols = formatter.veryShortWeekdaySymbols ?? []
        guard !symbols.isEmpty else { return "" }
        return symbols[(day - 1) % symbols.count]
    }

    private func fullName(for day: Int) -> String {
        let formatter = DateFormatter()
        let symbols = formatter.weekdaySymbols ?? []
        guard !symbols.isEmpty else { return "" }
        return symbols[(day - 1) % symbols.count]
    }
}

private struct PersonTriggerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ReminderEditorViewModel
    @Binding var showContactPicker: Bool
    @Binding var showAccessDeniedAlert: Bool
    @State private var name: String
    @State private var contactIdentifier: String

    private var existingTrigger: ReminderTriggerDraft? {
        viewModel.triggers.first(where: { $0.type == .person })
    }

    init(viewModel: ReminderEditorViewModel, showContactPicker: Binding<Bool>, showAccessDeniedAlert: Binding<Bool>) {
        self.viewModel = viewModel
        self._showContactPicker = showContactPicker
        self._showAccessDeniedAlert = showAccessDeniedAlert

        let trigger = viewModel.triggers.first(where: { $0.type == .person })
        _name = State(initialValue: trigger?.person?.name ?? "")
        _contactIdentifier = State(initialValue: trigger?.person?.contactIdentifier ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Contact Information") {
                    HStack {
                        TextField("Name", text: $name)

                        Button(action: {
                            Task {
                                await requestContactsAndShow()
                            }
                        }) {
                            Image(systemName: "person.crop.circle.badge.plus")
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.borderless)
                    }

                    if !contactIdentifier.isEmpty {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Contact linked")
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                    }
                }

                Section {
                    Text("You can manually enter a name or select a contact from your contacts.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(existingTrigger == nil ? "Add Person Trigger" : "Edit Person Trigger")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(existingTrigger == nil ? "Add" : "Save") {
                        if let trigger = existingTrigger {
                            var updated = trigger
                            updated.person = .init(
                                name: name,
                                contactIdentifier: contactIdentifier.isEmpty ? nil : contactIdentifier
                            )
                            viewModel.updateTrigger(id: trigger.id, with: updated)
                        } else {
                            viewModel.addPersonTrigger(
                                name: name,
                                identifier: contactIdentifier.isEmpty ? nil : contactIdentifier
                            )
                        }
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showContactPicker) {
                ContactPickerView { contactName, contactId in
                    name = contactName
                    contactIdentifier = contactId ?? ""
                    showContactPicker = false
                }
            }
            .alert("Contacts Access Required", isPresented: $showAccessDeniedAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            } message: {
                Text("Please allow access to contacts in Settings to select a person from your contacts.")
            }
        }
    }

    private func requestContactsAndShow() async {
        let status = ContactAccessHelper.checkAuthorizationStatus()

        switch status {
        case .authorized:
            showContactPicker = true
        case .notDetermined:
            let granted = await ContactAccessHelper.requestAccess()
            if granted {
                showContactPicker = true
            } else {
                showAccessDeniedAlert = true
            }
        case .denied, .restricted:
            showAccessDeniedAlert = true
        case .limited:
            showContactPicker = true
        @unknown default:
            showAccessDeniedAlert = true
        }
    }
}

#Preview {
    let environment = AppEnvironment(persistence: PersistenceController.preview)
    environment.bootstrap()
    return ReminderEditorView(environment: environment, existingReminder: nil)
}
