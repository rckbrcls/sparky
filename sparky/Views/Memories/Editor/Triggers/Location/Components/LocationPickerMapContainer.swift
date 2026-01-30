import SwiftUI
import MapKit

struct MapContainer: View {
    let allowsSelection: Bool
    @Binding var mapCameraPosition: MapCameraPosition
    @Binding var region: MKCoordinateRegion
    @Binding var selectedCoordinate: CLLocationCoordinate2D?
    let defaultRadius: Double
    let resolvedLocationName: String
    let onCameraChange: (MKCoordinateRegion) -> Void
    let onCoordinateSelected: (CLLocationCoordinate2D) -> Void

    var body: some View {
        Map(position: $mapCameraPosition,
            interactionModes: allowsSelection ? .all : []) {
            if let coordinate = selectedCoordinate {
                MapCircle(center: coordinate, radius: defaultRadius)
                    .foregroundStyle(Color.accentColor.opacity(0.18))
                if !allowsSelection {
                    Annotation(resolvedLocationName, coordinate: coordinate) {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 10, height: 10)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                            )
                            .shadow(radius: 2)
                    }
                }
            }
        }
        .onMapCameraChange { context in
            let span = sanitizedSpan(context.region.span)
            let updatedRegion = MKCoordinateRegion(center: context.region.center, span: span)
            region = updatedRegion
            if allowsSelection {
                onCameraChange(updatedRegion)
            }
        }
        .mapControls {
            if allowsSelection {
                MapCompass()
                MapUserLocationButton()
            }
        }
    }

    private func sanitizedSpan(_ span: MKCoordinateSpan) -> MKCoordinateSpan {
        let latitude = span.latitudeDelta > 0 ? span.latitudeDelta : 0.01
        let longitude = span.longitudeDelta > 0 ? span.longitudeDelta : 0.01
        return MKCoordinateSpan(latitudeDelta: latitude, longitudeDelta: longitude)
    }
}
