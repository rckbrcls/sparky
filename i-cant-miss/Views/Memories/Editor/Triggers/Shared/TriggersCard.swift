import SwiftUI
import Contacts
import UIKit
import MapKit
import UniformTypeIdentifiers

struct TriggersCard: View {
    @ObservedObject var viewModel: MemoryEditorViewModel
    let memoryLookup: [UUID: MemoryModel]

    // State to track which empty forms are visible
    @State private var showScheduledForm = false
    @State private var showPersonForm = false
    @State private var showLocationForm = false
    @State private var showSequentialForm = false

    private var triggerCount: Int {
        viewModel.triggers.count + (showScheduledForm ? 1 : 0) + (showPersonForm ? 1 : 0) + (showLocationForm ? 1 : 0) + (showSequentialForm ? 1 : 0)
    }

    private var hasAnyTriggerOrForm: Bool {
        hasScheduledTrigger || hasLocationTrigger || hasPersonTrigger || hasSequentialTrigger ||
        showScheduledForm || showPersonForm || showLocationForm || showSequentialForm
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(spacing: 8) {
                // Scheduled Trigger - Inline Form (existing or empty)
                if hasScheduledTrigger {
                    ScheduledTriggerInlineForm(
                        viewModel: viewModel,
                        onDelete: { removeTrigger(type: .scheduled) }
                    )
                } else if showScheduledForm {
                    ScheduledTriggerEmptyForm(
                        viewModel: viewModel,
                        onCancel: { showScheduledForm = false },
                        onSave: { showScheduledForm = false }
                    )
                }

                // Location Trigger - Inline Form
                if hasLocationTrigger {
                    LocationTriggerInlineForm(
                        viewModel: viewModel,
                        onDelete: { removeTrigger(type: .location) }
                    )
                } else if showLocationForm {
                    LocationTriggerEmptyForm(
                        viewModel: viewModel,
                        onCancel: { showLocationForm = false },
                        onSave: { showLocationForm = false }
                    )
                }

                // Person Trigger - Inline Form (existing or empty)
                if hasPersonTrigger {
                    PersonTriggerInlineForm(
                        viewModel: viewModel,
                        onDelete: { removeTrigger(type: .person) }
                    )
                } else if showPersonForm {
                    PersonTriggerEmptyForm(
                        viewModel: viewModel,
                        onCancel: { showPersonForm = false },
                        onSave: { showPersonForm = false }
                    )
                }

                // Sequential Trigger - Inline Form
                if hasSequentialTrigger {
                    SequentialTriggerInlineForm(
                        viewModel: viewModel,
                        memoryLookup: memoryLookup,
                        onDelete: { viewModel.removeSequentialTrigger() }
                    )
                } else if showSequentialForm {
                    SequentialTriggerEmptyForm(
                        viewModel: viewModel,
                        onCancel: { showSequentialForm = false },
                        onSave: { showSequentialForm = false }
                    )
                }

                // Add trigger button (dashed border)
                addTriggerButton
            }
        }
    }

    private var addTriggerButton: some View {
        Menu {
            if !hasScheduledTrigger && !showScheduledForm {
                Button {
                    showScheduledForm = true
                } label: {
                    Label("Date & Time", systemImage: "clock.badge")
                }
            }

            if !hasLocationTrigger && !showLocationForm {
                Button {
                    showLocationForm = true
                } label: {
                    Label("Location", systemImage: "mappin.circle.fill")
                }
            }

            if !hasPersonTrigger && !showPersonForm {
                Button {
                    showPersonForm = true
                } label: {
                    Label("Person", systemImage: "person.crop.circle.badge.plus")
                }
            }

            if !hasSequentialTrigger && !showSequentialForm {
                Button {
                    showSequentialForm = true
                } label: {
                    Label("Sequence", systemImage: "arrow.right")
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.caption.bold())
                Text("Add Trigger")
                    .font(.caption.bold())
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    .foregroundStyle(Color.secondary.opacity(0.4))
            )
            .contentShape(Rectangle())
        }
        .foregroundStyle(.primary)
        .accessibilityLabel("Add trigger")
    }

    // MARK: - Trigger State Helpers

    private var hasScheduledTrigger: Bool {
        viewModel.triggers.contains(where: { $0.type == .scheduled })
    }

    private var hasLocationTrigger: Bool {
        viewModel.triggers.contains(where: { $0.type == .location })
    }

    private var hasPersonTrigger: Bool {
        viewModel.triggers.contains(where: { $0.type == .person })
    }

    private var hasSequentialTrigger: Bool {
        return viewModel.sequentialTrigger?.sequential != nil
    }

    // MARK: - Helper Functions

    private func removeTrigger(type: MemoryTriggerType) {
        if let trigger = viewModel.triggers.first(where: { $0.type == type }) {
            viewModel.removeTrigger(id: trigger.id)
        }
    }
}

// MARK: - Scheduled Trigger Inline Form

private struct ScheduledTriggerInlineForm: View {
    @ObservedObject var viewModel: MemoryEditorViewModel
    let onDelete: () -> Void

    @State private var fireDate: Date
    @State private var timeOfDayType: TimeOfDayType
    @State private var repeatType: RepeatType
    @State private var showCustomRepeatSheet: Bool = false
    @State private var customRepeatType: CustomRepeatType = .weekly
    @State private var selectedWeekdays: Set<Int>
    @State private var selectedMonthDays: Set<Int>

    private var existingTrigger: MemoryTriggerDraft? {
        viewModel.triggers.first(where: { $0.type == .scheduled })
    }

