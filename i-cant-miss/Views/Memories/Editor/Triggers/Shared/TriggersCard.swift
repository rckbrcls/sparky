import SwiftUI
import Contacts
import UIKit
import MapKit
import UniformTypeIdentifiers

struct TriggersCard: View {
    @ObservedObject var viewModel: MemoryEditorViewModel
    let memoryLookup: [UUID: MemoryModel]
    var isEditable: Bool = true
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(spacing: 8) {
                // Scheduled Trigger - Inline Form (existing or empty)
                if hasScheduledTrigger {
                    ScheduledTriggerInlineForm(
                        viewModel: viewModel,
                        isEditable: isEditable,
                        onDelete: { removeTrigger(type: .scheduled) }
                    )
                }

                // Location Trigger - Inline Form
                if hasLocationTrigger {
                    LocationTriggerInlineForm(
                        viewModel: viewModel,
                        isEditable: isEditable,
                        onDelete: { removeTrigger(type: .location) }
                    )
                }



                // Sequential Trigger - Inline Form
                if hasSequentialTrigger {
                    SequentialTriggerInlineForm(
                        viewModel: viewModel,
                        memoryLookup: memoryLookup,
                        isEditable: isEditable,
                        onDelete: {
                            feedbackGenerator.impactOccurred()
                            viewModel.removeSequentialTrigger()
                        }
                    )
                }

                // Add trigger button (dashed border)
                if isEditable && !hasAnyTrigger {
                    addTriggerButton
                }
            }
        }
    }

    private var addTriggerButton: some View {
        Menu {
            if !hasScheduledTrigger {
                Button {
                    createDefaultScheduledTrigger()
                } label: {
                    Label("Date & Time", systemImage: "clock.badge")
                }
            }

            if !hasLocationTrigger {
                Button {
                    createDefaultLocationTrigger()
                } label: {
                    Label("Location", systemImage: "mappin.circle.fill")
                }
            }



            if !hasSequentialTrigger {
                Button {
                    createDefaultSequentialTrigger()
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
            .neutralButtonStyle()
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



    private var hasSequentialTrigger: Bool {
        return viewModel.sequentialTrigger?.sequential != nil
    }

    private var hasAnyTrigger: Bool {
        hasScheduledTrigger || hasLocationTrigger || hasSequentialTrigger
    }

    // MARK: - Helper Functions

    private func removeTrigger(type: MemoryTriggerType) {
        feedbackGenerator.impactOccurred()
        if let trigger = viewModel.triggers.first(where: { $0.type == type }) {
            viewModel.removeTrigger(id: trigger.id)
        }
    }

    private func createDefaultScheduledTrigger() {
        feedbackGenerator.impactOccurred()
        let fireDate = Date().addingTimeInterval(3600) // 1 hour from now
        viewModel.setScheduledTrigger(
            fireDate: fireDate,
            recurrence: nil,
            weekdaySelection: [],
            referenceTime: fireDate,
            isAllDay: false
        )
    }

    private func createDefaultLocationTrigger() {
        feedbackGenerator.impactOccurred()
        // Default to Apple Park coordinates
        viewModel.addLocationTrigger(
            name: "Select a location",
            latitude: 37.3349,
            longitude: -122.00902,
            radius: 200,
            event: .onEntry
        )
    }



    private func createDefaultSequentialTrigger() {
        feedbackGenerator.impactOccurred()
        viewModel.updateSequentialTrigger(sequenceID: UUID(), stepIndex: 0, startDate: Date(), currentStepIndex: 0)
    }
}

// MARK: - Scheduled Trigger Inline Form

private struct ScheduledTriggerInlineForm: View {
    @ObservedObject var viewModel: MemoryEditorViewModel
    var isEditable: Bool
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

    init(viewModel: MemoryEditorViewModel, isEditable: Bool, onDelete: @escaping () -> Void) {
        self.viewModel = viewModel
        self.isEditable = isEditable
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
            VStack(spacing: 0) {


                // Time of Day Row
                HStack {
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
                        Text(timeOfDayType.rawValue)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color(uiColor: .tertiarySystemFill))
                            )
                    }
                    .tint(.primary)
                }
                .padding(.vertical, 10)

                Divider()

                // Date & Time Row
                HStack {
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
                .padding(.vertical, 10)

                Divider()

                // Repeat Row
                HStack {
                    Text("Repeat")
                        .font(.body)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Menu {
                        ForEach(RepeatType.allCases) { type in
                            Button {
                                if type == .custom && repeatType == .custom {
                                    // Already custom, open sheet
                                    showCustomRepeatSheet = true
                                } else {
                                    repeatType = type
                                    if type == .custom {
                                        showCustomRepeatSheet = true
                                    }
                                }
                            } label: {
                                if repeatType == type {
                                    Label(type.rawValue, systemImage: "checkmark")
                                } else {
                                    Text(type.rawValue)
                                }
                            }
                        }
                    } label: {
                        Text(repeatType == .custom ? customRepeatSummary : repeatType.rawValue)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color(uiColor: .tertiarySystemFill))
                            )
                    }
                    .tint(.primary)
                }
                .padding(.vertical, 10)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .disabled(!isEditable)
        }
        .cardStyle(cornerRadius: 24)
        .contextMenu {
            if isEditable {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete Trigger", systemImage: "trash")
                }
            }
        }

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
    var isEditable: Bool
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


    private var existingTrigger: MemoryTriggerDraft? {
        viewModel.triggers.first(where: { $0.type == .location })
    }

    init(viewModel: MemoryEditorViewModel, isEditable: Bool, onDelete: @escaping () -> Void) {
        self.viewModel = viewModel
        self.isEditable = isEditable
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
            VStack(spacing: 12) {
                // Map preview
                LocationPickerView.MapSection(
                    onExpand: { if isEditable { isMapExpanded = true } },
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
                HStack {
                    Text("Remind")
                        .font(.body)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Menu {
                        ForEach(LocationEvent.allCases, id: \.self) { option in
                            Button {
                                if isEditable { event = option }
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
                                    .fill(Color(uiColor: .tertiarySystemFill))
                            )
                    }
                    .tint(.primary)
                }
                .onChange(of: event) { _, _ in
                    applyChanges()
                }
            }
            .padding(16)
        }
        .cardStyle(cornerRadius: 24)
        .contextMenu {
            if isEditable {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete Trigger", systemImage: "trash")
                }
            }
        }
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



// MARK: - Sequential Trigger Inline Form

private struct SequentialTriggerInlineForm: View {
    @ObservedObject var viewModel: MemoryEditorViewModel
    let memoryLookup: [UUID: MemoryModel]
    var isEditable: Bool
    let onDelete: () -> Void

    @State private var sequenceItems: [SequentialItem] = []
    @State private var showingPicker = false
    @State private var draggedItem: SequentialItem?
    @State private var sequenceStartDate: Date = Date()

    private var sequentialConfig: MemoryTriggerModel.TriggerSequential? {
        viewModel.sequentialTrigger?.sequential
    }

    private var currentStepIndex: Int {
        sequentialConfig?.currentStepIndex ?? 0
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                if sequentialConfig != nil {
                    VStack(alignment: .leading, spacing: 8) {

                        // Start Date Row
                        VStack(spacing: 0) {
                            HStack {
                                Text("Start Date")
                                    .font(.body)
                                    .foregroundStyle(.secondary)

                                Spacer()

                                DatePicker("", selection: $sequenceStartDate, displayedComponents: [.date])
                                    .labelsHidden()
                                    .disabled(!isEditable)
                            }
                            .padding(.vertical, 10)
                        }

                        Divider()
                            .padding(.bottom, 8)

                        // List of items
                        VStack(spacing: 8) {
                            ForEach(Array(sequenceItems.enumerated()), id: \.element.id) { index, item in
                                SequentialItemRow(
                                    item: item,
                                    currentMemoryID: viewModel.editingMemoryID,
                                    isEditable: isEditable,
                                    canMoveUp: index > 0,
                                    canMoveDown: index < sequenceItems.count - 1,
                                    onMoveUp: {
                                        if index > 0 {
                                            withAnimation {
                                                sequenceItems.swapAt(index, index - 1)
                                            }
                                            Task { await saveSequenceChanges() }
                                        }
                                    },
                                    onMoveDown: {
                                        if index < sequenceItems.count - 1 {
                                            withAnimation {
                                                sequenceItems.swapAt(index, index + 1)
                                            }
                                            Task { await saveSequenceChanges() }
                                        }
                                    },
                                    onDelete: {
                                        if !item.isCurrent, let idx = sequenceItems.firstIndex(of: item) {
                                            withAnimation { _ = sequenceItems.remove(at: idx) }
                                            Task { await saveSequenceChanges() }
                                        }
                                    }
                                )
                                .disabled(!isEditable)
                            }
                        }

                        // Add Memory button
                        if isEditable {
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
                                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                                        .foregroundStyle(Color.secondary.opacity(0.4))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(16)
        }
        .cardStyle(cornerRadius: 24)
        .contextMenu {
            if isEditable {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete Trigger", systemImage: "trash")
                }
            }
        }
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
        .onChange(of: sequenceStartDate) { _, _ in
            Task { await saveSequenceChanges() }
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

            // Load start date from sequence
            if let startDate = seqInfo.startDate {
                self.sequenceStartDate = startDate
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
        let currentStepIdx = viewModel.sequentialTrigger?.sequential?.currentStepIndex ?? 0

        for (index, item) in sequenceItems.enumerated() {
            if item.isCurrent {
                viewModel.updateSequentialTrigger(
                    sequenceID: sequenceID,
                    stepIndex: index,
                    startDate: sequenceStartDate,
                    currentStepIndex: currentStepIdx
                )
            } else {
                if let memory = viewModel.environment.memoryService.memory(id: item.id) {
                    await updateMemoryTrigger(memory, sequenceID: sequenceID, index: index, startDate: sequenceStartDate, currentStepIndex: currentStepIdx)
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

    private func updateMemoryTrigger(_ memory: MemoryModel, sequenceID: UUID, index: Int, startDate: Date, currentStepIndex: Int) async {
        var triggers = memory.triggers
        let newSeq = MemoryTriggerModel.TriggerSequential(
            sequenceID: sequenceID,
            stepIndex: index,
            startDate: startDate,
            currentStepIndex: currentStepIndex
        )

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
    let item: SequentialItem
    let currentMemoryID: UUID?
    let isEditable: Bool
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if isEditable {
                Menu {
                    if canMoveUp {
                        Button(action: onMoveUp) {
                            Label("Move Up", systemImage: "arrow.up")
                        }
                    }

                    if canMoveDown {
                        Button(action: onMoveDown) {
                            Label("Move Down", systemImage: "arrow.down")
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .frame(width: 30, height: 30)
                        .background(Color(uiColor: .secondarySystemFill))
                        .clipShape(Circle())
                }
                .menuStyle(.borderlessButton)
                .tint(.primary)
                .disabled(!canMoveUp && !canMoveDown)
            }



                Text(item.title.isEmpty ? "Untitled" : item.title)
                    .font(.subheadline)
                    .lineLimit(1)
                    .foregroundStyle(.primary)


            Spacer()

            if item.isCurrent {
                Image(systemName: "circle.circle")
                    .font(.caption.bold())
                    .foregroundStyle(Color.accentColor)
            } else if isEditable {
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
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.tertiarySystemBackground))
        )
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
