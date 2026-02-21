import SwiftUI
import Contacts
import UIKit
import MapKit
import CoreLocation
import UniformTypeIdentifiers

struct TriggersCard: View {
    @ObservedObject var viewModel: MemoryEditorViewModel
    var isEditable: Bool = true

    @State private var showGeofenceLimitAlert = false
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            scheduleSection
            locationSection
        }
    }

    // MARK: - Schedule Section

    @ViewBuilder
    private var scheduleSection: some View {
        if isEditable || viewModel.hasScheduleTrigger {
            VStack(spacing: 0) {
                if isEditable {
                    triggerToggleHeader(
                        title: "Schedule",
                        icon: "bell.fill",
                        isOn: scheduleToggleBinding
                    )
                }

                if viewModel.hasScheduleTrigger {
                    if isEditable {
                        Divider().padding(.horizontal, 16)
                    }
                    ScheduledTriggerInlineForm(
                        viewModel: viewModel,
                        isEditable: isEditable
                    )
                }
            }
            .cardStyle(cornerRadius: 24)
        }
    }

    // MARK: - Location Section

    @ViewBuilder
    private var locationSection: some View {
        if isEditable || viewModel.hasLocationTrigger {
            VStack(spacing: 0) {
                if isEditable {
                    triggerToggleHeader(
                        title: "Location",
                        icon: "location.fill",
                        isOn: locationToggleBinding
                    )
                }

                if viewModel.hasLocationTrigger {
                    if isEditable {
                        Divider().padding(.horizontal, 16)
                    }
                    LocationTriggerInlineForm(
                        viewModel: viewModel,
                        isEditable: isEditable
                    )
                }
            }
            .cardStyle(cornerRadius: 24)
            .alert("Geofence Limit Reached", isPresented: $showGeofenceLimitAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("You've reached the maximum of \(LocationTriggerExecutor.maxGeofences) location reminders. Remove a location reminder from another memory to add a new one.")
            }
        }
    }

    // MARK: - Toggle Header

    private func triggerToggleHeader(title: String, icon: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.body)
                .fontWeight(.medium)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Toggle Bindings

    private var scheduleToggleBinding: Binding<Bool> {
        Binding(
            get: { viewModel.hasScheduleTrigger },
            set: { newValue in
                withAnimation(.easeInOut(duration: 0.3)) {
                    if newValue {
                        createDefaultScheduleTrigger()
                    } else {
                        viewModel.removeScheduleConfig()
                    }
                }
            }
        )
    }

    private var locationToggleBinding: Binding<Bool> {
        Binding(
            get: { viewModel.hasLocationTrigger },
            set: { newValue in
                withAnimation(.easeInOut(duration: 0.3)) {
                    if newValue {
                        if viewModel.isGeofenceLimitReached() {
                            showGeofenceLimitAlert = true
                            return
                        }
                        createDefaultLocationTrigger()
                    } else {
                        viewModel.removeLocationConfig()
                    }
                }
            }
        )
    }

    // MARK: - Helper Functions

    private func createDefaultScheduleTrigger() {
        feedbackGenerator.impactOccurred()
        let fireDate = Date().addingTimeInterval(3600) // 1 hour from now
        viewModel.setScheduleConfig(
            fireDate: fireDate,
            recurrence: nil,
            weekdaySelection: [],
            referenceTime: fireDate,
            isAllDay: false
        )
    }

    private func createDefaultLocationTrigger() {
        feedbackGenerator.impactOccurred()
        let fallback = CLLocationManager().location?.coordinate
            ?? CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.00902)
        viewModel.setLocationConfig(
            name: "Select a location",
            latitude: fallback.latitude,
            longitude: fallback.longitude,
            radius: 200,
            event: .onEntry
        )
    }
}

// MARK: - Scheduled Trigger Inline Form

private struct ScheduledTriggerInlineForm: View {
    @ObservedObject var viewModel: MemoryEditorViewModel
    var isEditable: Bool

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

