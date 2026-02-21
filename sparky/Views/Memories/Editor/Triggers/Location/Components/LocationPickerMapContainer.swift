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
            if !allowsSelection, let coordinate = selectedCoordinate {
                MapCircle(center: coordinate, radius: defaultRadius)
                    .foregroundStyle(Color.accentColor.opacity(0.18))
            }
        }
        .overlay {
            if allowsSelection {
                GeometryReader { geo in
                    let diameter = geofencePixelDiameter(viewWidth: geo.size.width)
                    Circle()
                        .fill(Color.accentColor.opacity(0.18))
                        .overlay(
                            Circle()
                                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1.5)
                        )
                        .frame(width: diameter, height: diameter)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                        .allowsHitTesting(false)
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
            }
        }
    }

    private func geofencePixelDiameter(viewWidth: CGFloat) -> CGFloat {
        let metersPerDegreeLon = 111_320 * cos(region.center.latitude * .pi / 180)
        let metersAcrossView = region.span.longitudeDelta * metersPerDegreeLon
        guard metersAcrossView > 0 else { return 0 }
        let pixelRadius = (defaultRadius / metersAcrossView) * viewWidth
        return pixelRadius * 2
    }

    private func sanitizedSpan(_ span: MKCoordinateSpan) -> MKCoordinateSpan {
        let latitude = span.latitudeDelta > 0 ? span.latitudeDelta : 0.01
        let longitude = span.longitudeDelta > 0 ? span.longitudeDelta : 0.01
        return MKCoordinateSpan(latitudeDelta: latitude, longitudeDelta: longitude)
    }
}
