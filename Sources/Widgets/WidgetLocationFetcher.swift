import CoreLocation
import Foundation
import os

@MainActor
final class WidgetLocationFetcher: NSObject, CLLocationManagerDelegate {
    private static let logger = Logger(subsystem: "com.davidpovarsky.Zmanim.Widgets", category: "WidgetLocationFetcher")

    enum WidgetLocationState: Equatable {
        case authorized(reducedAccuracy: Bool)
        case appAuthorizedWidgetDenied
        case deniedOrRestricted
        case notDetermined
        case temporarilyUnavailable
    }

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation?, Never>?
    private var timeoutTask: Task<Void, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    var currentState: WidgetLocationState {
        guard CLLocationManager.locationServicesEnabled() else {
            return .deniedOrRestricted
        }

        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            if manager.isAuthorizedForWidgetUpdates {
                let reduced = manager.accuracyAuthorization == .reducedAccuracy
                return .authorized(reducedAccuracy: reduced)
            } else {
                return .appAuthorizedWidgetDenied
            }
        case .denied, .restricted:
            return .deniedOrRestricted
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .deniedOrRestricted
        }
    }

    func requestOneShotLocation(timeoutSeconds: TimeInterval = 4.0) async -> CLLocation? {
        let state = currentState
        guard case .authorized = state else {
            #if DEBUG
            Self.logger.debug("Widget location not requested because state is \(String(describing: state), privacy: .public)")
            #endif
            return nil
        }

        return await withCheckedContinuation { cont in
            self.continuation = cont
            self.manager.requestLocation()

            self.timeoutTask?.cancel()
            self.timeoutTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                guard !Task.isCancelled else { return }
                await self?.handleTimeout()
            }
        }
    }

    private func handleTimeout() {
        if let cont = continuation {
            #if DEBUG
            Self.logger.notice("Widget location request timed out")
            #endif
            continuation = nil
            manager.stopUpdatingLocation()
            cont.resume(returning: nil)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            self.timeoutTask?.cancel()
            guard let cont = self.continuation else { return }
            self.continuation = nil
            let loc = locations.last
            #if DEBUG
            if let loc {
                Self.logger.debug("Widget location received: lat=\(loc.coordinate.latitude), lon=\(loc.coordinate.longitude)")
            }
            #endif
            cont.resume(returning: loc)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.timeoutTask?.cancel()
            #if DEBUG
            Self.logger.error("Widget location failed: \(error.localizedDescription, privacy: .public)")
            #endif
            guard let cont = self.continuation else { return }
            self.continuation = nil
            cont.resume(returning: nil)
        }
    }
}
