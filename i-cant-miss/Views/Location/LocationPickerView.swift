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
            Text("Tap the map to drop the marker. We'll monitor a \(Int(defaultRadius)) m radius automatically.")
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
            ZStack(alignment: .topLeading) {
                mapView(allowsSelection: true)
                    .ignoresSafeArea()

                mapSelectionOverlay
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
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
                expandedSuggestionPanel
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
            MapReader { proxy in
                let baseMap = Map(position: $mapCameraPosition,
                                  interactionModes: allowsSelection ? .all : [])
                {
                    if let coordinate = selectedCoordinate {
                        MapCircle(center: coordinate, radius: defaultRadius)
                            .foregroundStyle(Color.accentColor.opacity(0.18))

                        Marker(markerTitle, coordinate: coordinate)
                            .tint(Color.accentColor)
                    }
                }
                .onMapCameraChange { context in
                    let span = sanitizedSpan(context.region.span)
                    let center = selectedCoordinate ?? context.region.center
                    region = MKCoordinateRegion(center: center, span: span)
                }

                if allowsSelection {
                    baseMap
                        .mapControls {
                            MapCompass()
                            MapUserLocationButton()
                        }
                        .simultaneousGesture(
                            SpatialTapGesture(coordinateSpace: .local)
                                .onEnded { value in
                                    let tapPoint = value.location
                                    if let coordinate = proxy.convert(tapPoint, from: .local) {
                                        updateSelection(to: coordinate)
                                    }
                                }
                        )
                } else {
                    baseMap
                }
            }
        } else {
            LegacySelectableMap(region: $region,
                                selectedCoordinate: $selectedCoordinate,
                                allowsSelection: allowsSelection,
                                defaultRadius: defaultRadius,
                                resolvedLocationName: resolvedLocationName,
                                onCoordinateSelected: { coordinate in
                                    updateSelection(to: coordinate)
                                },
                                onRegionChange: { newRegion in
                                    let span = sanitizedSpan(newRegion.span)
                                    let center = selectedCoordinate ?? newRegion.center
                                    region = MKCoordinateRegion(center: center, span: span)
                                })
        }
    }

    private var mapSelectionOverlay: some View {
        Group {
            if selectedCoordinate == nil {
                HStack {
                    Text("Tap anywhere on the map to drop your marker.")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color(.systemBackground), in: Capsule())
                    Spacer()
                }
                .padding(12)
            }
        }
        .allowsHitTesting(false)
    }

    private func updateSelection(to coordinate: CLLocationCoordinate2D,
                                 span overrideSpan: MKCoordinateSpan? = nil,
                                 name: String? = nil,
                                 resetName: Bool = true,
                                 updateCamera: Bool = false) {
        let targetSpan = sanitizedSpan(overrideSpan ?? region.span)
        let updatedRegion = MKCoordinateRegion(center: coordinate, span: targetSpan)

        selectedCoordinate = coordinate
        region = updatedRegion

        if updateCamera, #available(iOS 17, *) {
            mapCameraPosition = .region(updatedRegion)
        }

        if let providedName = name {
            selectedName = providedName
        } else if resetName {
            selectedName = ""
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
        return markerTitle
    }

    private var coordinateSummary: String {
        guard let coordinate = selectedCoordinate else {
            return "Tap the map to choose a location."
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
                                updateCamera: true)
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

        if allowsSelection {
            let tapRecognizer = UITapGestureRecognizer(target: context.coordinator,
                                                       action: #selector(Coordinator.handleTap(_:)))
            tapRecognizer.numberOfTapsRequired = 1
            tapRecognizer.numberOfTouchesRequired = 1
            mapView.addGestureRecognizer(tapRecognizer)
        }

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

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let mapView = recognizer.view as? MKMapView else { return }
            let location = recognizer.location(in: mapView)
            let coordinate = mapView.convert(location, toCoordinateFrom: mapView)
            parent.onCoordinateSelected(coordinate)
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.onRegionChange(mapView.region)
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

            let annotation = MKPointAnnotation()
            annotation.coordinate = coordinate
            annotation.title = parent.resolvedLocationName
            mapView.addAnnotation(annotation)

            let circle = MKCircle(center: coordinate, radius: parent.defaultRadius)
            mapView.addOverlay(circle)
        }
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
