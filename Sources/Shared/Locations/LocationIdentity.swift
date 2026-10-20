import Foundation

/// Canonical identity for locations used in snapshot storage and retrieval.
/// Distinguishes between device GPS and explicitly saved cities.
public enum LocationIdentity: Hashable, Codable, Sendable, CustomStringConvertible {
    case gps
    case savedCity(id: String)

    public var canonicalStorageKey: String {
        switch self {
        case .gps:
            return "snapshot_current"
        case .savedCity(let id):
            return "snapshot_city_\(id)"
        }
    }

    public var isGPS: Bool {
        if case .gps = self { return true }
        return false
    }

    public var savedCityID: String? {
        if case .savedCity(let id) = self { return id }
        return nil
    }

    public var description: String {
        switch self {
        case .gps:
            return "gps"
        case .savedCity(let id):
            return "savedCity(\(id))"
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case id
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        if type == "savedCity" {
            let id = try container.decode(String.self, forKey: .id)
            self = .savedCity(id: id)
        } else {
            self = .gps
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .gps:
            try container.encode("gps", forKey: .type)
        case .savedCity(let id):
            try container.encode("savedCity", forKey: .type)
            try container.encode(id, forKey: .id)
        }
    }
}

extension LocationChoice {
    public var identity: LocationIdentity {
        switch self {
        case .current:
            return .gps
        case .savedCity(let id):
            return .savedCity(id: id)
        }
    }
}

extension LocationIdentity {
    public var choice: LocationChoice {
        switch self {
        case .gps:
            return .current
        case .savedCity(let id):
            return .savedCity(id: id)
        }
    }
}
