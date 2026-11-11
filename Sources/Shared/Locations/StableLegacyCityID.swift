import CryptoKit
import Foundation

/// Provides deterministic, process-stable identifiers for legacy migration and saved locations.
/// Replaces non-deterministic `String.hashValue` (SipHash) to guarantee consistent IDs
/// across App, Extension, and independent process lifecycles.
public enum StableLegacyCityID: Sendable {
    /// Generates a deterministic identifier derived from canonical city name, coordinates, and time zone.
    public static func generate(
        name: String,
        latitude: Double,
        longitude: Double,
        timeZoneID: String
    ) -> String {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let roundedLat = String(format: "%.4f", latitude)
        let roundedLon = String(format: "%.4f", longitude)
        let canonical = "\(cleanName)_\(roundedLat)_\(roundedLon)_\(timeZoneID)"

        let digest = SHA256.hash(data: Data(canonical.utf8))
        let hexString = digest.map { String(format: "%02x", $0) }.joined()
        let prefix = hexString.prefix(16)
        return "legacy_\(prefix)"
    }
}
