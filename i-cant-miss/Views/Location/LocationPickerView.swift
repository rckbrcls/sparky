//
//  LocationPickerView.swift
//  i-cant-miss
//
//  Created by Codex on 13/10/25.
//

import SwiftUI
import Combine
import MapKit
import UIKit

struct LocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var searchModel = LocationSearchViewModel()
    @StateObject private var geocodingModel = LocationGeocoder()
    private let defaultRadius: Double = 200
    private let expandedSuggestionBottomPadding: CGFloat = 120
    @State private var region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.00902),
                                                   span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
    @State private var mapCameraPosition = MapCameraPosition.region(
        MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.00902),
                           span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
    )
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var selectedName: String = ""
    @State private var event: LocationEvent = .onEntry
    @State private var isSearching = false
    @State private var isMapExpanded = false
    @State private var isCameraAdjusting = false
    @State private var geocodeTask: Task<Void, Never>?
    @State private var cameraCooldownTask: Task<Void, Never>?
    @FocusState private var isSearchFieldFocused: Bool

    let onAdd: (String, Double, Double, Double, LocationEvent) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    searchSection
                    mapSection
                    eventSection
                    summarySection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Location Trigger")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        guard let coordinate = selectedCoordinate else { return }
                        let name = resolvedLocationName
                        onAdd(name, coordinate.latitude, coordinate.longitude, defaultRadius, event)
                        dismiss()
                    }
                    .disabled(isSearching || selectedCoordinate == nil)
                }
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

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Search for a place")
                .font(.headline)

            inlineSearchField

            inlineSuggestionList
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemBackground)))
    }

    private var inlineSearchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search for a place or pan the map", text: $searchModel.query)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)

            if !searchModel.query.isEmpty {
                Button {
                    searchModel.query = ""
                    searchModel.suggestions = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
            }

            if isSearching {
                ProgressView()
                    .progressViewStyle(.circular)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }

    @ViewBuilder
    private var inlineSuggestionList: some View {
        if !searchModel.suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("Suggestions")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)

                ForEach(Array(searchModel.suggestions.enumerated()), id: \.offset) { index, suggestion in
                    Button {
                        Task {
                            await selectSuggestion(suggestion)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(suggestion.title)
                                .font(.body.weight(.medium))
                                .foregroundStyle(.primary)
                            if !suggestion.subtitle.isEmpty {
                                Text(suggestion.subtitle)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)

                    if index < searchModel.suggestions.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }

    private var mapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Adjust the pin")
                .font(.headline)
            Text("Drag the map to position the pin. We'll monitor a \(Int(defaultRadius)) m radius automatically.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button {
                isMapExpanded = true
            } label: {
                ZStack(alignment: .top) {
                    mapPreview
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    mapSelectionOverlay
                    mapPreviewHint
                }
                .frame(height: 280)
                .contentShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .shadow(color: Color.black.opacity(0.08), radius: 12, y: 6)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemBackground)))
    }

    private var mapPreview: some View {
        mapView(allowsSelection: false)
            .allowsHitTesting(false)
    }

    private var mapPreviewHint: some View {
        HStack {
            Spacer()
            Label("Tap to expand", systemImage: "arrow.up.left.and.arrow.down.right")
                .font(.caption.weight(.semibold))
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(Color(.systemBackground), in: Capsule())
        }
        .padding(12)
        .allowsHitTesting(false)
    }

    private var expandedMapView: some View {
        NavigationStack {
            ZStack {
                mapView(allowsSelection: true)
                    .ignoresSafeArea()
                VStack(spacing: 0) {
                    mapSelectionOverlay
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    Spacer()
                }
                mapCenterIndicator
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        isMapExpanded = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("Adjust location")
                        .font(.headline)
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    expandedSearchBar
                }
            }
            .overlay(alignment: .bottom) {
                VStack(spacing: 16) {
                    expandedSuggestionPanel
                    expandedConfirmationPanel
                }
                .padding(.horizontal, 16)
                .padding(.bottom, expandedSuggestionBottomPadding)
                .zIndex(1)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSearchFieldFocused = true
            }
        }
        .onDisappear {
            isSearchFieldFocused = false
        }
    }

    @ViewBuilder
    private var expandedSuggestionPanel: some View {
        if !searchModel.suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("Suggestions")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)

                ForEach(Array(searchModel.suggestions.enumerated()), id: \.offset) { index, suggestion in
                    Button {
                        Task {
                            await selectSuggestion(suggestion)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(suggestion.title)
                                .font(.body.weight(.medium))
                                .foregroundStyle(.primary)
                            if !suggestion.subtitle.isEmpty {
                                Text(suggestion.subtitle)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)

                    if index < searchModel.suggestions.count - 1 {
                        Divider()
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18))
        }
    }

    private var expandedConfirmationPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Capsule()
                .fill(Color.secondary.opacity(0.35))
                .frame(width: 40, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)

            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text(resolvedLocationName)
                        .font(.body.weight(.semibold))
                    Text(coordinateSummary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "mappin.circle.fill")
                    .foregroundStyle(Color.accentColor)
            }

            if geocodingModel.isResolving {
                HStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(.circular)
                    Text("Resolving address…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                isMapExpanded = false
            } label: {
                Text("Use this location")
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(Color.white)
            }
        }
        .padding(16)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 22))
        .shadow(color: Color.black.opacity(0.12), radius: 20, y: 12)
    }

    private var mapCenterIndicator: some View {
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

    private var expandedSearchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search for a place or pan the map", text: $searchModel.query)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
                .focused($isSearchFieldFocused)

            if !searchModel.query.isEmpty {
                Button {
                    searchModel.query = ""
                    searchModel.suggestions = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
            }

            if isSearching {
                ProgressView()
                    .progressViewStyle(.circular)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var eventSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("When should we remind you?")
                .font(.headline)

            Picker("Event", selection: $event) {
                ForEach(LocationEvent.allCases) { event in
                    Text(event.label).tag(event)
                }
            }
            .pickerStyle(.segmented)

            Text(eventDescription)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemBackground)))
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Location summary")
                .font(.headline)

            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text(resolvedLocationName)
                        .font(.body.weight(.semibold))
                    Text(coordinateSummary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(Color.accentColor)
            }

            Divider()

            Label("Geofence radius \(Int(defaultRadius)) m", systemImage: "dot.circle")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemBackground)))
    }

    @ViewBuilder
    private func mapView(allowsSelection: Bool) -> some View {
        if #available(iOS 17, *) {
            Map(position: $mapCameraPosition,
                interactionModes: allowsSelection ? .all : []) {
                if let coordinate = selectedCoordinate {
                    MapCircle(center: coordinate, radius: defaultRadius)
                        .foregroundStyle(Color.accentColor.opacity(0.18))
                    if !allowsSelection {
                        Marker(markerTitle, coordinate: coordinate)
                            .tint(Color.accentColor)
                    }
                }
            }
            .onMapCameraChange { context in
                let span = sanitizedSpan(context.region.span)
                let updatedRegion = MKCoordinateRegion(center: context.region.center, span: span)
                region = updatedRegion
                if allowsSelection {
                    handleCameraRegionChange(to: updatedRegion)
                }
            }
            .mapControls {
                if allowsSelection {
                    MapCompass()
                    MapUserLocationButton()
                }
            }
        } else {
            LegacySelectableMap(region: $region,
                                selectedCoordinate: $selectedCoordinate,
                                allowsSelection: allowsSelection,
                                defaultRadius: defaultRadius,
                                shouldShowMarker: !allowsSelection,
                                resolvedLocationName: resolvedLocationName,
                                onCoordinateSelected: { coordinate in
                                    updateSelection(to: coordinate,
                                                    resetName: true,
                                                    updateCamera: false,
                                                    shouldGeocode: true)
                                },
                                onRegionChange: { newRegion in
                                    let span = sanitizedSpan(newRegion.span)
                                    let updatedRegion = MKCoordinateRegion(center: newRegion.center, span: span)
                                    region = updatedRegion
                                })
        }
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

        if updateCamera, #available(iOS 17, *) {
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

    private func handleCameraRegionChange(to updatedRegion: MKCoordinateRegion) {
        guard !isCameraAdjusting else { return }
        let coordinate = updatedRegion.center
        if selectedCoordinate?.isApproximatelyEqual(to: coordinate) == true {
            return
        }
        selectedName = ""
        selectedCoordinate = coordinate
        scheduleReverseGeocode(for: coordinate)
    }

    private func scheduleReverseGeocode(for coordinate: CLLocationCoordinate2D, force: Bool = false) {
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

    private func sanitizedSpan(_ span: MKCoordinateSpan) -> MKCoordinateSpan {
        let latitude = span.latitudeDelta > 0 ? span.latitudeDelta : 0.01
        let longitude = span.longitudeDelta > 0 ? span.longitudeDelta : 0.01
        return MKCoordinateSpan(latitudeDelta: latitude, longitudeDelta: longitude)
    }

    private var resolvedLocationName: String {
        guard selectedCoordinate != nil else {
            return "Select a place on the map"
        }
        if geocodingModel.isResolving && selectedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Resolving address..."
        }
        return markerTitle
    }

    private var coordinateSummary: String {
        guard let coordinate = selectedCoordinate else {
            return "Drag the map to choose a location."
        }
        return String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude)
    }

    private var markerTitle: String {
        let trimmed = selectedName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Pinned Location" : trimmed
    }

    private var eventDescription: String {
        switch event {
        case .onEntry:
            return "We'll remind you as soon as you arrive at this place."
        case .onExit:
            return "We'll remind you when you leave this place."
        }
    }

    private func selectSuggestion(_ suggestion: MKLocalSearchCompletion) async {
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
}

