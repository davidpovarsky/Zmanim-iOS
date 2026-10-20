import CoreLocation
import Foundation

public enum SnapshotValidationError: Error, Equatable, Sendable {
    case identityMismatch(expected: LocationIdentity, actual: LocationIdentity?)
    case coordinatesMismatch(distanceMeters: Double, maxAllowedMeters: Double)
    case invalidTimeZone(String)
    case timeZoneMismatch(expected: String, actual: String)
    case emptyItems
    case insufficientCoverage(requiredDate: Date)
    case missingTomorrowCoverage(requiredTomorrow: Date)
    case demoDataRejected
}

public struct SnapshotValidator {
    /// Pure validation function to guarantee a snapshot is authentic, matches the target,
    /// has a valid timezone, and provides sufficient date coverage without cross-city contamination.
    public static func validate(
        snapshot: ZmanSnapshot,
        for identity: LocationIdentity,
        expectedCoordinates: CLLocationCoordinate2D? = nil,
        maxCoordinateDistanceMeters: Double = 50_000,
        expectedTimeZoneID: String? = nil,
        requiredDate: Date = Date(),
        requireTomorrowCoverage: Bool = false
    ) -> Result<ZmanSnapshot, SnapshotValidationError> {
        // 1. Strictly reject demo fixtures or mock snapshots in production paths
        if snapshot.locationSignature == "demo" {
            return .failure(.demoDataRejected)
        }

        // 2. Identity check: if metadata is present, it must strictly match the target
        if let sourceIdentity = snapshot.sourceIdentity, sourceIdentity != identity {
            return .failure(.identityMismatch(expected: identity, actual: sourceIdentity))
        }

        // 3. Time zone verification: must be a genuine, system-valid identifier
        guard let validZone = TimeZone(identifier: snapshot.timeZoneID) else {
            return .failure(.invalidTimeZone(snapshot.timeZoneID))
        }

        if let expectedTimeZoneID, !expectedTimeZoneID.isEmpty {
            if validZone.identifier != expectedTimeZoneID {
                // Secondary check: verify if secondsFromGMT match as well
                let expectedZone = TimeZone(identifier: expectedTimeZoneID)
                if expectedZone == nil || validZone.secondsFromGMT(for: requiredDate) != expectedZone?.secondsFromGMT(for: requiredDate) {
                    return .failure(.timeZoneMismatch(expected: expectedTimeZoneID, actual: snapshot.timeZoneID))
                }
            }
        }

        // 4. Coordinates verification: within tolerance if expected coordinates provided
        if let expected = expectedCoordinates {
            let snapLoc = CLLocation(latitude: snapshot.latitude, longitude: snapshot.longitude)
            let expLoc = CLLocation(latitude: expected.latitude, longitude: expected.longitude)
            let distance = snapLoc.distance(from: expLoc)
            if distance > maxCoordinateDistanceMeters {
                return .failure(.coordinatesMismatch(distanceMeters: distance, maxAllowedMeters: maxCoordinateDistanceMeters))
            }
        }

        // 5. Items verification: non-empty and valid dates
        guard !snapshot.items.isEmpty else {
            return .failure(.emptyItems)
        }

        // 6. Date coverage verification: must cover the required day
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = validZone

        let hasRequiredDay = snapshot.items.contains { cal.isDate($0.date, inSameDayAs: requiredDate) }
        guard hasRequiredDay else {
            return .failure(.insufficientCoverage(requiredDate: requiredDate))
        }

        if requireTomorrowCoverage {
            guard let tomorrow = cal.date(byAdding: .day, value: 1, to: requiredDate) else {
                return .failure(.missingTomorrowCoverage(requiredTomorrow: requiredDate))
            }
            let hasTomorrow = snapshot.items.contains { cal.isDate($0.date, inSameDayAs: tomorrow) }
            guard hasTomorrow else {
                return .failure(.missingTomorrowCoverage(requiredTomorrow: tomorrow))
            }
        }

        return .success(snapshot)
    }

    /// Convenience check for freshness: valid identity, authentic data, and covers today.
    public static func isFresh(
        snapshot: ZmanSnapshot,
        for identity: LocationIdentity,
        now: Date = Date(),
        requireTomorrow: Bool = false
    ) -> Bool {
        switch validate(snapshot: snapshot, for: identity, requiredDate: now, requireTomorrowCoverage: requireTomorrow) {
        case .success:
            return true
        case .failure:
            return false
        }
    }

    /// Pure structural and identity validation check.
    public static func isValid(
        snapshot: ZmanSnapshot,
        for identity: LocationIdentity,
        now: Date? = nil
    ) -> Bool {
        if let now {
            return isFresh(snapshot: snapshot, for: identity, now: now)
        }
        if snapshot.locationSignature == "demo" { return false }
        if let sourceIdentity = snapshot.sourceIdentity, sourceIdentity != identity { return false }
        guard TimeZone(identifier: snapshot.timeZoneID) != nil else { return false }
        return !snapshot.items.isEmpty
    }
}
