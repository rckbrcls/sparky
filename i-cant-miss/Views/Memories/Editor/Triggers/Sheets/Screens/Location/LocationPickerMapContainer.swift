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
        if #available(iOS 17, *) {
            mapForModernPlatforms
        } else {
            mapForLegacyPlatforms
        }
    }

    @available(iOS 17, *)
    private var mapForModernPlatforms: some View {
        Map(position: $mapCameraPosition,
            interactionModes: allowsSelection ? .all : []) {
            if let coordinate = selectedCoordinate {
                MapCircle(center: coordinate, radius: defaultRadius)
                    .foregroundStyle(Color.accentColor.opacity(0.18))
                if !allowsSelection {
                    Marker(resolvedLocationName, coordinate: coordinate)
                        .tint(Color.accentColor)
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

    private var mapForLegacyPlatforms: some View {
        LegacySelectableMap(region: $region,
                            selectedCoordinate: $selectedCoordinate,
                            allowsSelection: allowsSelection,
                            defaultRadius: defaultRadius,
                            resolvedLocationName: resolvedLocationName,
                            onCoordinateSelected: onCoordinateSelected,
                            onRegionChange: { newRegion in
                                let span = sanitizedSpan(newRegion.span)
                                let updatedRegion = MKCoordinateRegion(center: newRegion.center, span: span)
                                region = updatedRegion
                                if allowsSelection {
                                    onCameraChange(updatedRegion)
                                }
                            })
    }

    private func sanitizedSpan(_ span: MKCoordinateSpan) -> MKCoordinateSpan {
        let latitude = span.latitudeDelta > 0 ? span.latitudeDelta : 0.01
        let longitude = span.longitudeDelta > 0 ? span.longitudeDelta : 0.01
        return MKCoordinateSpan(latitudeDelta: latitude, longitudeDelta: longitude)
    }
}
