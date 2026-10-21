import OneBusAwayWeatherUI
import SwiftUI
import SwiftUISky

public struct WeatherAwareHomeContent: View {
    @ObservedObject var weather: WeatherSceneModel
    @EnvironmentObject private var model: AppModel
    let timelineDate: Date
    @Binding var isWeatherPopupPresented: Bool
    @Binding var isAddCitySheetPresented: Bool
    let colorScheme: ColorScheme

    public init(
        weather: WeatherSceneModel,
        timelineDate: Date,
        isWeatherPopupPresented: Binding<Bool>,
        isAddCitySheetPresented: Binding<Bool>,
        colorScheme: ColorScheme
    ) {
        self.weather = weather
        self.timelineDate = timelineDate
        self._isWeatherPopupPresented = isWeatherPopupPresented
        self._isAddCitySheetPresented = isAddCitySheetPresented
        self.colorScheme = colorScheme
    }

    public var body: some View {
        let sunrise = ZmanDayResolver.sunrise(from: model.todayItems, date: timelineDate, timeZone: model.timeZone)
        let sunset = ZmanDayResolver.sunset(from: model.todayItems, date: timelineDate, timeZone: model.timeZone)
        let nextResult = NextZmanResolver.resolve(
            allItems: model.allItems,
            now: timelineDate,
            timeZone: model.timeZone
        )

        let headerTextColor = ZmanimSkyBackdrop.headerColor(
            for: timelineDate,
            timeZone: model.timeZone,
            sunrise: sunrise,
            sunset: sunset,
            condition: weather.isAvailable ? weather.condition : nil,
            cloudCover: weather.effectiveCloudCover,
            colorScheme: colorScheme
        )

        ScrollView {
            VStack(spacing: 20) {
                HomeHeader(
                    date: timelineDate,
                    timeZone: model.timeZone,
                    cityName: model.cityName,
                    isGPSActive: model.isGPSActive,
                    activeChoice: model.activeChoice,
                    defaultChoice: model.locationPreferences.defaultChoice,
                    savedCities: model.locationPreferences.savedCities,
                    display: weather.weatherDisplay,
                    isLoading: model.isLoading,
                    textColor: headerTextColor,
                    onSelectChoice: { choice in
                        Task { await model.selectActiveChoice(choice) }
                    },
                    onAddCityTap: {
                        isAddCitySheetPresented = true
                    },
                    onWeatherTap: {
                        isWeatherPopupPresented = true
                    }
                )

                SolarHero(
                    now: timelineDate,
                    items: model.todayItems,
                    city: model.cityName,
                    timeZone: model.timeZone
                )

                NextZmanCard(
                    result: nextResult,
                    isLoading: model.isLoading,
                    errorMessage: model.errorMessage,
                    timeZone: model.timeZone,
                    now: timelineDate
                )

                ZmanimDayList(
                    items: model.todayItems,
                    now: timelineDate,
                    timeZone: model.timeZone
                )

                homeAttributionFooter
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
        }
        .background {
            ZmanimSkyBackdrop(
                date: timelineDate,
                timeZone: model.timeZone,
                sunrise: sunrise,
                sunset: sunset,
                condition: weather.isAvailable ? weather.condition : nil,
                cloudCover: weather.effectiveCloudCover
            )
        }
        .onAppear {
            model.checkDayRollover(now: timelineDate)
        }
    }

    private var homeAttributionFooter: some View {
        VStack(spacing: 4) {
            Text(LocalizedStringKey("zmanim_data_source"))
                .font(.caption2)
                .foregroundStyle(Color.secondary.opacity(0.8))

            if weather.weatherDisplay != nil {
                Text(LocalizedStringKey("weather.source_attribution"))
                    .font(.caption2)
                    .foregroundStyle(Color.secondary.opacity(0.8))
            }
        }
        .padding(.vertical, 8)
    }
}

public struct WeatherAwarePopupOverlay: View {
    @ObservedObject var weather: WeatherSceneModel
    @Binding var isPresented: Bool

    public init(weather: WeatherSceneModel, isPresented: Binding<Bool>) {
        self.weather = weather
        self._isPresented = isPresented
    }

    public var body: some View {
        WeatherDetailPopup(
            display: weather.weatherDisplay,
            isPresented: $isPresented
        )
    }
}