    init(viewModel: MemoryEditorViewModel, isEditable: Bool) {
        self.viewModel = viewModel
        self.isEditable = isEditable

        let scheduleConfig = viewModel.scheduleConfig
        let defaultDate = scheduleConfig?.fireDate ?? Date().addingTimeInterval(3600)
        _fireDate = State(initialValue: defaultDate)

        let detectedTimeOfDay: TimeOfDayType = scheduleConfig?.isAllDay == true ? .allDay : .specificTime
        _timeOfDayType = State(initialValue: detectedTimeOfDay)

        let hasRecurrence = scheduleConfig?.recurrenceRule != nil || (scheduleConfig?.weekdayMask ?? 0) != 0
        _isRepeating = State(initialValue: hasRecurrence)

        let existingRule = scheduleConfig?.recurrenceRule
        _frequency = State(initialValue: existingRule?.frequency ?? .daily)
        _interval = State(initialValue: existingRule?.interval ?? 1)

        let detectedEndType = scheduleConfig?.recurrenceEndType ?? .never
        _endType = State(initialValue: detectedEndType)
        _endDate = State(initialValue: existingRule?.endDate ?? Calendar.current.date(byAdding: .month, value: 1, to: defaultDate) ?? defaultDate)
        _occurrenceCount = State(initialValue: existingRule?.occurrenceCount ?? 5)

        let initialWeekdays = Self.weekdaySet(from: scheduleConfig?.weekdayMask ?? 0)
        _selectedWeekdays = State(initialValue: initialWeekdays)
        _selectedMonthDays = State(initialValue: [])
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {

                // Time of Day Row
                inlineRow {
                    Text("Time")
                        .font(.body)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Menu {
                        ForEach(TimeOfDayType.allCases, id: \.self) { type in
                            Button {
                                timeOfDayType = type
                            } label: {
                                if timeOfDayType == type {
                                    Label(type.rawValue, systemImage: "checkmark")
                                } else {
                                    Text(type.rawValue)
                                }
                            }
                        }
                    } label: {
                        capsuleLabel(timeOfDayType.rawValue)
                    }
                    .tint(.primary)
                }

                Divider()

                // Date & Time Row
                inlineRow {
                    Text(timeOfDayType == .specificTime ? "Date & Time" : "Date")
                        .font(.body)
                        .foregroundStyle(.secondary)

                    Spacer()

                    if timeOfDayType == .specificTime {
                        DatePicker("", selection: $fireDate, displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                    } else {
                        DatePicker("", selection: $fireDate, displayedComponents: [.date])
                            .labelsHidden()
                    }
                }

                Divider()

                // Repeat Row
                inlineRow {
                    Text("Repeat")
                        .font(.body)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Menu {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { isRepeating = false }
                        } label: {
                            if !isRepeating {
                                Label("Never", systemImage: "checkmark")
                            } else {
                                Text("Never")
                            }
                        }

                        ForEach(RecurrenceFrequency.userVisible, id: \.self) { freq in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isRepeating = true
                                    frequency = freq
                                }
                            } label: {
                                if isRepeating && frequency == freq {
                                    Label(freq.displayName, systemImage: "checkmark")
                                } else {
                                    Text(freq.displayName)
                                }
                            }
                        }
                    } label: {
                        capsuleLabel(isRepeating ? frequency.displayName : "Never")
                    }
                    .tint(.primary)
                }

