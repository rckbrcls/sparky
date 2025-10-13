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
    @State private var creationType: TriggerCreationType?
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

                Section(header: triggerHeader) {
                    if viewModel.triggers.isEmpty {
                        Text("Add at least one trigger to activate this reminder.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.triggers, id: \.id) { trigger in
                            TriggerDraftRow(draft: trigger) {
                                viewModel.removeTrigger(id: trigger.id)
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                let trigger = viewModel.triggers[index]
                                viewModel.removeTrigger(id: trigger.id)
                            }
                        }
                    }

                    Button(action: { creationType = .choose }) {
                        Label("Add Trigger", systemImage: "plus.circle")
                    }
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
            }
            .alert("Could not save", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { _ in viewModel.errorMessage = nil }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .sheet(item: $creationType, content: { type in
                switch type {
                case .choose:
                    TriggerChooserView { selection in
                        creationType = selection
                    }
                case .time:
                    TimeTriggerForm { date, recurrence in
                        viewModel.addTimeTrigger(date: date, recurrence: recurrence)
                        creationType = nil
                    }
                case .weekday:
                    WeekdayTriggerForm { weekdays in
                        viewModel.addWeekdayTrigger(selectedWeekdays: weekdays)
                        creationType = nil
                    }
                case .location:
                    LocationPickerView { name, latitude, longitude, radius, event in
                        viewModel.addLocationTrigger(name: name,
                                                     latitude: latitude,
                                                     longitude: longitude,
                                                     radius: radius,
                                                     event: event)
                        creationType = nil
                    }
                case .person:
                    PersonTriggerForm { name, identifier in
                        viewModel.addPersonTrigger(name: name, identifier: identifier)
                        creationType = nil
                    }
                }
            })
        }
    }

    private var triggerHeader: some View {
        HStack {
            Text("Triggers")
            Spacer()
            Text("\(viewModel.triggers.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
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
}

private func viewModelTitle(for viewModel: ReminderEditorViewModel) -> String {
    viewModel.title.isEmpty ? "New Reminder" : "Edit Reminder"
}

private struct TriggerDraftRow: View {
    let draft: ReminderTriggerDraft
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(draft.type.label, systemImage: draft.type.systemImage)
                    .font(.subheadline)
                Spacer()
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var description: String {
        switch draft.type {
        case .time:
            if let fireDate = draft.fireDate {
                return "Fires on \(fireDate.formatted(date: .abbreviated, time: .shortened))"
            }
            return "Specific date and time"
        case .dayOfWeek:
            if draft.weekdayMask == 0 {
                return "Every day"
            }
            let formatter = DateFormatter()
            let days = (1...7).compactMap { day -> String? in
                let bit = 1 << day
                guard (draft.weekdayMask & Int16(bit)) != 0 else { return nil }
                return formatter.shortWeekdaySymbols[(day - 1) % formatter.shortWeekdaySymbols.count]
            }
            return "Repeats on \(days.joined(separator: ", "))"
        case .location:
            let name = draft.location?.name ?? "Unknown location"
            let radius = Int(draft.location?.radius ?? 0)
            let event = draft.location?.event.label ?? "Entry"
            return "\(name) • \(radius)m • \(event)"
        case .person:
            return draft.person?.name ?? "Person trigger"
        case .importantDate:
            return "Important date trigger"
        }
    }
}

private enum TriggerCreationType: Identifiable {
    case choose
    case time
    case weekday
    case location
    case person

    var id: Int {
        switch self {
        case .choose: return 0
        case .time: return 1
        case .weekday: return 2
        case .location: return 3
        case .person: return 4
        }
    }
}

private struct TriggerChooserView: View {
    let onSelect: (TriggerCreationType) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Choose trigger type") {
                    triggerButton(title: "Time", systemImage: "clock", type: .time)
                    triggerButton(title: "Day of week", systemImage: "calendar", type: .weekday)
                    triggerButton(title: "Location", systemImage: "mappin.and.ellipse", type: .location)
                    triggerButton(title: "Person", systemImage: "person.crop.circle", type: .person)
                }
            }
            .navigationTitle("Add Trigger")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
            }
        }
    }

    private func triggerButton(title: String, systemImage: String, type: TriggerCreationType) -> some View {
        Button {
            dismiss()
            onSelect(type)
        } label: {
            Label(title, systemImage: systemImage)
        }
    }
}

private struct TimeTriggerForm: View {
    @Environment(\.dismiss) private var dismiss
    @State private var date: Date = Date().addingTimeInterval(3600)
    @State private var selectedFrequency: RecurrenceRule.Frequency? = nil
    @State private var repeatInterval: Int = 1
    let onAdd: (Date, RecurrenceRule?) -> Void

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Fire date", selection: $date, displayedComponents: [.date, .hourAndMinute])

                Section("Repeats") {
                    Picker("Frequency", selection: $selectedFrequency) {
                        Text("None").tag(nil as RecurrenceRule.Frequency?)
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
            .navigationTitle("Time Trigger")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        let recurrence = selectedFrequency.map {
                            RecurrenceRule(frequency: $0, interval: repeatInterval)
                        }
                        onAdd(date, recurrence)
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct WeekdayTriggerForm: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selections: Set<Int> = []
    let onAdd: ([Int]) -> Void

    var body: some View {
        NavigationStack {
            Form {
                ForEach(1...7, id: \.self) { day in
                    Button {
                        if selections.contains(day) {
                            selections.remove(day)
                        } else {
                            selections.insert(day)
                        }
                    } label: {
                        HStack {
                            Text(weekdayName(for: day))
                            Spacer()
                            if selections.contains(day) {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Days of Week")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        onAdd(Array(selections))
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

private struct PersonTriggerForm: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var identifier: String = ""
    @State private var showContactPicker = false
    @State private var showAccessDeniedAlert = false
    let onAdd: (String, String?) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Contact") {
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

                    if !identifier.isEmpty {
                        HStack {
                            Text("Contact ID")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(identifier)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    Text("You can manually enter a name or select a contact from your iPhone contacts.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Person Trigger")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        onAdd(name, identifier.isEmpty ? nil : identifier)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showContactPicker) {
                ContactPickerView { contactName, contactId in
                    name = contactName
                    identifier = contactId ?? ""
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

#Preview {
    let environment = AppEnvironment(persistence: PersistenceController.preview)
    environment.bootstrap()
    return ReminderEditorView(environment: environment, existingReminder: nil)
}
