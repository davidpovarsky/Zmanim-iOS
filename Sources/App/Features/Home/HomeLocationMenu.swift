import SwiftUI

public struct HomeLocationMenu: View {
    public let currentCityName: String
    public let isGPSActive: Bool
    public let activeChoice: LocationChoice
    public let defaultChoice: LocationChoice
    public let savedCities: [SavedCity]
    public let textColor: Color
    public let onSelectChoice: (LocationChoice) -> Void
    public let onAddCityTap: () -> Void

    public init(
        currentCityName: String,
        isGPSActive: Bool,
        activeChoice: LocationChoice,
        defaultChoice: LocationChoice,
        savedCities: [SavedCity],
        textColor: Color,
        onSelectChoice: @escaping (LocationChoice) -> Void,
        onAddCityTap: @escaping () -> Void
    ) {
        self.currentCityName = currentCityName
        self.isGPSActive = isGPSActive
        self.activeChoice = activeChoice
        self.defaultChoice = defaultChoice
        self.savedCities = savedCities
        self.textColor = textColor
        self.onSelectChoice = onSelectChoice
        self.onAddCityTap = onAddCityTap
    }

    public var body: some View {
        Menu {
            // Option 1: Current GPS location
            Button {
                onSelectChoice(.current)
            } label: {
                HStack {
                    Text(LocalizedStringKey("location.current"))
                    if activeChoice.isCurrent {
                        Image(systemName: "checkmark")
                    }
                    if defaultChoice.isCurrent {
                        Text("(\(NSLocalizedString("location.default", value: "ברירת מחדל", comment: "")))")
                    }
                }
            }

            if !savedCities.isEmpty {
                Divider()

                // Section: Saved cities
                ForEach(savedCities) { city in
                    Button {
                        onSelectChoice(.savedCity(id: city.id))
                    } label: {
                        HStack {
                            Text(city.name)
                            if activeChoice.savedCityID == city.id {
                                Image(systemName: "checkmark")
                            }
                            if defaultChoice.savedCityID == city.id {
                                Text("(\(NSLocalizedString("location.default", value: "ברירת מחדל", comment: "")))")
                            }
                        }
                    }
                }
            }

            Divider()

            // Option 3: Add city
            Button {
                onAddCityTap()
            } label: {
                Label(LocalizedStringKey("location.add_city"), systemImage: "plus")
            }
        } label: {
            HStack(spacing: 4) {
                if isGPSActive {
                    Image(systemName: "location.fill")
                        .font(.caption)
                }
                Text(currentCityName)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(textColor.opacity(0.95))
            .padding(.vertical, 6)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
            .frame(minHeight: 44)
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel(String(format: NSLocalizedString("location.menu_a11y", value: "מיקום נוכחי: %@. הקש לשינוי מיקום.", comment: ""), currentCityName))
    }
}
