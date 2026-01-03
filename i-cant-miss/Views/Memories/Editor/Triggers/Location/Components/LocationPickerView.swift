import SwiftUI
import MapKit

struct LocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var searchModel: LocationSearchViewModel
    @StateObject private var geocodingModel: LocationGeocoder
    private let defaultRadius: Double = 200
    private let expandedSuggestionBottomPadding: CGFloat = 120
    @State private var region: MKCoordinateRegion
    @State private var mapCameraPosition: MapCameraPosition
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var selectedName: String
    @State private var event: LocationEvent
    @State private var isSearching: Bool
    @State private var isMapExpanded: Bool
    @State private var isCameraAdjusting: Bool
    @State private var geocodeTask: Task<Void, Never>?
    @State private var cameraCooldownTask: Task<Void, Never>?
    @FocusState private var isSearchFieldFocused: Bool
    private let showsCloseButton: Bool
    let onAdd: (String, Double, Double, Double, LocationEvent) -> Void

    init(
        showsCloseButton: Bool = true,
        onAdd: @escaping (String, Double, Double, Double, LocationEvent) -> Void
    ) {
        let initialRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.00902),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        _searchModel = StateObject(wrappedValue: LocationSearchViewModel())
        _geocodingModel = StateObject(wrappedValue: LocationGeocoder())
        _region = State(initialValue: initialRegion)
        _mapCameraPosition = State(initialValue: .region(initialRegion))
        _selectedCoordinate = State(initialValue: nil)
        _selectedName = State(initialValue: "")
        _event = State(initialValue: .onEntry)
        _isSearching = State(initialValue: false)
        _isMapExpanded = State(initialValue: false)
        _isCameraAdjusting = State(initialValue: false)
        _geocodeTask = State(initialValue: nil)
        _cameraCooldownTask = State(initialValue: nil)
        self.showsCloseButton = showsCloseButton
        self.onAdd = onAdd
    }

    var body: some View {
        VStack {
            Spacer()
            MapSection(
                onExpand: { isMapExpanded = true },
                mapPreview: { mapPreviewContent }
            )
            .padding(.horizontal, 24)
            Spacer()
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Location Trigger")
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
                Button(role: .confirm) {
                    guard let coordinate = selectedCoordinate else { return }
                    let name = resolvedLocationName
                    onAdd(name, coordinate.latitude, coordinate.longitude, defaultRadius, event)
                    dismiss()
                }
                label: {
                    Image(systemName: "checkmark")
                }
                .accessibilityLabel("Confirm Location Trigger")
                .disabled(isSearching || selectedCoordinate == nil)
            }
        }
        .onReceive(searchModel.$isSearching) { value in
            withAnimation(.easeInOut(duration: 0.2)) {
                isSearching = value
            }
        }
        .fullScreenCover(isPresented: $isMapExpanded) {
            expandedMapView
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
}

// MARK: - Private helpers

private extension LocationPickerView {
    var mapPreviewContent: some View {
        mapView(allowsSelection: false)
            .allowsHitTesting(false)
    }

