import Combine
import CoreLocation
import Foundation

@MainActor
final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    @Published private(set) var location: CLLocation?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var errorMessage: String?
    var onLocation: ((CLLocation) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = manager.authorizationStatus
    }

    func start() {
        guard CLLocationManager.locationServicesEnabled() else {
            errorMessage = NSLocalizedString("location.services_disabled", comment: "")
            return
        }

        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            errorMessage = NSLocalizedString("location.permission_required", comment: "")
        default:
            break
        }
    }

    func refresh() {
        start()
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
            if manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse {
                manager.requestLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let newest = locations.last else { return }
            self.location = newest
            self.errorMessage = nil
            self.onLocation?(newest)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.errorMessage = NSLocalizedString("location.geocode_failed", comment: "")
        }
    }

    /// Performs reverse geocoding to resolve genuine locality name and timezone.
    /// Strictly returns nil if unverified; never returns fabricated or generic status strings as city name.
    func describe(_ location: CLLocation) async -> (city: String?, timeZone: TimeZone?) {
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location, preferredLocale: Locale.autoupdatingCurrent)
            guard let place = placemarks.first else {
                return (nil, nil)
            }
            let cityName = place.locality ?? place.subLocality ?? place.administrativeArea
            return (cityName, place.timeZone)
        } catch {
            return (nil, nil)
        }
    }

    func resolve(city: String) async throws -> (location: CLLocation, city: String, timeZone: TimeZone) {
        let placemarks = try await geocoder.geocodeAddressString(city, in: nil, preferredLocale: Locale.autoupdatingCurrent)
        guard let place = placemarks.first, let location = place.location else {
            throw CLError(.geocodeFoundNoResult)
        }
        let resolvedCity = place.locality ?? place.name ?? city
        guard let tz = place.timeZone else {
            throw CLError(.geocodeFoundNoResult)
        }
        return (location, resolvedCity, tz)
    }
}
