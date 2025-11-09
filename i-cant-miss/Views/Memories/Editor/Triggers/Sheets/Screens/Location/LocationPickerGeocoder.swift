import MapKit
import Combine

@MainActor
final class LocationGeocoder: ObservableObject {
    @Published private(set) var isResolving = false

    private var activeCoordinate: CLLocationCoordinate2D?
    private var currentReverseRequest: MKReverseGeocodingRequest?

    func resolveName(for coordinate: CLLocationCoordinate2D) async -> String? {
        activeCoordinate = coordinate
        cancelActiveGeocode()
        isResolving = true

        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        do {
            let address = try await fetchAddress(for: location)
            if activeCoordinate?.isApproximatelyEqual(to: coordinate) ?? false {
                isResolving = false
            }
            return address
        } catch {
            if activeCoordinate?.isApproximatelyEqual(to: coordinate) ?? false {
                isResolving = false
            }
            return nil
        }
    }

    private func cancelActiveGeocode() {
        currentReverseRequest?.cancel()
        currentReverseRequest = nil
    }

    private func fetchAddress(for location: CLLocation) async throws -> String? {
        guard let request = MKReverseGeocodingRequest(location: location) else {
            return nil
        }

        currentReverseRequest = request
        do {
            let mapItems = try await request.mapItems
            guard currentReverseRequest === request else { return nil }
            currentReverseRequest = nil

            guard let mapItem = mapItems.first else { return nil }
            if let address = mapItem.address {
                return address.shortAddress ?? address.fullAddress
            }
            if let name = mapItem.name, !name.isEmpty {
                return name
            }
            return nil
        } catch {
            if currentReverseRequest === request {
                currentReverseRequest = nil
            }
            throw error
        }
    }
}
