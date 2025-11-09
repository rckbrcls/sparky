import SwiftUI
import MapKit
import UIKit

struct LegacySelectableMap: UIViewRepresentable {
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

            if !parent.allowsSelection {
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
