import Foundation

public enum LocationStoreError: LocalizedError, Equatable, Sendable {
    case storeUnavailable
    case encodingFailed(String)
    case corruptData(String)
    case readbackVerificationFailed
    case cityNotFound(String)
    case persistenceFailed

    public var errorDescription: String? {
        switch self {
        case .storeUnavailable:
            return NSLocalizedString("location.store_unavailable", comment: "")
        case .encodingFailed(let details):
            return "\(NSLocalizedString("location.save_failed", comment: "")) (\(details))"
        case .corruptData(let details):
            return "\(NSLocalizedString("location.store_unavailable", comment: "")) (\(details))"
        case .readbackVerificationFailed:
            return NSLocalizedString("location.save_failed", comment: "")
        case .cityNotFound:
            return NSLocalizedString("location.city_removed_widget", comment: "")
        case .persistenceFailed:
            return NSLocalizedString("location.save_failed", comment: "")
        }
    }
}
