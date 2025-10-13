//
//  LocationPickerView.swift
//  i-cant-miss
//
//  Created by Codex on 13/10/25.
//

import SwiftUI
import Combine
import MapKit

struct LocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var searchModel = LocationSearchViewModel()
    @State private var region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.00902),
                                                   span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var selectedName: String = ""
    @State private var radius: Double = 200
    @State private var event: LocationEvent = .onEntry
    @State private var isSearching = false

    let onAdd: (String, Double, Double, Double, LocationEvent) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                searchField

                if !searchModel.suggestions.isEmpty {
                    List {
                        ForEach(Array(searchModel.suggestions.enumerated()), id: \.offset) { _, suggestion in
                            Button {
                                Task {
                                    await selectSuggestion(suggestion)
                                }
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(suggestion.title)
                                    if !suggestion.subtitle.isEmpty {
                                        Text(suggestion.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .frame(height: 160)
                }

                Map(coordinateRegion: $region, interactionModes: [.all], showsUserLocation: true)
                    .frame(height: 250)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(alignment: .center) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.title)
                            .foregroundStyle(.red)
                            .shadow(radius: 4)
                    }
                    .overlay(alignment: .bottomTrailing) {
                        Button {
                            selectedCoordinate = region.center
                        } label: {
                            Label("Use center", systemImage: "scope")
                                .padding(8)
                                .background(.ultraThinMaterial, in: Capsule())
                        }
                        .padding()
                    }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Radius \(Int(radius)) m")
                        Slider(value: $radius, in: 50...1000, step: 50)
                    }
                    Picker("Event", selection: $event) {
                        ForEach(LocationEvent.allCases) { event in
                            Text(event.label).tag(event)
                        }
                    }
                    .pickerStyle(.segmented)

                    if !selectedName.isEmpty {
                        Text("Selected: \(selectedName)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding()
            .navigationTitle("Location Trigger")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        let coordinate = selectedCoordinate ?? region.center
                        let name = selectedName.isEmpty ? "Custom Location" : selectedName
                        onAdd(name, coordinate.latitude, coordinate.longitude, radius, event)
                        dismiss()
                    }
                }
            }
        }
    }

    private var searchField: some View {
        HStack {
            TextField("Search for a place", text: $searchModel.query)
                .textFieldStyle(.roundedBorder)
            if isSearching {
                ProgressView()
                    .transition(.opacity)
            }
        }
        .onReceive(searchModel.$isSearching) { value in
            withAnimation {
                isSearching = value
            }
        }
    }

    private func selectSuggestion(_ suggestion: MKLocalSearchCompletion) async {
        if let result = await searchModel.search(for: suggestion) {
            await MainActor.run {
                selectedCoordinate = result.placemark.coordinate
                selectedName = result.name ?? suggestion.title
                region = MKCoordinateRegion(center: result.placemark.coordinate,
                                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
                searchModel.query = suggestion.title
                searchModel.suggestions = []
            }
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