                // Expanded repeat options (when repeating is ON)
                if isRepeating {
                    Divider()

                    // Interval Row
                    inlineRow {
                        Text("Every")
                            .font(.body)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Stepper(value: $interval, in: 1...999) {
                            HStack(spacing: 4) {
                                Text("\(interval)")
                                    .fontWeight(.semibold)
                                Text(interval == 1 ? frequency.singularUnitLabel : frequency.unitLabel)
                            }
                            .font(.body)
                        }
                    }

                    // Weekday selection for weekly
                    if frequency == .weekly {
                        Divider()
                        MemoryWeekdaySelectionView(selectedDays: $selectedWeekdays)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                    }

                    // Month day selection for monthly
                    if frequency == .monthly {
                        Divider()
                        MonthDaySelectionView(selectedDays: $selectedMonthDays)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                    }

                    Divider()

                    // End condition Row
                    inlineRow {
                        Text("Ends")
                            .font(.body)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Menu {
                            ForEach(RecurrenceEndType.allCases) { type in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) { endType = type }
                                } label: {
                                    if endType == type {
                                        Label(type.label, systemImage: "checkmark")
                                    } else {
                                        Text(type.label)
                                    }
                                }
                            }
                        } label: {
                            capsuleLabel(endType.label)
                        }
                        .tint(.primary)
                    }

                    // Until Date picker
                    if endType == .untilDate {
                        Divider()
                        inlineRow {
                            Text("End Date")
                                .font(.body)
                                .foregroundStyle(.secondary)

                            Spacer()

                            DatePicker("", selection: $endDate, in: fireDate..., displayedComponents: [.date])
                                .labelsHidden()
                        }
                    }

                    // Occurrence count stepper
                    if endType == .afterCount {
                        Divider()
                        inlineRow {
                            Stepper(value: $occurrenceCount, in: 1...999) {
                                HStack(spacing: 4) {
                                    Text("After")
                                        .foregroundStyle(.secondary)
                                    Text("\(occurrenceCount)")
                                        .fontWeight(.semibold)
                                    Text(occurrenceCount == 1 ? "time" : "times")
                                }
                                .font(.body)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .disabled(!isEditable)
        }
        .onChange(of: fireDate) { _, _ in applyChanges() }
        .onChange(of: timeOfDayType) { _, _ in applyChanges() }
        .onChange(of: isRepeating) { _, _ in applyChanges() }
        .onChange(of: frequency) { _, _ in applyChanges() }
        .onChange(of: interval) { _, _ in applyChanges() }
        .onChange(of: endType) { _, _ in applyChanges() }
        .onChange(of: endDate) { _, _ in applyChanges() }
        .onChange(of: occurrenceCount) { _, _ in applyChanges() }
        .onChange(of: selectedWeekdays) { _, _ in applyChanges() }
        .onChange(of: selectedMonthDays) { _, _ in applyChanges() }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func inlineRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack { content() }
            .padding(.vertical, 10)
    }

    private func capsuleLabel(_ text: String) -> some View {
        Text(text)
            .font(.body)
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.Theme.elementBackground)
            )
    }

    private func applyChanges() {
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
    var isEditable: Bool

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
    @FocusState private var isSearchFieldFocused: Bool

    private let defaultRadius: Double = 200

    private var existingConfig: LocationConfigDraft? {
        viewModel.locationConfig
    }

    init(viewModel: MemoryEditorViewModel, isEditable: Bool) {
        self.viewModel = viewModel
        self.isEditable = isEditable

        let config = viewModel.locationConfig
        let userCoord = CLLocationManager().location?.coordinate
        let lat = config?.latitude ?? userCoord?.latitude ?? 37.3349
        let lon = config?.longitude ?? userCoord?.longitude ?? -122.00902
        let name = config?.name ?? ""
        let eventType = config?.event ?? .onEntry

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
            // Row 1: Location name — tap opens full-screen map
            Button {
                if let coordinate = selectedCoordinate {
                    mapCameraPosition = .region(MKCoordinateRegion(center: coordinate, span: region.span))
                }
                isMapExpanded = true
            } label: {
                HStack {
                    Text("Location")
                        .font(.body)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(resolvedLocationName)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if isEditable {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            Divider()

            // Row 2: Event picker
            HStack {
                Text("Remind")
                    .font(.body)
                    .foregroundStyle(.secondary)

                Spacer()

                Menu {
                    ForEach(LocationEvent.allCases, id: \.self) { option in
                        Button {
                            event = option
                        } label: {
                            if event == option {
                                Label(option.displayName, systemImage: "checkmark")
                            } else {
                                Text(option.displayName)
                            }
                        }
                    }
                } label: {
                    Text(event.displayName)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.Theme.elementBackground)
                        )
                }
                .tint(.primary)
            }
            .padding(.vertical, 10)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .disabled(!isEditable)
        .onChange(of: event) { _, _ in
            applyChanges()
        }
        .fullScreenCover(isPresented: $isMapExpanded) {
            expandedMapView
        }
        .onDisappear {
            geocodeTask?.cancel()
            cameraCooldownTask?.cancel()
        }
    }

    // MARK: - Expanded Map

    private var expandedMapView: some View {
        ExpandedMapScreen(
            searchModel: searchModel,
            event: $event,
            mapContent: { mapView(allowsSelection: true) },
            onSuggestionSelected: { suggestion in
                 Task { await selectSuggestion(suggestion) }
            },
            onConfirm: {
                applyChanges()
                isMapExpanded = false
            },
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

    // MARK: - Location Helpers

    private var resolvedLocationName: String {
        guard selectedCoordinate != nil else { return "Select a place on the map" }
        if geocodingModel.isResolving && selectedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Resolving address..."
        }
        let trimmed = selectedName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Pinned Location" : trimmed
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
                searchModel.query = suggestion.title
                withAnimation(.easeInOut(duration: 0.2)) { searchModel.suggestions = [] }
                updateSelection(to: coordinate, name: resolvedName, resetName: false, updateCamera: true, shouldGeocode: false)
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
        viewModel.setLocationConfig(
            name: name,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            radius: defaultRadius,
            event: event
        )
    }
}