private extension MKCoordinateRegion {
    func isApproximatelyEqual(to other: MKCoordinateRegion, tolerance: CLLocationDegrees = 0.0005) -> Bool {
        let latitudeDiff = abs(center.latitude - other.center.latitude)
        let longitudeDiff = abs(center.longitude - other.center.longitude)
        let latitudeSpanDiff = abs(span.latitudeDelta - other.span.latitudeDelta)
        let longitudeSpanDiff = abs(span.longitudeDelta - other.span.longitudeDelta)

        return latitudeDiff < tolerance &&
        longitudeDiff < tolerance &&
        latitudeSpanDiff < tolerance &&
        longitudeSpanDiff < tolerance
    }
}

private struct LegacySelectableMap: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    @Binding var selectedCoordinate: CLLocationCoordinate2D?
    let allowsSelection: Bool
    let defaultRadius: Double
    let shouldShowMarker: Bool
    let resolvedLocationName: String
    let onCoordinateSelected: (CLLocationCoordinate2D) -> Void
    let onRegionChange: (MKCoordinateRegion) -> Void

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.showsCompass = true
        mapView.showsScale = false
        mapView.showsUserLocation = true
        mapView.setRegion(region, animated: false)
        mapView.isScrollEnabled = allowsSelection
        mapView.isZoomEnabled = allowsSelection
        mapView.isPitchEnabled = allowsSelection
        mapView.isRotateEnabled = allowsSelection

        context.coordinator.refreshAnnotationsAndOverlays(on: mapView)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self

        if !mapView.region.isApproximatelyEqual(to: region) {
            mapView.setRegion(region, animated: true)
        }

        context.coordinator.refreshAnnotationsAndOverlays(on: mapView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: LegacySelectableMap

        init(parent: LegacySelectableMap) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.onRegionChange(mapView.region)
            if parent.allowsSelection {
                parent.onCoordinateSelected(mapView.centerCoordinate)
            }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let circle = overlay as? MKCircle else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let renderer = MKCircleRenderer(circle: circle)
            let accent = UIColor(Color.accentColor)
            renderer.fillColor = accent.withAlphaComponent(0.12)
            renderer.strokeColor = accent.withAlphaComponent(0.45)
            renderer.lineWidth = 2
            return renderer
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }

            let identifier = "LocationMarker"
            if let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView {
                configureMarker(view, for: annotation)
                return view
            }

            let view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            configureMarker(view, for: annotation)
            return view
        }

        private func configureMarker(_ view: MKMarkerAnnotationView, for annotation: MKAnnotation) {
            view.annotation = annotation
            view.titleVisibility = .adaptive
            view.subtitleVisibility = .hidden
            view.markerTintColor = UIColor(Color.accentColor)
        }

        func refreshAnnotationsAndOverlays(on mapView: MKMapView) {
            let nonUserAnnotations = mapView.annotations.filter { !($0 is MKUserLocation) }
            mapView.removeAnnotations(nonUserAnnotations)
            mapView.removeOverlays(mapView.overlays)

            guard let coordinate = parent.selectedCoordinate else { return }

            if parent.shouldShowMarker {
                let annotation = MKPointAnnotation()
                annotation.coordinate = coordinate
                annotation.title = parent.resolvedLocationName
                mapView.addAnnotation(annotation)
            }

            let circle = MKCircle(center: coordinate, radius: parent.defaultRadius)
            mapView.addOverlay(circle)
        }
    }
}

