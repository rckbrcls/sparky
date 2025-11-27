import Foundation
import CoreLocation
import Combine

@MainActor
final class UserLocationProvider: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var coordinate: CLLocationCoordinate2D?

    private let manager: CLLocationManager

    override init() {
        manager = CLLocationManager()
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestAccessIfNeeded() {
        guard CLLocationManager.locationServicesEnabled() else { return }
        guard authorizationStatus == .notDetermined else { return }
        manager.requestWhenInUseAuthorization()
    }

    func refreshLocation() {
        guard CLLocationManager.locationServicesEnabled() else { return }
        manager.startUpdatingLocation()
    }
}

extension UserLocationProvider: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            authorizationStatus = manager.authorizationStatus
            switch authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                self.manager.requestLocation()
                self.manager.startUpdatingLocation()
            default:
                coordinate = nil
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        Task { @MainActor [weak self] in
            self?.coordinate = latest.coordinate
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.coordinate = nil
        }
    }
}