    var expandedMapView: some View {
        ExpandedMapScreen(
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

    var expandedSuggestionPanel: some View {
        ExpandedSuggestionPanel(
            suggestions: searchModel.suggestions,
            onSuggestionSelected: handleSuggestionTap(_:)
        )
    }

    var expandedConfirmationPanel: some View {
        ExpandedConfirmationPanel(
            resolvedLocationName: resolvedLocationName,
            coordinateSummary: coordinateSummary,
            isResolving: geocodingModel.isResolving,
            event: $event,
            onUseLocation: { isMapExpanded = false }
        )
    }

    var expandedSearchBar: some View {
        ExpandedSearchBar(
            query: $searchModel.query,
            isSearching: isSearching,
            onClearQuery: clearSearchQuery
        )
    }

    var mapSelectionOverlay: some View {
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

    var mapCenterIndicator: some View {
        VStack {
            Spacer()
            VStack(spacing: 4) {
                Image(systemName: geocodingModel.isResolving ? "mappin.circle" : "mappin.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.accentColor)
                    .shadow(color: Color.black.opacity(0.25), radius: 8, y: 6)
                Circle()
                    .fill(Color.accentColor.opacity(0.25))
                    .frame(width: 18, height: 18)
                    .overlay(
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 6, height: 6)
                    )
            }
            .offset(y: -28)
            Spacer()
        }
        .allowsHitTesting(false)
    }

    func mapView(allowsSelection: Bool) -> some View {
        MapContainer(
            allowsSelection: allowsSelection,
            mapCameraPosition: $mapCameraPosition,
            region: $region,
            selectedCoordinate: $selectedCoordinate,
            defaultRadius: defaultRadius,
            resolvedLocationName: resolvedLocationName,
            onCameraChange: handleCameraRegionChange(to:),
            onCoordinateSelected: { coordinate in
                updateSelection(
                    to: coordinate,
                    resetName: true,
                    updateCamera: false,
                    shouldGeocode: true
                )
            }
        )
        .environmentObject(geocodingModel)
    }

    func handleCameraRegionChange(to updatedRegion: MKCoordinateRegion) {
        guard !isCameraAdjusting else { return }
        let coordinate = updatedRegion.center
        if selectedCoordinate?.isApproximatelyEqual(to: coordinate) == true {
            return
        }
        selectedName = ""
        selectedCoordinate = coordinate
        scheduleReverseGeocode(for: coordinate)
    }

    func updateSelection(to coordinate: CLLocationCoordinate2D,
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

    func handleSuggestionTap(_ suggestion: MKLocalSearchCompletion) {
        Task { await selectSuggestion(suggestion) }
    }

    func scheduleReverseGeocode(for coordinate: CLLocationCoordinate2D, force: Bool = false) {
        geocodeTask?.cancel()
        geocodeTask = Task { @MainActor in
            if !force {
                try? await Task.sleep(nanoseconds: 350_000_000)
            }
            guard !Task.isCancelled else { return }
            if let resolved = await geocodingModel.resolveName(for: coordinate) {
                guard !Task.isCancelled else { return }
                if let currentCoordinate = selectedCoordinate,
                   currentCoordinate.isApproximatelyEqual(to: coordinate) {
                    selectedName = resolved
                }
            } else if selectedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                selectedName = "Pinned Location"
            }
        }
    }

    func sanitizedSpan(_ span: MKCoordinateSpan) -> MKCoordinateSpan {
        let latitude = span.latitudeDelta > 0 ? span.latitudeDelta : 0.01
        let longitude = span.longitudeDelta > 0 ? span.longitudeDelta : 0.01
        return MKCoordinateSpan(latitudeDelta: latitude, longitudeDelta: longitude)
    }

    func selectSuggestion(_ suggestion: MKLocalSearchCompletion) async {
        if let result = await searchModel.search(for: suggestion) {
            await MainActor.run {
                let resolvedName = result.name ?? suggestion.title
                let coordinate = result.location.coordinate
                updateSelection(to: coordinate,
                                name: resolvedName,
                                resetName: false,
                                updateCamera: true,
                                shouldGeocode: false)
                searchModel.query = suggestion.title
                withAnimation(.easeInOut(duration: 0.2)) {
                    searchModel.suggestions = []
                }
                isSearchFieldFocused = false
            }
        }
    }

    func clearSearchQuery() {
        searchModel.query = ""
        searchModel.suggestions = []
    }

    var resolvedLocationName: String {
        guard selectedCoordinate != nil else {
            return "Select a place on the map"
        }
        if geocodingModel.isResolving && selectedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Resolving address..."
        }
        return markerTitle
    }

    var coordinateSummary: String {
        guard let coordinate = selectedCoordinate else {
            return "Drag the map to choose a location."
        }
        return String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude)
    }

    var markerTitle: String {
        let trimmed = selectedName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Pinned Location" : trimmed
    }

    var eventDescription: String {
        switch event {
        case .onEntry:
            return "We'll remind you as soon as you arrive at this place."
        case .onExit:
            return "We'll remind you when you leave this place."
        }
    }
}