    init(viewModel: MemoryEditorViewModel, onDelete: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onDelete = onDelete

        let scheduledTrigger = viewModel.triggers.first(where: { $0.type == .scheduled })
        let defaultDate = scheduledTrigger?.fireDate ?? Date().addingTimeInterval(3600)
        _fireDate = State(initialValue: defaultDate)

        let detectedTimeOfDay: TimeOfDayType = scheduledTrigger?.isAllDay == true ? .allDay : .specificTime
        _timeOfDayType = State(initialValue: detectedTimeOfDay)

        let detectedRepeatType = Self.detectRepeatType(from: scheduledTrigger)
        _repeatType = State(initialValue: detectedRepeatType)

        let initialWeekdays = Self.weekdaySet(from: scheduledTrigger?.weekdayMask ?? 0)
        _selectedWeekdays = State(initialValue: initialWeekdays)
        _selectedMonthDays = State(initialValue: [])

        if !initialWeekdays.isEmpty {
            _customRepeatType = State(initialValue: .weekly)
        } else {
            _customRepeatType = State(initialValue: .weekly)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            TriggerSectionHeader(
                iconName: "clock.badge",
                title: "Date & Time",
                onDelete: onDelete
            )

            VStack(spacing: 12) {
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
                    ForEach(RepeatType.allCases) { type in
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
            .padding(16)
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .onChange(of: fireDate) { _, _ in applyChanges() }
        .onChange(of: timeOfDayType) { _, _ in applyChanges() }
        .onChange(of: repeatType) { _, _ in applyChanges() }
        .onChange(of: selectedWeekdays) { _, _ in applyChanges() }
        .onChange(of: selectedMonthDays) { _, _ in applyChanges() }
        .sheet(isPresented: $showCustomRepeatSheet) {
            CustomRepeatSheet(
                customRepeatType: $customRepeatType,
                selectedWeekdays: $selectedWeekdays,
                selectedMonthDays: $selectedMonthDays
            )
        }
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

    private func applyChanges() {
        var adjustedFireDate = fireDate
        if timeOfDayType == .allDay {
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
                recurrence = RecurrenceRule(frequency: .monthly, interval: 1)
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

        viewModel.setScheduledTrigger(
            fireDate: adjustedFireDate,
            recurrence: recurrence,
            weekdaySelection: weekdaySelection,
            referenceTime: adjustedFireDate,
            isAllDay: timeOfDayType == .allDay
        )
    }

    private static func detectRepeatType(from trigger: MemoryTriggerDraft?) -> RepeatType {
        guard let trigger = trigger, let recurrence = trigger.recurrenceRule else {
            return .never
        }

        if trigger.weekdayMask != 0 {
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

// MARK: - Location Trigger Inline Form

private struct LocationTriggerInlineForm: View {
    @ObservedObject var viewModel: MemoryEditorViewModel
    let onDelete: () -> Void

    @StateObject private var searchModel = LocationSearchViewModel()
    @StateObject private var geocodingModel = LocationGeocoder()
    @State private var region: MKCoordinateRegion
    @State private var mapCameraPosition: MapCameraPosition
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var selectedName: String
    @State private var event: LocationEvent
    @State private var isMapExpanded = false
    @State private var isCameraAdjusting = false
    @State private var geocodeTask: Task<Void, Never>?
    @State private var cameraCooldownTask: Task<Void, Never>?
    @State private var isSearching = false
    @FocusState private var isSearchFieldFocused: Bool

    private let defaultRadius: Double = 200
    private let expandedSuggestionBottomPadding: CGFloat = 120

    private var existingTrigger: MemoryTriggerDraft? {
        viewModel.triggers.first(where: { $0.type == .location })
    }

    init(viewModel: MemoryEditorViewModel, onDelete: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onDelete = onDelete

        let trigger = viewModel.triggers.first(where: { $0.type == .location })
        let lat = trigger?.location?.latitude ?? 37.3349
        let lon = trigger?.location?.longitude ?? -122.00902
        let name = trigger?.location?.name ?? ""
        let eventType = trigger?.location?.event ?? .onEntry

        let initialRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )

        _region = State(initialValue: initialRegion)
        _mapCameraPosition = State(initialValue: .region(initialRegion))
        _selectedCoordinate = State(initialValue: CLLocationCoordinate2D(latitude: lat, longitude: lon))
        _selectedName = State(initialValue: name)
        _event = State(initialValue: eventType)
    }

    var body: some View {
        VStack(spacing: 0) {
            TriggerSectionHeader(
                iconName: "mappin.circle.fill",
                title: "Location",
                onDelete: onDelete
            )

            VStack(spacing: 12) {
                // Map preview
                LocationPickerView.MapSection(
                    onExpand: { isMapExpanded = true },
                    mapPreview: { mapPreviewContent }
                )

                // Location info
                if let location = existingTrigger?.location {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(location.name ?? "Selected Location")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Text(String(format: "%.4f, %.4f", location.latitude, location.longitude))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }

                // Event picker
                Picker("Remind when", selection: $event) {
                    ForEach(LocationEvent.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: event) { _, _ in
                    applyChanges()
                }
            }
            .padding(16)
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .fullScreenCover(isPresented: $isMapExpanded) {
            expandedMapView
        }
        .onReceive(searchModel.$isSearching) { value in
            withAnimation(.easeInOut(duration: 0.2)) {
                isSearching = value
            }
        }
        .onDisappear {
            geocodeTask?.cancel()
            cameraCooldownTask?.cancel()
        }
    }

    private var mapPreviewContent: some View {
        MapContainer(
            allowsSelection: false,
            mapCameraPosition: $mapCameraPosition,
            region: $region,
            selectedCoordinate: $selectedCoordinate,
            defaultRadius: defaultRadius,
            resolvedLocationName: resolvedLocationName,
            onCameraChange: { _ in },
            onCoordinateSelected: { _ in }
        )
        .allowsHitTesting(false)
        .environmentObject(geocodingModel)
    }

    private var expandedMapView: some View {
        LocationPickerView.ExpandedMapScreen(
            searchModel: searchModel,
            suggestionBottomPadding: expandedSuggestionBottomPadding,
            mapContent: { mapView(allowsSelection: true) },
            selectionOverlay: { mapSelectionOverlay },
            centerIndicator: { mapCenterIndicator },
            searchBar: { expandedSearchBar },
            suggestionPanel: { expandedSuggestionPanel },
            confirmationPanel: { expandedConfirmationPanel },
            searchFieldFocus: $isSearchFieldFocused,
            onDismiss: { isMapExpanded = false }
        )
    }

    private func mapView(allowsSelection: Bool) -> some View {
        MapContainer(
            allowsSelection: allowsSelection,
            mapCameraPosition: $mapCameraPosition,
            region: $region,
            selectedCoordinate: $selectedCoordinate,
            defaultRadius: defaultRadius,
            resolvedLocationName: resolvedLocationName,
            onCameraChange: handleCameraRegionChange(to:),
            onCoordinateSelected: { coordinate in
                updateSelection(to: coordinate, resetName: true, updateCamera: false, shouldGeocode: true)
            }
        )
        .environmentObject(geocodingModel)
    }

    private var mapSelectionOverlay: some View {
        HStack {
            Text("Drag the map to position the pin precisely.")
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(Color(.systemBackground), in: Capsule())
            Spacer()
        }
        .padding(12)
        .allowsHitTesting(false)
    }

    private var mapCenterIndicator: some View {
        VStack {
            Spacer()
            VStack(spacing: 4) {
                Image(systemName: geocodingModel.isResolving ? "mappin.circle" : "mappin.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.primary)
                    .shadow(color: Color.black.opacity(0.25), radius: 8, y: 6)
                Circle()
                    .fill(Color.primary.opacity(0.25))
                    .frame(width: 18, height: 18)
                    .overlay(
                        Circle()
                            .fill(Color.primary)
                            .frame(width: 6, height: 6)
                    )
            }
            .offset(y: -28)
            Spacer()
        }
        .allowsHitTesting(false)
    }

    private var expandedSearchBar: some View {
        LocationPickerView.ExpandedSearchBar(
            query: $searchModel.query,
            isSearching: isSearching,
            onClearQuery: { searchModel.query = ""; searchModel.suggestions = [] }
        )
    }

    private var expandedSuggestionPanel: some View {
        LocationPickerView.ExpandedSuggestionPanel(
            suggestions: searchModel.suggestions,
            onSuggestionSelected: { suggestion in
                Task { await selectSuggestion(suggestion) }
            }
        )
    }

    private var expandedConfirmationPanel: some View {
        LocationPickerView.ExpandedConfirmationPanel(
            resolvedLocationName: resolvedLocationName,
            coordinateSummary: coordinateSummary,
            isResolving: geocodingModel.isResolving,
            event: $event,
            onUseLocation: {
                applyChanges()
                isMapExpanded = false
            }
        )
    }

    private var resolvedLocationName: String {
        guard selectedCoordinate != nil else { return "Select a place on the map" }
        if geocodingModel.isResolving && selectedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Resolving address..."
        }
        let trimmed = selectedName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Pinned Location" : trimmed
    }

    private var coordinateSummary: String {
        guard let coordinate = selectedCoordinate else { return "Drag the map to choose a location." }
        return String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude)
    }

    private func handleCameraRegionChange(to updatedRegion: MKCoordinateRegion) {
        guard !isCameraAdjusting else { return }
        let coordinate = updatedRegion.center
        if selectedCoordinate?.isApproximatelyEqual(to: coordinate) == true { return }
        selectedName = ""
        selectedCoordinate = coordinate
        scheduleReverseGeocode(for: coordinate)
    }

    private func updateSelection(to coordinate: CLLocationCoordinate2D,
                                 span overrideSpan: MKCoordinateSpan? = nil,
                                 name: String? = nil,
                                 resetName: Bool = true,
                                 updateCamera: Bool = false,
                                 shouldGeocode: Bool = true) {
        let targetSpan = sanitizedSpan(overrideSpan ?? region.span)
        let updatedRegion = MKCoordinateRegion(center: coordinate, span: targetSpan)

        selectedCoordinate = coordinate
        region = updatedRegion

        if updateCamera {
            isCameraAdjusting = true
            mapCameraPosition = .region(updatedRegion)
            cameraCooldownTask?.cancel()
            cameraCooldownTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 250_000_000)
                isCameraAdjusting = false
            }
        }

        if let providedName = name {
            selectedName = providedName
        } else if resetName {
            selectedName = ""
        }

        if shouldGeocode {
            scheduleReverseGeocode(for: coordinate, force: name == nil)
        }
    }

    private func scheduleReverseGeocode(for coordinate: CLLocationCoordinate2D, force: Bool = false) {
        geocodeTask?.cancel()
        geocodeTask = Task { @MainActor in
            if !force { try? await Task.sleep(nanoseconds: 350_000_000) }
            guard !Task.isCancelled else { return }
            if let resolved = await geocodingModel.resolveName(for: coordinate) {
                guard !Task.isCancelled else { return }
                if let currentCoordinate = selectedCoordinate, currentCoordinate.isApproximatelyEqual(to: coordinate) {
                    selectedName = resolved
                }
            } else if selectedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                selectedName = "Pinned Location"
            }
        }
    }

    private func selectSuggestion(_ suggestion: MKLocalSearchCompletion) async {
        if let result = await searchModel.search(for: suggestion) {
            await MainActor.run {
                let resolvedName = result.name ?? suggestion.title
                let coordinate = result.location.coordinate
                updateSelection(to: coordinate, name: resolvedName, resetName: false, updateCamera: true, shouldGeocode: false)
                searchModel.query = suggestion.title
                withAnimation(.easeInOut(duration: 0.2)) { searchModel.suggestions = [] }
                isSearchFieldFocused = false
            }
        }
    }

    private func sanitizedSpan(_ span: MKCoordinateSpan) -> MKCoordinateSpan {
        let latitude = span.latitudeDelta > 0 ? span.latitudeDelta : 0.01
        let longitude = span.longitudeDelta > 0 ? span.longitudeDelta : 0.01
        return MKCoordinateSpan(latitudeDelta: latitude, longitudeDelta: longitude)
    }

    private func applyChanges() {
        guard let coordinate = selectedCoordinate else { return }
        let name = resolvedLocationName
        viewModel.addLocationTrigger(
            name: name,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            radius: defaultRadius,
            event: event
        )
    }
}


// MARK: - Person Trigger Inline Form

private struct PersonTriggerInlineForm: View {
    @ObservedObject var viewModel: MemoryEditorViewModel
    let onDelete: () -> Void

    @State private var name: String
    @State private var contactIdentifier: String
    @State private var showContactPicker = false
    @State private var showAccessDeniedAlert = false

    private var existingTrigger: MemoryTriggerDraft? {
        viewModel.triggers.first(where: { $0.type == .person })
    }

    init(viewModel: MemoryEditorViewModel, onDelete: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onDelete = onDelete
        let trigger = viewModel.triggers.first(where: { $0.type == .person })
        _name = State(initialValue: trigger?.person?.name ?? "")
        _contactIdentifier = State(initialValue: trigger?.person?.contactIdentifier ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            TriggerSectionHeader(
                iconName: "person.crop.circle.fill",
                title: "Person",
                onDelete: onDelete
            )

            VStack(spacing: 12) {
                HStack {
                    TextField("Name", text: $name)
                        .textFieldStyle(.plain)
                        .onChange(of: name) { _, _ in
                            commitChanges()
                        }
                    Button {
                        Task { await requestContactsAndShow() }
                    } label: {
                        Image(systemName: "person.crop.circle.badge.plus")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Pick from contacts")
                }

                if !contactIdentifier.isEmpty {
                    Label("Contact linked", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            .padding(16)
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .sheet(isPresented: $showContactPicker) {
            ContactPickerView { selectedName, identifier in
                name = selectedName
                contactIdentifier = identifier ?? ""
                showContactPicker = false
                commitChanges()
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

    private func commitChanges() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        if let trigger = existingTrigger {
            var updated = trigger
            updated.person = .init(
                name: trimmedName,
                contactIdentifier: contactIdentifier.isEmpty ? nil : contactIdentifier
            )
            viewModel.updateTrigger(id: trigger.id, with: updated)
        }
    }

    private func requestContactsAndShow() async {
        let status = ContactAccessHelper.checkAuthorizationStatus()
        switch status {
        case .authorized, .limited:
            await MainActor.run {
                showContactPicker = true
            }
        case .notDetermined:
            let granted = await ContactAccessHelper.requestAccess()
            await MainActor.run {
                if granted {
                    showContactPicker = true
                } else {
                    showAccessDeniedAlert = true
                }
            }
        case .denied, .restricted:
            await MainActor.run {
                showAccessDeniedAlert = true
            }
        @unknown default:
            await MainActor.run {
                showAccessDeniedAlert = true
            }
        }
    }
}

// MARK: - Sequential Trigger Inline Form

private struct SequentialTriggerInlineForm: View {
    @ObservedObject var viewModel: MemoryEditorViewModel
    let memoryLookup: [UUID: MemoryModel]
    let onDelete: () -> Void

    @State private var sequenceItems: [SequentialItem] = []
    @State private var showingPicker = false
    @State private var draggedItem: SequentialItem?
    @State private var isExpanded = false

    private var sequentialConfig: MemoryTriggerModel.TriggerSequential? {
        viewModel.sequentialTrigger?.sequential
    }

    var body: some View {
        VStack(spacing: 0) {
            TriggerSectionHeader(
                iconName: "arrowshape.turn.up.right.circle",
                title: "Sequence",
                onDelete: onDelete
            )

            VStack(spacing: 12) {
                if let config = sequentialConfig {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Step \(config.stepIndex + 1)")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(.primary)

                            Spacer()

                            Text("in sequence")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Button {
                                withAnimation { isExpanded.toggle() }
                            } label: {
                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if isExpanded {
                            // Drag-and-drop list
                            VStack(spacing: 8) {
                                ForEach(sequenceItems) { item in
                                    SequentialItemRow(
                                        index: sequenceItems.firstIndex(of: item) ?? 0,
                                        item: item,
                                        currentMemoryID: viewModel.editingMemoryID,
                                        onDelete: {
                                            if !item.isCurrent, let idx = sequenceItems.firstIndex(of: item) {
                                                withAnimation { _ = sequenceItems.remove(at: idx) }
                                                Task { await saveSequenceChanges() }
                                            }
                                        }
                                    )
                                    .onDrag {
                                        draggedItem = item
                                        return NSItemProvider(item: item.id.uuidString as NSString, typeIdentifier: "com.icantmiss.sequentialitem")
                                    }
                                    .onDrop(of: ["com.icantmiss.sequentialitem"], delegate: SequentialDropDelegate(item: item, items: $sequenceItems, draggedItem: $draggedItem, onReorder: {
                                        Task { await saveSequenceChanges() }
                                    }))
                                }
                            }

                            // Add Memory button
                            Button {
                                showingPicker = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus")
                                        .font(.caption.bold())
                                    Text("Add Memory")
                                        .font(.caption.bold())
                                }
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                                        .foregroundStyle(Color.secondary.opacity(0.4))
                                )
                            }
                            .buttonStyle(.plain)

                            Text("Drag to reorder")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            // Collapsed view - show sequence preview
                            let sequenceID = config.sequenceID
                            let sequenceMemories = memoryLookup.values.filter { memory in
                                memory.triggers.contains { t in
                                    t.type == .sequential && t.sequential?.sequenceID == sequenceID
                                }
                            }.sorted { lhs, rhs in
                                let lhsIndex = lhs.triggers.first(where: { $0.type == .sequential })?.sequential?.stepIndex ?? 0
                                let rhsIndex = rhs.triggers.first(where: { $0.type == .sequential })?.sequential?.stepIndex ?? 0
                                return lhsIndex < rhsIndex
                            }

                            if !sequenceMemories.isEmpty {
                                ForEach(Array(sequenceMemories.enumerated()), id: \.element.id) { index, memory in
                                    HStack(spacing: 8) {
                                        Text("\(index + 1)")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundStyle(.secondary)
                                            .frame(width: 20)

                                        Text(memory.title.isEmpty ? "Untitled" : memory.title)
                                            .font(.subheadline)
                                            .lineLimit(1)
                                            .foregroundStyle(.primary)

                                        if memory.id == viewModel.editingMemoryID {
                                            Text("(current)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .sheet(isPresented: $showingPicker) {
            SequentialMemoryPickerSheet(
                viewModel: viewModel,
                excludedMemoryIDs: Set(sequenceItems.map(\.id)),
                onSelect: { memory in
                    let item = SequentialItem(id: memory.id, title: memory.title, isCurrent: false)
                    sequenceItems.append(item)
                    Task { await saveSequenceChanges() }
                }
            )
        }
        .onAppear {
            loadExistingConfiguration()
        }
    }

    private func loadExistingConfiguration() {
        var items: [SequentialItem] = []
        let currentID = viewModel.editingMemoryID ?? UUID()

        if let seqInfo = viewModel.sequentialTrigger?.sequential {
            let sequenceID = seqInfo.sequenceID
            let allMemories = viewModel.environment.memoryService.memories.filter { memory in
                memory.triggers.contains { t in
                    t.type == .sequential && t.sequential?.sequenceID == sequenceID
                }
            }

            items = allMemories.map { mem in
                SequentialItem(id: mem.id, title: mem.title, isCurrent: mem.id == viewModel.editingMemoryID)
            }

            items.sort { lhs, rhs in
                let lhsIndex = allMemories.first(where: { $0.id == lhs.id })?.triggers.first(where: { $0.type == .sequential })?.sequential?.stepIndex ?? 0
                let rhsIndex = allMemories.first(where: { $0.id == rhs.id })?.triggers.first(where: { $0.type == .sequential })?.sequential?.stepIndex ?? 0
                return lhsIndex < rhsIndex
            }
        }

        if !items.contains(where: { $0.isCurrent }) {
            let title = viewModel.title.isEmpty ? "New Memory" : viewModel.title
            let current = SequentialItem(id: currentID, title: title, isCurrent: true)
            items.append(current)
        }

        self.sequenceItems = items
    }

    private func saveSequenceChanges() async {
        let sequenceID = viewModel.sequentialTrigger?.sequential?.sequenceID ?? UUID()

        for (index, item) in sequenceItems.enumerated() {
            if item.isCurrent {
                viewModel.updateSequentialTrigger(sequenceID: sequenceID, stepIndex: index)
            } else {
                if let memory = viewModel.environment.memoryService.memory(id: item.id) {
                    await updateMemoryTrigger(memory, sequenceID: sequenceID, index: index)
                }
            }
        }

        // Handle removed items
        let service = viewModel.environment.memoryService
        let staleMemories = service.memories.filter { mem in
            mem.triggers.contains { $0.type == .sequential && $0.sequential?.sequenceID == sequenceID } &&
            !sequenceItems.contains { $0.id == mem.id }
        }

        for mem in staleMemories {
            await removeSequentialTrigger(from: mem)
        }
    }

    private func updateMemoryTrigger(_ memory: MemoryModel, sequenceID: UUID, index: Int) async {
        var triggers = memory.triggers
        let newSeq = MemoryTriggerModel.TriggerSequential(sequenceID: sequenceID, stepIndex: index)

        if let idx = triggers.firstIndex(where: { $0.type == .sequential }) {
            triggers[idx].sequential = newSeq
        } else {
            let t = MemoryTriggerModel(
                id: UUID(),
                type: .sequential,
                weekdayMask: 0,
                isActive: true,
                sequential: newSeq,
                spacedStage: 0,
                ignoreCount: 0
            )
            triggers.append(t)
        }

        let draft = MemoryDraft.from(model: memory, withTriggers: triggers)
        _ = try? await viewModel.environment.memoryService.updateMemory(from: draft)
    }

    private func removeSequentialTrigger(from memory: MemoryModel) async {
        var triggers = memory.triggers
        triggers.removeAll { $0.type == .sequential }
        let draft = MemoryDraft.from(model: memory, withTriggers: triggers)
        _ = try? await viewModel.environment.memoryService.updateMemory(from: draft)
    }
}

private struct SequentialItemRow: View {
    let index: Int
    let item: SequentialItem
    let currentMemoryID: UUID?
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("\(index + 1)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                if item.isCurrent {
                    Text("Current Memory")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
                Text(item.title.isEmpty ? "Untitled" : item.title)
                    .font(.subheadline)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
            }

            Spacer()

            if !item.isCurrent {
                Button {
                    withAnimation { onDelete() }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.tertiarySystemBackground))
        )
    }
}

private struct SequentialDropDelegate: DropDelegate {
    let item: SequentialItem
    @Binding var items: [SequentialItem]
    @Binding var draggedItem: SequentialItem?
    let onReorder: () -> Void

    func dropUpdated(info: DropInfo) -> DropProposal {
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        onReorder()
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggedItem = draggedItem else { return }
        guard draggedItem.id != item.id else { return }

        if let from = items.firstIndex(of: draggedItem),
           let to = items.firstIndex(of: item) {
            if from != to {
                withAnimation {
                    items.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
                }
            }
        }
    }
}

fileprivate struct SequentialItem: Identifiable, Equatable {
    let id: UUID
    let title: String
    var isCurrent: Bool
}

fileprivate extension MemoryDraft {
    static func from(model: MemoryModel, withTriggers triggers: [MemoryTriggerModel]) -> MemoryDraft {
        MemoryDraft(
            id: model.id,
            title: model.title,
            status: model.status,
            isPinned: model.isPinned,
            dueDate: model.dueDate,
            spaceID: model.space?.id,
            triggers: triggers,
            note: model.note,
            checkItems: model.checkItems.map { CheckItemDraft(id: $0.id, title: $0.title, detail: $0.detail ?? "", isCompleted: $0.isCompleted, sortOrder: $0.sortOrder, createdAt: $0.createdAt, completedAt: $0.completedAt) },
            photoAttachmentIDs: model.photoAttachmentIDs,
            linkAttachmentIDs: model.linkAttachmentIDs,
            audioAttachmentIDs: model.audioAttachmentIDs,
            fileAttachmentIDs: model.fileAttachmentIDs,
            attachments: model.attachments,
            autoCompleteOnChecklistCompletion: model.autoCompleteOnChecklistCompletion
        )
    }
}


// MARK: - Trigger Section Header

private struct TriggerSectionHeader: View {
    let iconName: String
    let title: String
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .frame(width: 24)

            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)

            Spacer()

            Menu {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 24, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 24))
    }
}

// MARK: - Scheduled Trigger Empty Form

private struct ScheduledTriggerEmptyForm: View {
    @ObservedObject var viewModel: MemoryEditorViewModel
    let onCancel: () -> Void
    let onSave: () -> Void

    @State private var fireDate: Date = Date().addingTimeInterval(3600)
    @State private var timeOfDayType: TimeOfDayType = .specificTime
    @State private var repeatType: RepeatType = .never
    @State private var showCustomRepeatSheet: Bool = false
    @State private var customRepeatType: CustomRepeatType = .weekly
    @State private var selectedWeekdays: Set<Int> = []
    @State private var selectedMonthDays: Set<Int> = []

    var body: some View {
        VStack(spacing: 0) {
            // Header
            TriggerEmptyFormHeader(
                iconName: "clock.badge",
                title: "Date & Time",
                onCancel: onCancel,
                onSave: saveAndClose
            )

            VStack(spacing: 12) {
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
                    ForEach(RepeatType.allCases) { type in
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
            .padding(16)
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .sheet(isPresented: $showCustomRepeatSheet) {
            CustomRepeatSheet(
                customRepeatType: $customRepeatType,
                selectedWeekdays: $selectedWeekdays,
                selectedMonthDays: $selectedMonthDays
            )
        }
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

    private func saveAndClose() {
        var adjustedFireDate = fireDate
        if timeOfDayType == .allDay {
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
                recurrence = RecurrenceRule(frequency: .monthly, interval: 1)
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

        viewModel.setScheduledTrigger(
            fireDate: adjustedFireDate,
            recurrence: recurrence,
            weekdaySelection: weekdaySelection,
            referenceTime: adjustedFireDate,
            isAllDay: timeOfDayType == .allDay
        )
        onSave()
    }
}

// MARK: - Person Trigger Empty Form

private struct PersonTriggerEmptyForm: View {
    @ObservedObject var viewModel: MemoryEditorViewModel
    let onCancel: () -> Void
    let onSave: () -> Void

    @State private var name: String = ""
    @State private var contactIdentifier: String = ""
    @State private var showContactPicker = false
    @State private var showAccessDeniedAlert = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            TriggerEmptyFormHeader(
                iconName: "person.crop.circle.fill",
                title: "Person",
                onCancel: onCancel,
                onSave: saveAndClose,
                isSaveDisabled: name.trimmingCharacters(in: .whitespaces).isEmpty
            )

            VStack(spacing: 12) {
                HStack {
                    TextField("Name", text: $name)
                        .textFieldStyle(.plain)
                    Button {
                        Task { await requestContactsAndShow() }
                    } label: {
                        Image(systemName: "person.crop.circle.badge.plus")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Pick from contacts")
                }

                if !contactIdentifier.isEmpty {
                    Label("Contact linked", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            .padding(16)
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .sheet(isPresented: $showContactPicker) {
            ContactPickerView { selectedName, identifier in
                name = selectedName
                contactIdentifier = identifier ?? ""
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

    private func saveAndClose() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        viewModel.addPersonTrigger(
            name: trimmedName,
            identifier: contactIdentifier.isEmpty ? nil : contactIdentifier
        )
        onSave()
    }

    private func requestContactsAndShow() async {
        let status = ContactAccessHelper.checkAuthorizationStatus()
        switch status {
        case .authorized, .limited:
            await MainActor.run {
                showContactPicker = true
            }
        case .notDetermined:
            let granted = await ContactAccessHelper.requestAccess()
            await MainActor.run {
                if granted {
                    showContactPicker = true
                } else {
                    showAccessDeniedAlert = true
                }
            }
        case .denied, .restricted:
            await MainActor.run {
                showAccessDeniedAlert = true
            }
        @unknown default:
            await MainActor.run {
                showAccessDeniedAlert = true
            }
        }
    }
}

// MARK: - Location Trigger Empty Form

private struct LocationTriggerEmptyForm: View {
    @ObservedObject var viewModel: MemoryEditorViewModel
    let onCancel: () -> Void
    let onSave: () -> Void

    @StateObject private var searchModel = LocationSearchViewModel()
    @StateObject private var geocodingModel = LocationGeocoder()
    @State private var region: MKCoordinateRegion
    @State private var mapCameraPosition: MapCameraPosition
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var selectedName = ""
    @State private var event: LocationEvent = .onEntry
    @State private var isMapExpanded = false
    @State private var isCameraAdjusting = false
    @State private var geocodeTask: Task<Void, Never>?
    @State private var cameraCooldownTask: Task<Void, Never>?
    @State private var isSearching = false
    @FocusState private var isSearchFieldFocused: Bool

    private let defaultRadius: Double = 200
    private let expandedSuggestionBottomPadding: CGFloat = 120

    init(viewModel: MemoryEditorViewModel, onCancel: @escaping () -> Void, onSave: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onCancel = onCancel
        self.onSave = onSave

        let initialRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.00902),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )

        _region = State(initialValue: initialRegion)
        _mapCameraPosition = State(initialValue: .region(initialRegion))
        _selectedCoordinate = State(initialValue: nil)
    }

    var body: some View {
        VStack(spacing: 0) {
            TriggerEmptyFormHeader(
                iconName: "mappin.circle.fill",
                title: "Location",
                onCancel: onCancel,
                onSave: saveAndClose,
                isSaveDisabled: selectedCoordinate == nil
            )

            VStack(spacing: 12) {
                // Map preview
                LocationPickerView.MapSection(
                    onExpand: { isMapExpanded = true },
                    mapPreview: { mapPreviewContent }
                )

                // Location info
                if selectedCoordinate != nil {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(resolvedLocationName)
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Text(coordinateSummary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                } else {
                    Text("Tap the map to select a location")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Event picker
                Picker("Remind when", selection: $event) {
                    ForEach(LocationEvent.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(16)
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .fullScreenCover(isPresented: $isMapExpanded) {
            expandedMapView
        }
        .onReceive(searchModel.$isSearching) { value in
            withAnimation(.easeInOut(duration: 0.2)) {
                isSearching = value
            }
        }
        .onAppear {
            if selectedCoordinate == nil {
                let center = region.center
                updateSelection(to: center, resetName: true, updateCamera: true)
            }
        }
        .onDisappear {
            geocodeTask?.cancel()
            cameraCooldownTask?.cancel()
        }
    }

    private var mapPreviewContent: some View {
        MapContainer(
            allowsSelection: false,
            mapCameraPosition: $mapCameraPosition,
            region: $region,
            selectedCoordinate: $selectedCoordinate,
            defaultRadius: defaultRadius,
            resolvedLocationName: resolvedLocationName,
            onCameraChange: { _ in },
            onCoordinateSelected: { _ in }
        )
        .allowsHitTesting(false)
        .environmentObject(geocodingModel)
    }

    private var expandedMapView: some View {
        LocationPickerView.ExpandedMapScreen(
            searchModel: searchModel,
            suggestionBottomPadding: expandedSuggestionBottomPadding,
            mapContent: { mapView(allowsSelection: true) },
            selectionOverlay: { mapSelectionOverlay },
            centerIndicator: { mapCenterIndicator },
            searchBar: { expandedSearchBar },
            suggestionPanel: { expandedSuggestionPanel },
            confirmationPanel: { expandedConfirmationPanel },
            searchFieldFocus: $isSearchFieldFocused,
            onDismiss: { isMapExpanded = false }
        )
    }

    private func mapView(allowsSelection: Bool) -> some View {
        MapContainer(
            allowsSelection: allowsSelection,
            mapCameraPosition: $mapCameraPosition,
            region: $region,
            selectedCoordinate: $selectedCoordinate,
            defaultRadius: defaultRadius,
            resolvedLocationName: resolvedLocationName,
            onCameraChange: handleCameraRegionChange(to:),
            onCoordinateSelected: { coordinate in
                updateSelection(to: coordinate, resetName: true, updateCamera: false, shouldGeocode: true)
            }
        )
        .environmentObject(geocodingModel)
    }

    private var mapSelectionOverlay: some View {
        HStack {
            Text("Drag the map to position the pin precisely.")
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(Color(.systemBackground), in: Capsule())
            Spacer()
        }
        .padding(12)
        .allowsHitTesting(false)
    }

    private var mapCenterIndicator: some View {
        VStack {
            Spacer()
            VStack(spacing: 4) {
                Image(systemName: geocodingModel.isResolving ? "mappin.circle" : "mappin.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.primary)
                    .shadow(color: Color.black.opacity(0.25), radius: 8, y: 6)
                Circle()
                    .fill(Color.primary.opacity(0.25))
                    .frame(width: 18, height: 18)
                    .overlay(
                        Circle()
                            .fill(Color.primary)
                            .frame(width: 6, height: 6)
                    )
            }
            .offset(y: -28)
            Spacer()
        }
        .allowsHitTesting(false)
    }

    private var expandedSearchBar: some View {
        LocationPickerView.ExpandedSearchBar(
            query: $searchModel.query,
            isSearching: isSearching,
            onClearQuery: { searchModel.query = ""; searchModel.suggestions = [] }
        )
    }

    private var expandedSuggestionPanel: some View {
        LocationPickerView.ExpandedSuggestionPanel(
            suggestions: searchModel.suggestions,
            onSuggestionSelected: { suggestion in
                Task { await selectSuggestion(suggestion) }
            }
        )
    }

    private var expandedConfirmationPanel: some View {
        LocationPickerView.ExpandedConfirmationPanel(
            resolvedLocationName: resolvedLocationName,
            coordinateSummary: coordinateSummary,
            isResolving: geocodingModel.isResolving,
            event: $event,
            onUseLocation: { isMapExpanded = false }
        )
    }

    private var resolvedLocationName: String {
        guard selectedCoordinate != nil else { return "Select a place on the map" }
        if geocodingModel.isResolving && selectedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Resolving address..."
        }
        let trimmed = selectedName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Pinned Location" : trimmed
    }

    private var coordinateSummary: String {
        guard let coordinate = selectedCoordinate else { return "Drag the map to choose a location." }
        return String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude)
    }

    private func handleCameraRegionChange(to updatedRegion: MKCoordinateRegion) {
        guard !isCameraAdjusting else { return }
        let coordinate = updatedRegion.center
        if selectedCoordinate?.isApproximatelyEqual(to: coordinate) == true { return }
        selectedName = ""
        selectedCoordinate = coordinate
        scheduleReverseGeocode(for: coordinate)
    }

    private func updateSelection(to coordinate: CLLocationCoordinate2D,
                                 span overrideSpan: MKCoordinateSpan? = nil,
                                 name: String? = nil,
                                 resetName: Bool = true,
                                 updateCamera: Bool = false,
                                 shouldGeocode: Bool = true) {
        let targetSpan = sanitizedSpan(overrideSpan ?? region.span)
        let updatedRegion = MKCoordinateRegion(center: coordinate, span: targetSpan)

        selectedCoordinate = coordinate
        region = updatedRegion

        if updateCamera {
            isCameraAdjusting = true
            mapCameraPosition = .region(updatedRegion)
            cameraCooldownTask?.cancel()
            cameraCooldownTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 250_000_000)
                isCameraAdjusting = false
            }
        }

        if let providedName = name {
            selectedName = providedName
        } else if resetName {
            selectedName = ""
        }

        if shouldGeocode {
            scheduleReverseGeocode(for: coordinate, force: name == nil)
        }
    }

    private func scheduleReverseGeocode(for coordinate: CLLocationCoordinate2D, force: Bool = false) {
        geocodeTask?.cancel()
        geocodeTask = Task { @MainActor in
            if !force { try? await Task.sleep(nanoseconds: 350_000_000) }
            guard !Task.isCancelled else { return }
            if let resolved = await geocodingModel.resolveName(for: coordinate) {
                guard !Task.isCancelled else { return }
                if let currentCoordinate = selectedCoordinate, currentCoordinate.isApproximatelyEqual(to: coordinate) {
                    selectedName = resolved
                }
            } else if selectedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                selectedName = "Pinned Location"
            }
        }
    }

    private func selectSuggestion(_ suggestion: MKLocalSearchCompletion) async {
        if let result = await searchModel.search(for: suggestion) {
            await MainActor.run {
                let resolvedName = result.name ?? suggestion.title
                let coordinate = result.location.coordinate
                updateSelection(to: coordinate, name: resolvedName, resetName: false, updateCamera: true, shouldGeocode: false)
                searchModel.query = suggestion.title
                withAnimation(.easeInOut(duration: 0.2)) { searchModel.suggestions = [] }
                isSearchFieldFocused = false
            }
        }
    }

    private func sanitizedSpan(_ span: MKCoordinateSpan) -> MKCoordinateSpan {
        let latitude = span.latitudeDelta > 0 ? span.latitudeDelta : 0.01
        let longitude = span.longitudeDelta > 0 ? span.longitudeDelta : 0.01
        return MKCoordinateSpan(latitudeDelta: latitude, longitudeDelta: longitude)
    }

    private func saveAndClose() {
        guard let coordinate = selectedCoordinate else { return }
        let name = resolvedLocationName
        viewModel.addLocationTrigger(
            name: name,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            radius: defaultRadius,
            event: event
        )
        onSave()
    }
}

// MARK: - Sequential Trigger Empty Form

private struct SequentialTriggerEmptyForm: View {
    @ObservedObject var viewModel: MemoryEditorViewModel
    let onCancel: () -> Void
    let onSave: () -> Void

    @State private var sequenceItems: [SequentialItem] = []
    @State private var showingPicker = false
    @State private var draggedItem: SequentialItem?

    var body: some View {
        VStack(spacing: 0) {
            TriggerEmptyFormHeader(
                iconName: "arrowshape.turn.up.right.circle",
                title: "Sequence",
                onCancel: onCancel,
                onSave: saveAndClose,
                isSaveDisabled: sequenceItems.count < 2
            )

            VStack(spacing: 12) {
                // Description
                Text("Create a sequence of memories that will be triggered in order.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Drag-and-drop list
                if !sequenceItems.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(sequenceItems) { item in
                            SequentialItemRow(
                                index: sequenceItems.firstIndex(of: item) ?? 0,
                                item: item,
                                currentMemoryID: viewModel.editingMemoryID,
                                onDelete: {
                                    if !item.isCurrent, let idx = sequenceItems.firstIndex(of: item) {
                                        withAnimation { _ = sequenceItems.remove(at: idx) }
                                    }
                                }
                            )
                            .onDrag {
                                draggedItem = item
                                return NSItemProvider(item: item.id.uuidString as NSString, typeIdentifier: "com.icantmiss.sequentialitem")
                            }
                            .onDrop(of: ["com.icantmiss.sequentialitem"], delegate: SequentialDropDelegate(item: item, items: $sequenceItems, draggedItem: $draggedItem, onReorder: {}))
                        }
                    }

                    Text("Drag to reorder")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                // Add Memory button
                Button {
                    showingPicker = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.caption.bold())
                        Text("Add Memory")
                            .font(.caption.bold())
                    }
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                            .foregroundStyle(Color.secondary.opacity(0.4))
                    )
                }
                .buttonStyle(.plain)

                if sequenceItems.count < 2 {
                    Text("Add at least 2 memories to create a sequence")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding(16)
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .sheet(isPresented: $showingPicker) {
            SequentialMemoryPickerSheet(
                viewModel: viewModel,
                excludedMemoryIDs: Set(sequenceItems.map(\.id)),
                onSelect: { memory in
                    let item = SequentialItem(id: memory.id, title: memory.title, isCurrent: false)
                    sequenceItems.append(item)
                }
            )
        }
        .onAppear {
            loadCurrentMemory()
        }
    }

    private func loadCurrentMemory() {
        let currentID = viewModel.editingMemoryID ?? UUID()
        let title = viewModel.title.isEmpty ? "New Memory" : viewModel.title
        let current = SequentialItem(id: currentID, title: title, isCurrent: true)
        sequenceItems = [current]
    }

    private func saveAndClose() {
        guard sequenceItems.count >= 2 else { return }

        let sequenceID = UUID()

        Task {
            for (index, item) in sequenceItems.enumerated() {
                if item.isCurrent {
                    viewModel.updateSequentialTrigger(sequenceID: sequenceID, stepIndex: index)
                } else {
                    if let memory = viewModel.environment.memoryService.memory(id: item.id) {
                        await updateMemoryTrigger(memory, sequenceID: sequenceID, index: index)
                    }
                }
            }

            await MainActor.run {
                onSave()
            }
        }
    }

    private func updateMemoryTrigger(_ memory: MemoryModel, sequenceID: UUID, index: Int) async {
        var triggers = memory.triggers
        let newSeq = MemoryTriggerModel.TriggerSequential(sequenceID: sequenceID, stepIndex: index)

        if let idx = triggers.firstIndex(where: { $0.type == .sequential }) {
            triggers[idx].sequential = newSeq
        } else {
            let t = MemoryTriggerModel(
                id: UUID(),
                type: .sequential,
                weekdayMask: 0,
                isActive: true,
                sequential: newSeq,
                spacedStage: 0,
                ignoreCount: 0
            )
            triggers.append(t)
        }

        let draft = MemoryDraft.from(model: memory, withTriggers: triggers)
        _ = try? await viewModel.environment.memoryService.updateMemory(from: draft)
    }
}

// MARK: - Trigger Empty Form Header


private struct TriggerEmptyFormHeader: View {
    let iconName: String
    let title: String
    let onCancel: () -> Void
    let onSave: () -> Void
    var isSaveDisabled: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            Button {
                onCancel()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            Image(systemName: iconName)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .frame(width: 24)

            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)

            Spacer()

            Button {
                onSave()
            } label: {
                Image(systemName: "checkmark")
                    .font(.caption.bold())
                    .foregroundStyle(isSaveDisabled ? .tertiary : .primary)
            }
            .disabled(isSaveDisabled)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 24, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 24))
    }
}
