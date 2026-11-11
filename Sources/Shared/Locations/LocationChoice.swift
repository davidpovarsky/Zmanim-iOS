import Foundation

/// Represents the selection between device GPS location and a specific saved city.
public enum LocationChoice: Codable, Hashable, Sendable, Equatable {
    case current
    case savedCity(id: String)

    public var isCurrent: Bool {
        if case .current = self { return true }
        return false
    }

    public var savedCityID: String? {
        if case .savedCity(let id) = self { return id }
        return nil
    }

    public var storageKey: String {
        switch self {
        case .current:
            return "current"
        case .savedCity(let id):
            return "city_\(id)"
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
            self = .current
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .current:
            try container.encode("current", forKey: .type)
        case .savedCity(let id):
            try container.encode("savedCity", forKey: .type)
            try container.encode(id, forKey: .id)
        }
    }
}
