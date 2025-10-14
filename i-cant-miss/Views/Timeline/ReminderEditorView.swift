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
    @State private var showTimeTriggerSheet = false
    @State private var showWeekdayTriggerSheet = false
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

                // Time Trigger Section
                Section {
                    TimeTriggerInlineForm(viewModel: viewModel, showSheet: $showTimeTriggerSheet)
                } header: {
                    Label("Time", systemImage: "clock")
                }

                // Weekday Trigger Section
                Section {
                    WeekdayTriggerInlineForm(viewModel: viewModel, showSheet: $showWeekdayTriggerSheet)
                } header: {
                    Label("Weekdays", systemImage: "calendar")
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

                if let important = viewModel.importantDate {
                    Section("Important Date") {
                        Text(important.title)
                        Text("Occurs on \(important.date.formatted(date: .long, time: .omitted))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        ForEach(important.leadTimes) { lead in
                            Text("Notify \(lead.offset.formattedLeadTime)")
                                .font(.caption)
                        }
                        Button(role: .destructive) {
                            viewModel.importantDate = nil
                        } label: {
                            Label("Remove important date", systemImage: "trash")
                        }
                    }
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
            .sheet(isPresented: $showTimeTriggerSheet) {
                TimeTriggerSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showWeekdayTriggerSheet) {
                WeekdayTriggerSheet(viewModel: viewModel)
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

private struct TimeTriggerInlineForm: View {
    @ObservedObject var viewModel: ReminderEditorViewModel
    @Binding var showSheet: Bool

    private var existingTrigger: ReminderTriggerDraft? {
        viewModel.triggers.first(where: { $0.type == .time })
    }

    var body: some View {
        if let trigger = existingTrigger {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let fireDate = trigger.fireDate {
                        Text(fireDate.formatted(date: .abbreviated, time: .shortened))
                            .font(.body)
                            .foregroundStyle(.primary)
                        if let recurrence = trigger.recurrenceRule {
                            Text("Repeats \(recurrence.frequency.title.lowercased())")
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
                Label("Add time trigger", systemImage: "plus.circle.fill")
                Spacer()
            }
            .foregroundStyle(.accent)
            .formRowButton { showSheet = true }
        }
    }
}

private struct WeekdayTriggerInlineForm: View {
    @ObservedObject var viewModel: ReminderEditorViewModel
    @Binding var showSheet: Bool

    private var existingTrigger: ReminderTriggerDraft? {
        viewModel.triggers.first(where: { $0.type == .dayOfWeek })
    }

    var body: some View {
        if let trigger = existingTrigger {
            HStack {
                Text(selectedDaysText(mask: trigger.weekdayMask))
                    .font(.body)
                    .foregroundStyle(.primary)
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
                Label("Add weekday trigger", systemImage: "plus.circle.fill")
                Spacer()
            }
            .foregroundStyle(.accent)
            .formRowButton { showSheet = true }
        }
    }

    private func selectedDaysText(mask: Int16) -> String {
        if mask == 0 {
            return "No days selected"
        }
        let formatter = DateFormatter()
        let days = (1...7).compactMap { day -> String? in
            let bit = Int16(1 << day)
            guard (mask & bit) != 0 else { return nil }
            return formatter.shortWeekdaySymbols[(day - 1) % formatter.shortWeekdaySymbols.count]
        }
        return days.isEmpty ? "No days selected" : days.joined(separator: ", ")
    }
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

private extension TimeInterval {
    var formattedLeadTime: String {
        let minutes = self / 60
        if minutes >= 1440 {
            let days = Int(minutes / 1440)
            return "\(days) day\(days == 1 ? "" : "s") before"
        } else if minutes >= 60 {
            let hours = Int(minutes / 60)
            return "\(hours) hour\(hours == 1 ? "" : "s") before"
        } else {
            let mins = Int(minutes)
            return "\(mins) minute\(mins == 1 ? "" : "s") before"
        }
    }
}

private extension RecurrenceRule.Frequency {
    var title: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        }
    }
}

// MARK: - Trigger Sheets

private struct TimeTriggerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ReminderEditorViewModel
    @State private var date: Date
    @State private var selectedFrequency: RecurrenceRule.Frequency?
    @State private var repeatInterval: Int

    private var existingTrigger: ReminderTriggerDraft? {
        viewModel.triggers.first(where: { $0.type == .time })
    }

    init(viewModel: ReminderEditorViewModel) {
        self.viewModel = viewModel
        let trigger = viewModel.triggers.first(where: { $0.type == .time })
        _date = State(initialValue: trigger?.fireDate ?? Date().addingTimeInterval(3600))
        _selectedFrequency = State(initialValue: trigger?.recurrenceRule?.frequency)
        _repeatInterval = State(initialValue: trigger?.recurrenceRule?.interval ?? 1)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date", selection: $date, displayedComponents: [.date])
                    DatePicker("Time", selection: $date, displayedComponents: [.hourAndMinute])
                }

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
            .navigationTitle(existingTrigger == nil ? "Add Time Trigger" : "Edit Time Trigger")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(existingTrigger == nil ? "Add" : "Save") {
                        let recurrence = selectedFrequency.map {
                            RecurrenceRule(frequency: $0, interval: repeatInterval)
                        }

                        if let trigger = existingTrigger {
                            var updated = trigger
                            updated.fireDate = date
                            updated.recurrenceRule = recurrence
                            viewModel.updateTrigger(id: trigger.id, with: updated)
                        } else {
                            viewModel.addTimeTrigger(date: date, recurrence: recurrence)
                        }
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct WeekdayTriggerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ReminderEditorViewModel
    @State private var selectedDays: Set<Int>

    private var existingTrigger: ReminderTriggerDraft? {
        viewModel.triggers.first(where: { $0.type == .dayOfWeek })
    }

    init(viewModel: ReminderEditorViewModel) {
        self.viewModel = viewModel
        let trigger = viewModel.triggers.first(where: { $0.type == .dayOfWeek })

        var initialDays = Set<Int>()
        if let mask = trigger?.weekdayMask {
            for day in 1...7 {
                let bit = Int16(1 << day)
                if (mask & bit) != 0 {
                    initialDays.insert(day)
                }
            }
        }
        _selectedDays = State(initialValue: initialDays)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(1...7, id: \.self) { day in
                        Button {
                            if selectedDays.contains(day) {
                                selectedDays.remove(day)
                            } else {
                                selectedDays.insert(day)
                            }
                        } label: {
                            HStack {
                                Text(weekdayName(for: day))
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedDays.contains(day) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.blue)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundStyle(.gray)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(existingTrigger == nil ? "Add Weekday Trigger" : "Edit Weekday Trigger")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(existingTrigger == nil ? "Add" : "Save") {
                        let mask = selectedDays.reduce(into: Int16(0)) { partialResult, day in
                            partialResult |= Int16(1 << day)
                        }

                        if let trigger = existingTrigger {
                            var updated = trigger
                            updated.weekdayMask = mask
                            viewModel.updateTrigger(id: trigger.id, with: updated)
                        } else {
                            viewModel.addWeekdayTrigger(selectedWeekdays: Array(selectedDays))
                        }
                        dismiss()
                    }
                }
            }
        }
    }

    private func weekdayName(for day: Int) -> String {
        let formatter = DateFormatter()
        return formatter.weekdaySymbols[(day - 1) % formatter.weekdaySymbols.count]
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
