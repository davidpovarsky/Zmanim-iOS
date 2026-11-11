import Combine
import Foundation
import MapKit
import CoreLocation

public struct CitySearchSuggestion: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String

    public init(title: String, subtitle: String) {
        self.id = "\(title)-\(subtitle)"
        self.title = title
        self.subtitle = subtitle
    }

    public var fullDescription: String {
        subtitle.isEmpty ? title : "\(title), \(subtitle)"
    }
}

public enum CitySearchError: LocalizedError, Equatable {
    case noResults
    case invalidCoordinates
    case timeZoneNotFound
    case resolutionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .noResults:
            return NSLocalizedString("search.no_results", comment: "")
        case .invalidCoordinates:
            return NSLocalizedString("search.invalid_coords", comment: "")
        case .timeZoneNotFound:
            return NSLocalizedString("search.timezone_not_found", comment: "")
        case .resolutionFailed(let reason):
            return String(format: NSLocalizedString("search.failed_format", comment: ""), reason)
        }
    }
}

@MainActor
public final class CitySearchService: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published public private(set) var suggestions: [CitySearchSuggestion] = []
    @Published public private(set) var isSearching: Bool = false
    @Published public private(set) var errorMessage: String? = nil

    private let completer = MKLocalSearchCompleter()
    private var rawCompletions: [String: MKLocalSearchCompletion] = [:]
    private var debounceCancellable: AnyCancellable?
    private let querySubject = PassthroughSubject<String, Never>()

    public override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]

        debounceCancellable = querySubject
            .debounce(for: .milliseconds(250), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] query in
                self?.executeCompleterSearch(query: query)
            }
    }

    public func updateQuery(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            completer.cancel()
            suggestions = []
            rawCompletions.removeAll()
            isSearching = false
            errorMessage = nil
            return
        }
        isSearching = true
        errorMessage = nil
        querySubject.send(trimmed)
    }

    public func clear() {
        completer.cancel()
        suggestions = []
        rawCompletions.removeAll()
        isSearching = false
        errorMessage = nil
    }

    private func executeCompleterSearch(query: String) {
        guard !query.isEmpty else {
            suggestions = []
            rawCompletions.removeAll()
            isSearching = false
            return
        }
        completer.queryFragment = query
    }

    // MARK: - MKLocalSearchCompleterDelegate

    nonisolated public func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        var results: [CitySearchSuggestion] = []
        var completionMap: [String: MKLocalSearchCompletion] = [:]

        for completion in completer.results {
            let suggestion = CitySearchSuggestion(title: completion.title, subtitle: completion.subtitle)
            results.append(suggestion)
            completionMap[suggestion.id] = completion
        }

        Task { @MainActor in
            self.rawCompletions = completionMap
            self.suggestions = results
            self.isSearching = false
            self.errorMessage = results.isEmpty ? NSLocalizedString("search.no_results", comment: "") : nil
        }
    }

    nonisolated public func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.isSearching = false
            self.errorMessage = error.localizedDescription
        }
    }

    // MARK: - Resolve selected completion to verified location with coordinates & timezone

    public func resolve(suggestion: CitySearchSuggestion) async throws -> ResolvedLocation {
        let request: MKLocalSearch.Request
        if let completion = rawCompletions[suggestion.id] {
            request = MKLocalSearch.Request(completion: completion)
        } else {
            request = MKLocalSearch.Request()
            request.naturalLanguageQuery = suggestion.fullDescription
        }

        let search = MKLocalSearch(request: request)
        let response = try await search.start()

        guard let firstItem = response.mapItems.first else {
            throw CitySearchError.noResults
        }

        let placemark = firstItem.placemark
        let coord = placemark.coordinate

        guard CLLocationCoordinate2DIsValid(coord) else {
            throw CitySearchError.invalidCoordinates
        }

        // Determine authentic time zone
        var resolvedTimeZone = placemark.timeZone
        if resolvedTimeZone == nil {
            let loc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            let geoPlacemarks = try? await CLGeocoder().reverseGeocodeLocation(loc)
            resolvedTimeZone = geoPlacemarks?.first?.timeZone
        }

        guard let timeZone = resolvedTimeZone else {
            throw CitySearchError.timeZoneNotFound
        }

        let displayName = placemark.locality ?? placemark.name ?? suggestion.title

        return ResolvedLocation(
            displayName: displayName,
            latitude: coord.latitude,
            longitude: coord.longitude,
            timeZoneID: timeZone.identifier,
            source: .fixedSearch
        )
    }
}