@MainActor
private final class LocationGeocoder: ObservableObject {
    @Published private(set) var isResolving = false

    private let geocoder = CLGeocoder()
    private var activeCoordinate: CLLocationCoordinate2D?

    func resolveName(for coordinate: CLLocationCoordinate2D) async -> String? {
        activeCoordinate = coordinate
        geocoder.cancelGeocode()
        isResolving = true
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            let name = placemarks.first?.formattedAddress
            if activeCoordinate?.isApproximatelyEqual(to: coordinate) ?? false {
                isResolving = false
            }
            return name
        } catch {
            if activeCoordinate?.isApproximatelyEqual(to: coordinate) ?? false {
                isResolving = false
            }
            return nil
        }
    }
}

private extension CLLocationCoordinate2D {
    func isApproximatelyEqual(to other: CLLocationCoordinate2D, tolerance: CLLocationDegrees = 0.00001) -> Bool {
        abs(latitude - other.latitude) < tolerance && abs(longitude - other.longitude) < tolerance
    }
}

private extension CLPlacemark {
    var formattedAddress: String {
        let street = [subThoroughfare, thoroughfare]
            .compactMap { $0 }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        let localityComponents = [subLocality, locality, administrativeArea]
            .compactMap { $0 }
        let combined = ([street] + localityComponents)
            .filter { !$0.isEmpty }
        if !combined.isEmpty {
            return combined.joined(separator: ", ")
        }
        return name ?? "Pinned Location"
    }
}

private final class LocationSearchViewModel: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var query: String = "" {
        didSet { updateQuery() }
    }
    @Published var suggestions: [MKLocalSearchCompletion] = []
    @Published var isSearching = false

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    private func updateQuery() {
        if query.isEmpty {
            suggestions = []
            isSearching = false
            return
        }
        isSearching = true
        completer.queryFragment = query
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in
            self.suggestions = completer.results
            self.isSearching = false
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.isSearching = false
        }
    }

    func search(for completion: MKLocalSearchCompletion) async -> MKMapItem? {
        isSearching = true
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            isSearching = false
            return response.mapItems.first
        } catch {
            isSearching = false
            return nil
        }
    }
}
