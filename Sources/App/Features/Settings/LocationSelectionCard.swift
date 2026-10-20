import SwiftUI

public struct LocationSelectionCard: View {
    @Binding public var locationMode: LocationMode
    @Binding public var fixedCity: String
    public let currentCityName: String
    public let onSelectLocation: (ResolvedLocation) -> Void

    @StateObject private var searchService = CitySearchService()
    @State private var searchText: String = ""
    @State private var isResolving: Bool = false
    @State private var selectionError: String? = nil

    public init(
        locationMode: Binding<LocationMode>,
        fixedCity: Binding<String>,
        currentCityName: String,
        onSelectLocation: @escaping (ResolvedLocation) -> Void
    ) {
        self._locationMode = locationMode
        self._fixedCity = fixedCity
        self.currentCityName = currentCityName
        self.onSelectLocation = onSelectLocation
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(LocalizedStringKey("settings.my_city"), systemImage: "location.circle.fill")
                .font(.title2.bold())
                .foregroundStyle(Color.zmanInk)

            Picker(String(localized: "settings.location_source"), selection: $locationMode) {
                ForEach(LocationMode.allCases) {
                    Text($0.title).tag($0)
                }
            }
            .pickerStyle(.segmented)

            if locationMode == .fixed {
                fixedCityContent
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .foregroundStyle(Color.zmanOrange)
                    Text(currentCityName)
                        .foregroundStyle(Color.zmanInk)
                }
                .font(.subheadline)
            }
        }
        .padding(18)
        .zmanCard()
    }

    @ViewBuilder
    private var fixedCityContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(String(localized: "settings.search_city"), text: $searchText)
                    .textFieldStyle(.plain)
                    .onChange(of: searchText) { _, newValue in
                        selectionError = nil
                        searchService.updateQuery(newValue)
                    }

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        searchService.clear()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color.zmanBackground, in: RoundedRectangle(cornerRadius: 12))

            if isResolving {
                HStack {
                    ProgressView()
                    Text(NSLocalizedString("settings.resolving_location", value: "מאמת מיקום…", comment: ""))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            if let error = selectionError ?? searchService.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if !searchService.suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(searchService.suggestions) { suggestion in
                        Button {
                            select(suggestion: suggestion)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(suggestion.title)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Color.zmanInk)
                                    if !suggestion.subtitle.isEmpty {
                                        Text(suggestion.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.left")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 4)
                        }
                        .buttonStyle(.plain)

                        if suggestion.id != searchService.suggestions.last?.id {
                            Divider()
                        }
                    }
                }
                .padding(8)
                .background(Color.zmanBackground, in: RoundedRectangle(cornerRadius: 12))
            } else if !fixedCity.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.zmanOrange)
                    Text(fixedCity)
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.zmanInk)
                }
            }
        }
    }

    private func select(suggestion: CitySearchSuggestion) {
        isResolving = true
        selectionError = nil
        Task {
            do {
                let resolved = try await searchService.resolve(suggestion: suggestion)
                onSelectLocation(resolved)
                fixedCity = resolved.displayName
                searchText = ""
                searchService.clear()
            } catch {
                selectionError = error.localizedDescription
            }
            isResolving = false
        }
    }
}
