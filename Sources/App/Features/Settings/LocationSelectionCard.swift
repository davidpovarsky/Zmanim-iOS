import SwiftUI

public struct LocationSelectionCard: View {
    @ObservedObject public var model: AppModel

    @State private var isAddCitySheetPresented: Bool = false
    @State private var cityToDelete: SavedCity? = nil
    @State private var isConfirmingDelete: Bool = false

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(LocalizedStringKey("settings.my_city"), systemImage: "location.circle.fill")
                .font(.title2.bold())
                .foregroundStyle(Color.zmanInk)

            Text(LocalizedStringKey("settings.location_source"))
                .font(.subheadline)
                .foregroundStyle(Color.secondary)

            // 1. Current GPS Location Option
            Button {
                Task {
                    await model.setDefaultLocationChoice(.current)
                }
            } label: {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundStyle(Color.zmanOrange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(LocalizedStringKey("location.current"))
                            .font(.headline)
                            .foregroundStyle(Color.zmanInk)
                        Text(model.cityName)
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                    }
                    Spacer()
                    if model.locationPreferences.defaultChoice.isCurrent {
                        Label(LocalizedStringKey("location.default"), systemImage: "checkmark.circle.fill")
                            .font(.subheadline.bold())
                            .foregroundStyle(Color.zmanIndigo)
                    }
                }
                .padding(12)
                .background(Color.zmanBackground, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            // 2. Saved Cities Section
            if !model.locationPreferences.savedCities.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(LocalizedStringKey("location.saved_cities"))
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.zmanInk)

                    ForEach(model.locationPreferences.savedCities) { city in
                        let isDefault = model.locationPreferences.defaultChoice.savedCityID == city.id
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(city.name)
                                    .font(.headline)
                                    .foregroundStyle(Color.zmanInk)
                                Text(city.timeZoneID)
                                    .font(.caption2)
                                    .foregroundStyle(Color.secondary)
                            }
                            Spacer()

                            if isDefault {
                                Label(LocalizedStringKey("location.default"), systemImage: "checkmark.circle.fill")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(Color.zmanIndigo)
                            } else {
                                Button {
                                    Task {
                                        await model.setDefaultLocationChoice(.savedCity(id: city.id))
                                    }
                                } label: {
                                    Text(LocalizedStringKey("location.set_default"))
                                        .font(.caption.bold())
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.zmanIndigo.opacity(0.12), in: Capsule())
                                        .foregroundStyle(Color.zmanIndigo)
                                }
                                .buttonStyle(.plain)
                            }

                            Button {
                                cityToDelete = city
                                isConfirmingDelete = true
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption)
                                    .foregroundStyle(.red.opacity(0.8))
                                    .padding(6)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(LocalizedStringKey("location.remove_city"))
                        }
                        .padding(10)
                        .background(Color.zmanBackground, in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }

            // 3. Add City Button
            Button {
                isAddCitySheetPresented = true
            } label: {
                Label(LocalizedStringKey("location.add_city"), systemImage: "plus.circle.fill")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
            .tint(Color.zmanIndigo)
        }
        .padding(18)
        .zmanCard()
        .sheet(isPresented: $isAddCitySheetPresented) {
            AddSavedCitySheet { resolved in
                Task {
                    let newCity = await model.addSavedCity(
                        name: resolved.displayName,
                        latitude: resolved.latitude,
                        longitude: resolved.longitude,
                        timeZoneID: resolved.timeZoneID
                    )
                    await model.setDefaultLocationChoice(.savedCity(id: newCity.id))
                    await model.selectActiveChoice(.savedCity(id: newCity.id))
                }
            }
        }
        .confirmationDialog(
            String(format: NSLocalizedString("location.confirm_remove_city", value: "האם להסיר את %@ מרשימת הערים השמורות?", comment: ""), cityToDelete?.name ?? ""),
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            if let city = cityToDelete {
                Button(LocalizedStringKey("location.remove"), role: .destructive) {
                    Task {
                        await model.removeSavedCity(id: city.id)
                    }
                }
            }
            Button(LocalizedStringKey("location.cancel"), role: .cancel) {}
        }
    }
}
