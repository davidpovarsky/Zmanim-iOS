import OneBusAwayWeatherUI
import SwiftUI
import SwiftUISky

public struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @State private var isWeatherPopupPresented = false
    @State private var isAddCitySheetPresented = false

    public init() {}

    public var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 30)) { timeline in
                homeTimelineContent(for: timeline.date)
            }
            .navigationTitle(Text("app_name"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        model.refresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .overlay {
                WeatherDetailPopup(
                    display: model.weatherModel.weatherDisplay,
                    isPresented: $isWeatherPopupPresented
                )
            }
            .sheet(isPresented: $isAddCitySheetPresented) {
                AddSavedCitySheet { resolved in
                    Task {
                        await model.selectFixedLocation(resolved)
                    }
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    model.checkDayRollover(now: Date())
                    Task {
                        await model.refreshWeather(force: false)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func homeTimelineContent(for timelineDate: Date) -> some View {
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
            condition: model.weatherModel.condition,
            cloudCover: model.weatherModel.cloudCover,
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
                    display: model.weatherModel.weatherDisplay,
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
            homeBackdrop(date: timelineDate, sunrise: sunrise, sunset: sunset)
        }
        .onAppear {
            model.checkDayRollover(now: timelineDate)
        }
    }

    @ViewBuilder
    private func homeBackdrop(date: Date, sunrise: Date?, sunset: Date?) -> some View {
        ZmanimSkyBackdrop(
            date: date,
            timeZone: model.timeZone,
            sunrise: sunrise,
            sunset: sunset,
            condition: model.weatherModel.condition,
            cloudCover: model.weatherModel.cloudCover
        )
    }

    private var homeAttributionFooter: some View {
        VStack(spacing: 4) {
            Text(LocalizedStringKey("zmanim_data_source"))
                .font(.caption2)
                .foregroundStyle(Color.secondary.opacity(0.8))

            if model.weatherModel.weatherDisplay != nil {
                Text(LocalizedStringKey("weather.source_attribution"))
                    .font(.caption2)
                    .foregroundStyle(Color.secondary.opacity(0.8))
            }
        }
        .padding(.vertical, 8)
    }
}
