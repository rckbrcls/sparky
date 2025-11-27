import SwiftUI
import MapKit
import Combine

struct MemoriesMapView: View {
    struct MemoryAnnotation: Identifiable {
        let id: UUID
        let memory: MemoryModel
        let coordinate: CLLocationCoordinate2D
        let radius: Double
        let locationName: String?
        let event: LocationEvent

        init(memory: MemoryModel, trigger: MemoryTriggerModel, location: MemoryTriggerModel.TriggerLocation) {
            self.id = trigger.id
            self.memory = memory
            self.coordinate = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
            self.radius = max(location.radius, 60)
            self.locationName = location.name
            self.event = location.event
        }
    }

    let memories: [MemoryModel]
    let onSelectMemory: (MemoryModel) -> Void

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var hasCenteredOnAnnotations = false
    @State private var hasCenteredOnUser = false
    @State private var selectedTriggerID: UUID?
    @StateObject private var userLocationProvider = UserLocationProvider()

    private var annotations: [MemoryAnnotation] {
        memories.flatMap { memory in
            memory.triggers
                .filter { $0.isActive && $0.type == .location }
                .compactMap { trigger in
                    guard let location = trigger.location else { return nil }
                    let coordinate = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
                    guard CLLocationCoordinate2DIsValid(coordinate) else { return nil }
                    return MemoryAnnotation(memory: memory, trigger: trigger, location: location)
                }
        }
    }

    private var selectedAnnotation: MemoryAnnotation? {
        guard let triggerID = selectedTriggerID else { return nil }
        return annotations.first { $0.id == triggerID }
    }

    private var annotationsSignature: String {
        annotations.map { $0.id.uuidString }.sorted().joined(separator: "-")
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            mapContent
            emptyStateOverlay
            selectionOverlay
        }
        .onChange(of: annotationsSignature) { _, _ in
            centerCameraIfNeeded()
        }
        .onReceive(userLocationProvider.$coordinate.compactMap { $0 }) { coordinate in
            centerOnUser(coordinate)
        }
        .task {
            userLocationProvider.requestAccessIfNeeded()
            centerCameraIfNeeded()
        }
    }

    private var mapContent: some View {
        Map(position: $cameraPosition,
            interactionModes: .all) {
            UserAnnotation()

            ForEach(annotations) { annotation in
                MapCircle(center: annotation.coordinate, radius: annotation.radius)
                    .foregroundStyle(Color.accentColor.opacity(0.18))
                    .stroke(Color.accentColor.opacity(0.5), lineWidth: 1)

                Annotation(annotation.memory.title, coordinate: annotation.coordinate) {
                    MemoryMapMarkerView(isSelected: selectedTriggerID == annotation.id)
                        .onTapGesture {
                            withAnimation(.easeInOut) {
                                selectedTriggerID = annotation.id
                            }
                        }
                }
            }
        }
        .mapControls {
            MapCompass()
            MapUserLocationButton()
            MapPitchToggle()
            MapScaleView()
        }
        .mapStyle(.standard)
        .ignoresSafeArea(.container, edges: .all)
    }

    private var selectionOverlay: some View {
        Group {
            if let annotation = selectedAnnotation {
                VStack(alignment: .leading, spacing: 8) {
                    Text(annotation.memory.title)
                        .font(.headline)
                        .lineLimit(2)

                    if let name = annotation.locationName, !name.isEmpty {
                        Label(name, systemImage: "mappin.and.ellipse")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Label(annotation.event.displayName, systemImage: annotation.event == .onEntry ? "arrow.down.circle" : "arrow.up.circle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("Radius: \(Int(annotation.radius)) m")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button("View Memory") {
                        onSelectMemory(annotation.memory)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding()
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var emptyStateOverlay: some View {
        VStack {
            if annotations.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "mappin.slash")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No Location Memories")
                            .font(.headline)
                        Text("Create a location-triggered memory to see it here.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.horizontal, 16)
                .padding(.top, 20)
            }
            Spacer()
        }
        .allowsHitTesting(false)
    }

    private func centerCameraIfNeeded() {
        if !hasCenteredOnUser, let coordinate = userLocationProvider.coordinate {
            centerOnUser(coordinate)
            return
        }

        guard !hasCenteredOnAnnotations else { return }
        guard let region = fittedRegion(for: annotations) else { return }
        cameraPosition = .region(region)
        hasCenteredOnAnnotations = true
    }

    private func centerOnUser(_ coordinate: CLLocationCoordinate2D) {
        guard CLLocationCoordinate2DIsValid(coordinate) else { return }
        let span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        cameraPosition = .region(MKCoordinateRegion(center: coordinate, span: span))
        hasCenteredOnUser = true
    }

    private func fittedRegion(for annotations: [MemoryAnnotation]) -> MKCoordinateRegion? {
        guard let first = annotations.first else { return nil }
        var minLatitude = first.coordinate.latitude
        var maxLatitude = first.coordinate.latitude
        var minLongitude = first.coordinate.longitude
        var maxLongitude = first.coordinate.longitude

        annotations.dropFirst().forEach { annotation in
            minLatitude = min(minLatitude, annotation.coordinate.latitude)
            maxLatitude = max(maxLatitude, annotation.coordinate.latitude)
            minLongitude = min(minLongitude, annotation.coordinate.longitude)
            maxLongitude = max(maxLongitude, annotation.coordinate.longitude)
        }

        let latitudeDelta = max((maxLatitude - minLatitude) * 1.3, 0.02)
        let longitudeDelta = max((maxLongitude - minLongitude) * 1.3, 0.02)
        let center = CLLocationCoordinate2D(
            latitude: (minLatitude + maxLatitude) / 2,
            longitude: (minLongitude + maxLongitude) / 2
        )

        guard CLLocationCoordinate2DIsValid(center) else { return nil }

        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
        )
    }
}

private struct MemoryMapMarkerView: View {
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? Color.accentColor : Color.white)
                .frame(width: 32, height: 32)
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)

            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSelected ? Color.white : Color.accentColor)
        }
        .padding(4)
        .background(
            Circle()
                .fill(Color.white.opacity(isSelected ? 0.6 : 0.3))
        )
    }
}
