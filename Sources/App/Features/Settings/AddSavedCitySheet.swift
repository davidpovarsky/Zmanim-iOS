import SwiftUI

public struct AddSavedCitySheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var searchService = CitySearchService()
    @State private var searchText: String = ""
    @State private var isResolving: Bool = false
    @State private var errorMessage: String? = nil

    public let onCityAdded: (ResolvedLocation) -> Void

    public init(onCityAdded: @escaping (ResolvedLocation) -> Void) {
        self.onCityAdded = onCityAdded
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchField
                    .padding()

                if isResolving {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text(NSLocalizedString("settings.resolving_location", value: "מאמת מיקום…", comment: ""))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                }

                if let error = errorMessage ?? searchService.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }

                List {
                    ForEach(searchService.suggestions) { suggestion in
                        Button {
                            selectSuggestion(suggestion)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(suggestion.title)
                                    .font(.headline)
                                    .foregroundStyle(Color.primary)
                                if !suggestion.subtitle.isEmpty {
                                    Text(suggestion.subtitle)
                                        .font(.subheadline)
                                        .foregroundStyle(Color.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle(LocalizedStringKey("location.add_city"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("location.cancel")) {
                        dismiss()
                    }
                }
            }
        }
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(String(localized: "settings.search_city"), text: $searchText)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .onChange(of: searchText) { _, newValue in
                    errorMessage = nil
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
        .padding(12)
        .background(Color.zmanBackground, in: RoundedRectangle(cornerRadius: 12))
    }

    private func selectSuggestion(_ suggestion: CitySearchSuggestion) {
        guard !isResolving else { return }
        isResolving = true
        errorMessage = nil

        Task {
            do {
                let resolved = try await searchService.resolve(suggestion: suggestion)
                isResolving = false
                onCityAdded(resolved)
                dismiss()
            } catch {
                isResolving = false
                errorMessage = error.localizedDescription
            }
        }
    }
}
