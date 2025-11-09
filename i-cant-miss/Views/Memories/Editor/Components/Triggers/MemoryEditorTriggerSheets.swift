import SwiftUI
import Contacts

struct MemoryScheduleTriggerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: MemoryEditorViewModel
    @State private var dueDateEnabled: Bool
    @State private var dueDate: Date
    @State private var timeTriggerEnabled: Bool
    @State private var timeDate: Date
    @State private var selectedFrequency: RecurrenceRule.Frequency?
    @State private var repeatInterval: Int
    @State private var weekdayEnabled: Bool
    @State private var weekdaySelection: Set<Int>
    @State private var weekdayReferenceTime: Date

    private var timeTrigger: MemoryTriggerDraft? {
        viewModel.triggers.first(where: { $0.type == .time })
    }

    private var weekdayTrigger: MemoryTriggerDraft? {
        viewModel.triggers.first(where: { $0.type == .dayOfWeek })
    }

    init(viewModel: MemoryEditorViewModel) {
        self.viewModel = viewModel

        let existingTime = viewModel.triggers.first(where: { $0.type == .time })
        let existingWeekday = viewModel.triggers.first(where: { $0.type == .dayOfWeek })
        let defaultReferenceDate = existingTime?.fireDate ?? existingWeekday?.fireDate ?? Date().addingTimeInterval(3600)
        let initialWeekdays = MemoryScheduleTriggerSheet.weekdaySet(from: existingWeekday?.weekdayMask ?? 0)

        _dueDateEnabled = State(initialValue: viewModel.dueDateEnabled)
        _dueDate = State(initialValue: viewModel.dueDate)
        _timeTriggerEnabled = State(initialValue: existingTime != nil)
        _timeDate = State(initialValue: existingTime?.fireDate ?? defaultReferenceDate)
        _selectedFrequency = State(initialValue: existingTime?.recurrenceRule?.frequency)
        _repeatInterval = State(initialValue: max(existingTime?.recurrenceRule?.interval ?? 1, 1))
        _weekdayEnabled = State(initialValue: !initialWeekdays.isEmpty)
        _weekdaySelection = State(initialValue: initialWeekdays)
        _weekdayReferenceTime = State(initialValue: existingWeekday?.fireDate ?? existingTime?.fireDate ?? defaultReferenceDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Due Date") {
                    Toggle("Enable due date", isOn: $dueDateEnabled.animation())
                    if dueDateEnabled {
                        DatePicker("Date", selection: $dueDate, displayedComponents: [.date])
                        DatePicker("Time", selection: $dueDate, displayedComponents: [.hourAndMinute])
                    } else {
                        Text("Turn this on to convert the memory into a dated checklist.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Exact Date & Time") {
                    Toggle("Enable time trigger", isOn: $timeTriggerEnabled.animation())
                    if timeTriggerEnabled {
                        DatePicker("Date", selection: $timeDate, displayedComponents: [.date])
                        DatePicker("Time", selection: $timeDate, displayedComponents: [.hourAndMinute])

                        Picker("Repeat", selection: $selectedFrequency) {
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
                    } else if timeTrigger != nil {
                        Text("This memory currently has a time trigger. Disabling removes it.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Weekday Routine") {
                    Toggle("Enable weekday schedule", isOn: $weekdayEnabled.animation())
                    if weekdayEnabled {
                        MemoryWeekdaySelectionView(selectedDays: $weekdaySelection)

                        DatePicker("Time", selection: $weekdayReferenceTime, displayedComponents: [.hourAndMinute])

                        if weekdaySelection.isEmpty {
                            Text("Select at least one weekday to keep this trigger active.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(weekdaySummaryText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else if weekdayTrigger != nil {
                        Text("This memory already repeats on weekdays. Disable to remove it.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Date Triggers")
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
            .onChange(of: weekdayEnabled) { newValue in
                if !newValue {
                    weekdaySelection.removeAll()
                } else if weekdaySelection.isEmpty {
                    weekdaySelection.insert(MemoryScheduleTriggerSheet.currentWeekday())
                }
            }
        }
    }

    private var isSaveDisabled: Bool {
        weekdayEnabled && weekdaySelection.isEmpty
    }

    private var weekdaySummaryText: String {
        weekdayMaskSummary(mask: MemoryScheduleTriggerSheet.mask(from: weekdaySelection))
    }

    private func applyChanges() {
        viewModel.dueDateEnabled = dueDateEnabled
        if dueDateEnabled {
            viewModel.dueDate = dueDate
        }

        if timeTriggerEnabled {
            let recurrence = selectedFrequency.map { RecurrenceRule(frequency: $0, interval: repeatInterval) }
            viewModel.setTimeTrigger(fireDate: timeDate, recurrence: recurrence)
        } else {
            viewModel.setTimeTrigger(fireDate: nil, recurrence: nil)
        }

        if weekdayEnabled && !weekdaySelection.isEmpty {
            viewModel.setWeekdayTrigger(weekdaySelection: weekdaySelection, referenceTime: weekdayReferenceTime)
        } else {
            viewModel.setWeekdayTrigger(weekdaySelection: [], referenceTime: weekdayReferenceTime)
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

enum MemoryTriggerPickerDestination: Hashable {
    case date
    case location
    case person
    case sequential
}

struct MemoryTriggerPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: MemoryEditorViewModel
    let onSelect: (MemoryTriggerPickerDestination) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("Date & Time") {
                    TriggerPickerRow(
                        title: "Date triggers",
                        subtitle: dateSubtitle,
                        systemImage: "calendar.badge.clock"
                    ) {
                        select(.date)
                    }
                }

                Section("Location") {
                    TriggerPickerRow(
                        title: "Location trigger",
                        subtitle: locationSubtitle,
                        systemImage: "mappin.circle.fill"
                    ) {
                        select(.location)
                    }
                }

                Section("Person") {
                    TriggerPickerRow(
                        title: "Person trigger",
                        subtitle: personSubtitle,
                        systemImage: "person.crop.circle.badge.plus"
                    ) {
                        select(.person)
                    }
                }

                Section("Sequence") {
                    TriggerPickerRow(
                        title: "Sequential trigger",
                        subtitle: "Link this memory with others to create sequences.",
                        systemImage: "arrowshape.turn.up.right.circle.badge.clockwise"
                    ) {
                        select(.sequential)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Add Trigger")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var dateSubtitle: String {
        if viewModel.dueDateEnabled || viewModel.triggers.contains(where: { $0.type == .time || $0.type == .dayOfWeek }) {
            return "Update existing due date or schedule."
        }
        return "Create due dates, specific events or weekday routines."
    }

    private var locationSubtitle: String {
        if viewModel.triggers.contains(where: { $0.type == .location }) {
            return "Edit the existing location reminder."
        }
        return "Be reminded when arriving or leaving a place."
    }

    private var personSubtitle: String {
        if viewModel.triggers.contains(where: { $0.type == .person }) {
            return "Update the person associated with this memory."
        }
        return "Trigger when you interact with someone."
    }

    private func select(_ destination: MemoryTriggerPickerDestination) {
        onSelect(destination)
        dismiss()
    }
}

private struct TriggerPickerRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .frame(width: 28, height: 28)
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.callout.weight(.semibold))
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}

struct MemoryPersonTriggerSheet: View {
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

struct MemorySequentialTriggerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: MemoryEditorViewModel
    let excludedMemoryID: UUID?
    @State private var selectedPrevious: UUID?
    @State private var selectedNext: UUID?
    @State private var searchText: String = ""

    init(viewModel: MemoryEditorViewModel,
         excludedMemoryID: UUID?) {
        self.viewModel = viewModel
        self.excludedMemoryID = excludedMemoryID
        let configuration = viewModel.sequentialTrigger?.sequential
        _selectedPrevious = State(initialValue: configuration?.previousMemoryID)
        _selectedNext = State(initialValue: configuration?.nextMemoryID)
    }

    var body: some View {
        NavigationStack {
            List {
                infoSection
                selectionSection(kind: .previous)
                selectionSection(kind: .next)

                if selectedPrevious != nil || selectedNext != nil {
                    Section {
                        Button("Remove sequential trigger", role: .destructive) {
                            viewModel.removeSequentialTrigger()
                            selectedPrevious = nil
                            selectedNext = nil
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchText, prompt: "Search memories")
            .navigationTitle("Sequential Trigger")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.updateSequentialTrigger(
                            previousMemoryID: selectedPrevious,
                            nextMemoryID: selectedNext
                        )
                        dismiss()
                    }
                }
            }
        }
    }

    private var infoSection: some View {
        Section {
            Text("Choose which memory unlocks this one and which should be scheduled afterwards. When the previous memory completes, the next memory will be scheduled for the following day.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.vertical, 4)
        }
    }

    private func selectionSection(kind: SelectionKind) -> some View {
        Section(kind.title) {
            selectionSummary(kind: kind)
            let sections = spaceSections(filteredBy: searchText)
            if sections.isEmpty {
                Text("No memories available.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                ForEach(sections) { section in
                    if !section.memories.isEmpty {
                        DisclosureGroup(section.space.name) {
                            ForEach(section.memories) { memory in
                                selectableRow(for: memory, kind: kind)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func selectionSummary(kind: SelectionKind) -> some View {
        let selectionID = kind == .previous ? selectedPrevious : selectedNext
        if let selectionID, let memory = memoryLookup[selectionID] {
            VStack(alignment: .leading, spacing: 4) {
                Text(memory.title)
                    .font(.callout.weight(.semibold))
                HStack(spacing: 6) {
                    Image(systemName: "folder")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(memory.space.name)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    statusBadge(for: memory)
                }
                Button("Clear selection") {
                    if kind == .previous {
                        selectedPrevious = nil
                    } else {
                        selectedNext = nil
                    }
                }
                .font(.footnote)
                .buttonStyle(.borderless)
            }
            .padding(.vertical, 4)
        } else {
            Text(kind.emptyMessage)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private func selectableRow(for memory: MemoryModel, kind: SelectionKind) -> some View {
        let currentSelection = kind == .previous ? selectedPrevious : selectedNext
        let isSelected = currentSelection == memory.id
        let isDisabled: Bool = {
            switch kind {
            case .previous:
                return selectedNext == memory.id
            case .next:
                return selectedPrevious == memory.id
            }
        }()

        return Button {
            toggleSelection(for: memory.id, kind: kind)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(memory.title)
                        .font(.subheadline.weight(isSelected ? .semibold : .regular))
                        .foregroundColor(isDisabled ? .secondary : .primary)
                    HStack(spacing: 6) {
                        Text(memory.space.name)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        statusBadge(for: memory)
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                } else if isDisabled {
                    Image(systemName: "slash.circle")
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 4)
        }
        .disabled(isDisabled)
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func statusBadge(for memory: MemoryModel) -> some View {
        switch memory.status {
        case .active:
            EmptyView()
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(.green)
        case .archived:
            Image(systemName: "archivebox.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func toggleSelection(for id: UUID, kind: SelectionKind) {
        switch kind {
        case .previous:
            if selectedPrevious == id {
                selectedPrevious = nil
            } else {
                selectedPrevious = id
                if selectedNext == id {
                    selectedNext = nil
                }
            }
        case .next:
            if selectedNext == id {
                selectedNext = nil
            } else {
                selectedNext = id
                if selectedPrevious == id {
                    selectedPrevious = nil
                }
            }
        }
    }

    private func spaceSections(filteredBy query: String) -> [SpaceSection] {
        let candidates = filteredCandidates(query: query)
        let grouped = Dictionary(grouping: candidates, by: \.space)
        return grouped
            .map { SpaceSection(space: $0.key, memories: $0.value.sorted(by: { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending })) }
            .sorted { $0.space.name.localizedCaseInsensitiveCompare($1.space.name) == .orderedAscending }
    }

    private func filteredCandidates(query: String) -> [MemoryModel] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return allCandidates }
        return allCandidates.filter { memory in
            memory.title.localizedCaseInsensitiveContains(trimmed) ||
            memory.space.name.localizedCaseInsensitiveContains(trimmed)
        }
    }

    private var allCandidates: [MemoryModel] {
        viewModel.environment.memoryService.memories.filter { memory in
            guard matchesOrigin(memory: memory) else { return false }
            if let excludedMemoryID, memory.id == excludedMemoryID {
                return false
            }
            return true
        }
    }

    private var memoryLookup: [UUID: MemoryModel] {
        Dictionary(uniqueKeysWithValues: viewModel.environment.memoryService.memories.map { ($0.id, $0) })
    }

    private func matchesOrigin(memory: MemoryModel) -> Bool {
        guard let origin = memory.metadata.origin else { return false }
        switch origin {
        case .reminder:
            return true
        case .note, .todoList:
            return false
        }
    }

    private enum SelectionKind {
        case previous
        case next

        var title: String {
            switch self {
            case .previous: return "Previous memory"
            case .next: return "Next memory"
            }
        }

        var emptyMessage: String {
            switch self {
            case .previous: return "No previous memory selected."
            case .next: return "No next memory selected."
            }
        }
    }

    private struct SpaceSection: Identifiable {
        let space: SpaceModel
        let memories: [MemoryModel]

        var id: UUID { space.id }
    }
}

struct MemoryWeekdaySelectionView: View {
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
