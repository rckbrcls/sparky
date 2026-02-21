import MapKit

extension CLLocationCoordinate2D {
    func isApproximatelyEqual(to other: CLLocationCoordinate2D, tolerance: CLLocationDegrees = 0.00001) -> Bool {
        abs(latitude - other.latitude) < tolerance && abs(longitude - other.longitude) < tolerance
    }
}
