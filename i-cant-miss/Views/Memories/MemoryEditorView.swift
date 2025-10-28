//
//  MemoryEditorView.swift
//  i-cant-miss
//
//  Created by Codex on 09/03/24.
//

import SwiftUI
import Contacts

struct MemoryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: MemoryEditorViewModel
    @State private var showScheduleSheet = false
    @State private var showLocationPicker = false
    @State private var showPersonSheet = false
    @State private var showContactPicker = false
    @State private var showAccessDeniedAlert = false
    @State private var checklistDraftRows: [ChecklistDraftRow] = [ChecklistDraftRow()]
    @FocusState private var focusedDraftID: UUID?
    private let isEditing: Bool
    
    init(environment: AppEnvironment,
         memory: MemoryModel? = nil,
         defaultSpace: SpaceModel? = nil,
         template: MemoryEditorTemplate = .blank) {
        _viewModel = StateObject(wrappedValue: MemoryEditorViewModel(
            environment: environment,
            memory: memory,
            defaultSpace: defaultSpace,
            template: template
        ))
        self.isEditing = memory != nil
    }
    
    var body: some View {
        NavigationStack {
            Form {
                detailsSection
                tagsSection
                bodySection
                checklistSection
                triggersSection
                dueDateSection
                extrasSection
            }
            .scrollContentBackground(.hidden)
            .onAppear {
                viewModel.loadLatestDataIfNeeded()
                DispatchQueue.main.async {
                    focusedDraftID = checklistDraftRows.first?.id
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button( role: .cancel) {
                        dismiss()
                    } label: {
                        Label("Cancel", systemImage: "xmark")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(role: .confirm) {
                        Task {
                            let success = await viewModel.save()
                            if success { dismiss() }
                        }
                    } label: {
                        if viewModel.isSaving {
                            ProgressView()
                        } else {
                            Label("Save", systemImage: "checkmark")
                        }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
            .alert("Unable to save", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { _ in viewModel.errorMessage = nil }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .sheet(isPresented: $showScheduleSheet) {
                MemoryScheduleTriggerSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showLocationPicker) {
                LocationPickerView { name, latitude, longitude, radius, event in
                    viewModel.addLocationTrigger(name: name,
                                                 latitude: latitude,
                                                 longitude: longitude,
                                                 radius: radius,
                                                 event: event)
                    showLocationPicker = false
                }
            }
            .sheet(isPresented: $showPersonSheet) {
                MemoryPersonTriggerSheet(
                    viewModel: viewModel,
                    showContactPicker: $showContactPicker,
                    showAccessDeniedAlert: $showAccessDeniedAlert
                )
                .presentationDetents([.medium])
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
            .alert("Contacts Access Required", isPresented: $showAccessDeniedAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            } message: {
                Text("Allow contact access in Settings to pick a person trigger.")
            }
        }
    }
    
    private var navigationTitle: String { isEditing ? "Edit Memory" : "New Memory" }
    
    private var detailsSection: some View {
        Section("Details") {
            TextField("Title", text: $viewModel.title)
            
            SpacePicker(selection: Binding(
                get: { viewModel.selectedSpaceID ?? spacesForPicker.first?.id ?? SpaceModel.inbox.id },
                set: { viewModel.selectedSpaceID = $0 }
            ), spaces: spacesForPicker)
            
            Toggle("Pinned", isOn: $viewModel.isPinned)
            
            Picker("Status", selection: $viewModel.status) {
                ForEach(MemoryStatus.allCases) { status in
                    Text(status.rawValue.capitalized).tag(status)
                }
            }
            
            Picker("Priority", selection: $viewModel.priority) {
                ForEach(MemoryPriority.allCases) { priority in
                    Label(priorityLabel(for: priority), systemImage: priority.iconName)
                        .tag(priority)
                }
            }
        }
    }
    
    private var tagsSection: some View {
        Section("Tags") {
            if viewModel.availableTags.isEmpty {
                Text("No tags available.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Menu {
                    ForEach(viewModel.availableTags) { tag in
                        let isSelected = viewModel.selectedTagIDs.contains(tag.id)
                        Button {
                            viewModel.toggleTag(id: tag.id)
                        } label: {
                            Label(tag.name, systemImage: isSelected ? "checkmark.circle.fill" : "circle")
                        }
                    }
                } label: {
                    Label("Select Tags", systemImage: "tag")
                }
                
                if viewModel.selectedTags.isEmpty {
                    Text("No tags selected.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(viewModel.selectedTags) { tag in
                                Text(tag.name)
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }
    
    private var bodySection: some View {
        Section("Body") {
            TextEditor(text: $viewModel.body)
                .frame(minHeight: 150)
        }
    }
    
    private var checklistSection: some View {
        Section {
            ForEach(viewModel.checklistItems) { item in
                ChecklistItemEditor(
                    item: binding(for: item),
                    onToggle: { viewModel.toggleChecklistCompletion(for: item.id) },
                    onDelete: { removeChecklist(item) }
                )
            }
            ForEach(checklistDraftRows) { draft in
                ChecklistNewItemRow(
                    draft: draftBinding(for: draft),
                    focus: $focusedDraftID,
                    onSubmit: handleDraftSubmit,
                    onTitleChange: handleDraftTitleChange
                )
            }
        } header: {
            Label("Checklist", systemImage: "checklist")
        }
    }
    
    private var triggersSection: some View {
        Section {
            MemoryScheduleTriggerInlineForm(viewModel: viewModel, showSheet: $showScheduleSheet)
            
            MemoryLocationTriggerInlineForm(
                viewModel: viewModel,
                showLocationPicker: $showLocationPicker
            )
            
            MemoryPersonTriggerInlineForm(
                viewModel: viewModel,
                showSheet: $showPersonSheet
            )
        } header: {
            Label("Triggers", systemImage: "bolt.fill")
        }
    }
    
    private var dueDateSection: some View {
        Section("Due Date") {
            Toggle("Add due date", isOn: $viewModel.dueDateEnabled.animation())
            if viewModel.dueDateEnabled {
                DatePicker("Date", selection: $viewModel.dueDate, displayedComponents: [.date])
                DatePicker("Time", selection: $viewModel.dueDate, displayedComponents: [.hourAndMinute])
            }
        }
    }
    
    private var extrasSection: some View {
        Section("Preferences") {
            Toggle("Auto-complete when checklist is done", isOn: $viewModel.autoCompleteChecklist)
                .disabled(!viewModel.canToggleAutoComplete)
                .foregroundStyle(viewModel.canToggleAutoComplete ? .primary : .secondary)
        }
    }
    
    private func binding(for item: CheckItemDraft) -> Binding<CheckItemDraft> {
        guard let index = viewModel.checklistItems.firstIndex(where: { $0.id == item.id }) else {
            return .constant(item)
        }
        return $viewModel.checklistItems[index]
    }

    private func draftBinding(for draft: ChecklistDraftRow) -> Binding<ChecklistDraftRow> {
        guard let index = checklistDraftRows.firstIndex(where: { $0.id == draft.id }) else {
            return .constant(draft)
        }
        return $checklistDraftRows[index]
    }

    private func handleDraftSubmit(_ draftID: UUID) {
        guard let index = checklistDraftRows.firstIndex(where: { $0.id == draftID }) else { return }
        let trimmed = checklistDraftRows[index].title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let detail = checklistDraftRows[index].detail.trimmingCharacters(in: .whitespacesAndNewlines)
        viewModel.addChecklistItem(title: trimmed, detail: detail)

        checklistDraftRows[index].title = ""
        checklistDraftRows[index].detail = ""
        if checklistDraftRows.count > 1 {
            checklistDraftRows.remove(at: index)
        }

        if checklistDraftRows.isEmpty {
            checklistDraftRows = [ChecklistDraftRow()]
        }

        cleanupTrailingPlaceholders()
    }

    private func handleDraftTitleChange(_ draftID: UUID, _ text: String) {
        guard let index = checklistDraftRows.firstIndex(where: { $0.id == draftID }) else { return }
        guard !checklistDraftRows.isEmpty else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lastIndex = checklistDraftRows.count - 1

        if trimmed.isEmpty {
            if checklistDraftRows.count > 1 && index != lastIndex {
                checklistDraftRows.remove(at: index)
            }
            cleanupTrailingPlaceholders()
        } else if index == lastIndex {
            checklistDraftRows.append(ChecklistDraftRow())
        }
    }

    private func cleanupTrailingPlaceholders() {
        while checklistDraftRows.count > 1 {
            guard let last = checklistDraftRows.last else { break }
            let beforeLast = checklistDraftRows[checklistDraftRows.count - 2]
            if last.isEffectivelyEmpty && beforeLast.isEffectivelyEmpty {
                checklistDraftRows.removeLast()
            } else {
                break
            }
        }

        if checklistDraftRows.isEmpty {
            checklistDraftRows = [ChecklistDraftRow()]
        }
        DispatchQueue.main.async {
            focusedDraftID = checklistDraftRows.last?.id
        }
    }
    
    private func removeChecklist(_ item: CheckItemDraft) {
        if let index = viewModel.checklistItems.firstIndex(where: { $0.id == item.id }) {
            viewModel.checklistItems.remove(at: index)
            if viewModel.checklistItems.isEmpty {
                viewModel.showChecklist = false
            }
        }
    }
    
    private func priorityLabel(for priority: MemoryPriority) -> String {
        switch priority {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
    
    private var spacesForPicker: [SpaceModel] {
        let spaces = viewModel.availableSpaces
        return spaces.isEmpty ? [SpaceModel.inbox] : spaces
    }
}

private struct SpacePicker: View {
    @Binding var selection: UUID
    let spaces: [SpaceModel]
    
    var body: some View {
        Picker("Space", selection: $selection) {
            ForEach(spaces) { space in
                Text(space.name).tag(space.id)
            }
        }
    }
}

private struct ChecklistItemEditor: View {
    @Binding var item: CheckItemDraft
    let onToggle: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button(action: onToggle) {
                    Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(item.isCompleted ? .green : .secondary)
                }
                .buttonStyle(.plain)

                TextField("Item title", text: $item.title)
                    .submitLabel(.next)

                if shouldShowDelete {
                    Button(action: onDelete) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                }
            }

            TextField("Details", text: $item.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .submitLabel(.next)
        }
        .padding(.vertical, 4)
    }

    private var shouldShowDelete: Bool {
        let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let detail = item.detail.trimmingCharacters(in: .whitespacesAndNewlines)
        return !title.isEmpty || !detail.isEmpty
    }
}

private struct ChecklistNewItemRow: View {
    @Binding var draft: ChecklistDraftRow
    let focus: FocusState<UUID?>.Binding
    let onSubmit: (UUID) -> Void
    let onTitleChange: (UUID, String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "circle")
                    .foregroundStyle(.secondary)
                TextField("New item", text: $draft.title)
                    .submitLabel(.next)
                    .focused(focus, equals: draft.id)
                    .onSubmit { onSubmit(draft.id) }
                    .onChange(of: draft.title) { _, newValue in
                        onTitleChange(draft.id, newValue)
                    }

                if shouldShowClear {
                    Button {
                        draft.title = ""
                        draft.detail = ""
                        onTitleChange(draft.id, "")
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                }
            }

            if shouldShowDetailField {
                TextField("Description", text: $draft.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .submitLabel(.next)
                    .onSubmit { onSubmit(draft.id) }
            }
        }
        .padding(.vertical, 4)
    }

    private var shouldShowClear: Bool {
        !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !draft.detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var shouldShowDetailField: Bool {
        shouldShowClear
    }
}

private struct ChecklistDraftRow: Identifiable, Equatable {
    let id: UUID
    var title: String
    var detail: String

    init(id: UUID = UUID(), title: String = "", detail: String = "") {
        self.id = id
        self.title = title
        self.detail = detail
    }

    var isEffectivelyEmpty: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - Trigger Inline Forms

private struct MemoryScheduleTriggerInlineForm: View {
    @ObservedObject var viewModel: MemoryEditorViewModel
    @Binding var showSheet: Bool
    
    private var timeTrigger: MemoryTriggerDraft? {
        viewModel.triggers.first(where: { $0.type == .time })
    }
    
    private var weekdayTrigger: MemoryTriggerDraft? {
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
            .contentShape(Rectangle())
            .onTapGesture { showSheet = true }
            .swipeActions {
                Button(role: .destructive) {
                    viewModel.clearScheduleTriggers()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        } else {
            Label("Add schedule", systemImage: "plus.circle.fill")
                .foregroundStyle(.accent)
                .contentShape(Rectangle())
                .onTapGesture { showSheet = true }
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

private struct MemoryLocationTriggerInlineForm: View {
    @ObservedObject var viewModel: MemoryEditorViewModel
    @Binding var showLocationPicker: Bool
    
    private var trigger: MemoryTriggerDraft? {
        viewModel.triggers.first(where: { $0.type == .location })
    }
    
    var body: some View {
        if let trigger, let location = trigger.location {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(location.name ?? "Location")
                        .font(.body)
                    Text("\(Int(location.radius))m • \(location.event.label)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
            .onTapGesture { showLocationPicker = true }
            .swipeActions {
                Button(role: .destructive) {
                    viewModel.removeTrigger(id: trigger.id)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        } else {
            Label("Add location trigger", systemImage: "plus.circle.fill")
                .foregroundStyle(.accent)
                .contentShape(Rectangle())
                .onTapGesture { showLocationPicker = true }
        }
    }
}

private struct MemoryPersonTriggerInlineForm: View {
    @ObservedObject var viewModel: MemoryEditorViewModel
    @Binding var showSheet: Bool
    
    private var trigger: MemoryTriggerDraft? {
        viewModel.triggers.first(where: { $0.type == .person })
    }
    
    var body: some View {
        if let trigger, let person = trigger.person {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(person.name)
                        .font(.body)
                    if person.contactIdentifier != nil {
                        Text("Linked contact")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
            .onTapGesture { showSheet = true }
            .swipeActions {
                Button(role: .destructive) {
                    viewModel.removeTrigger(id: trigger.id)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        } else {
            Label("Add person trigger", systemImage: "plus.circle.fill")
                .foregroundStyle(.accent)
                .contentShape(Rectangle())
                .onTapGesture { showSheet = true }
        }
    }
}

// MARK: - Trigger Sheets

private struct MemoryScheduleTriggerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: MemoryEditorViewModel
    @State private var date: Date
    @State private var selectedFrequency: RecurrenceRule.Frequency?
    @State private var repeatInterval: Int
    @State private var selectedWeekdays: Set<Int>
    @State private var includeTimeTrigger: Bool
    
    private var timeTrigger: MemoryTriggerDraft? {
        viewModel.triggers.first(where: { $0.type == .time })
    }
    
    private var weekdayTrigger: MemoryTriggerDraft? {
        viewModel.triggers.first(where: { $0.type == .dayOfWeek })
    }
    
    private var hasExistingSchedule: Bool {
        timeTrigger != nil || weekdayTrigger != nil
    }
    
    init(viewModel: MemoryEditorViewModel) {
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
                    MemoryWeekdaySelectionView(selectedDays: $selectedWeekdays)
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

private struct MemoryPersonTriggerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: MemoryEditorViewModel
    @Binding var showContactPicker: Bool
    @Binding var showAccessDeniedAlert: Bool
    @State private var name: String
    @State private var contactIdentifier: String
    
    private var existingTrigger: MemoryTriggerDraft? {
        viewModel.triggers.first(where: { $0.type == .person })
    }
    
    init(viewModel: MemoryEditorViewModel,
         showContactPicker: Binding<Bool>,
         showAccessDeniedAlert: Binding<Bool>) {
        self.viewModel = viewModel
        _showContactPicker = showContactPicker
        _showAccessDeniedAlert = showAccessDeniedAlert
        
        let trigger = viewModel.triggers.first(where: { $0.type == .person })
        _name = State(initialValue: trigger?.person?.name ?? "")
        _contactIdentifier = State(initialValue: trigger?.person?.contactIdentifier ?? "")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Contact") {
                    HStack {
                        TextField("Name", text: $name)
                        Button {
                            Task { await requestContactsAndShow() }
                        } label: {
                            Image(systemName: "person.crop.circle.badge.plus")
                        }
                        .buttonStyle(.borderless)
                    }
                    
                    if !contactIdentifier.isEmpty {
                        Label("Contact linked", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
                
                Section {
                    Text("Enter a name or choose from contacts.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
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
        }
    }
    
    private func requestContactsAndShow() async {
        let status = ContactAccessHelper.checkAuthorizationStatus()
        switch status {
        case .authorized, .limited:
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
        @unknown default:
            showAccessDeniedAlert = true
        }
    }
}

private struct MemoryWeekdaySelectionView: View {
    @Binding var selectedDays: Set<Int>
    private let columns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 12), count: 7)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(1...7, id: \.self) { day in
                    let isSelected = selectedDays.contains(day)
                    Button {
                        toggle(day)
                    } label: {
                        GeometryReader { proxy in
                            let diameter = proxy.size.width
                            Circle()
                                .fill(isSelected ? Color.accentColor : Color(.tertiarySystemFill))
                                .overlay(
                                    Text(symbol(for: day))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(isSelected ? Color(.systemBackground) : .primary)
                                )
                                .frame(width: diameter, height: diameter)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .aspectRatio(1, contentMode: .fit)
                    .buttonStyle(.plain)
                    .contentShape(Circle())
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
        let mask = selectedDays.reduce(into: Int16(0)) { result, day in
            result |= Int16(1 << day)
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

#Preview {
    let environment = AppEnvironment(persistence: PersistenceController.preview)
    environment.bootstrap()
    return MemoryEditorView(environment: environment)
}
