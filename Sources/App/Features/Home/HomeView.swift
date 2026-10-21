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
                WeatherAwareHomeContent(
                    weather: model.weatherModel,
                    timelineDate: timeline.date,
                    isWeatherPopupPresented: $isWeatherPopupPresented,
                    isAddCitySheetPresented: $isAddCitySheetPresented,
                    colorScheme: colorScheme
                )
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
                WeatherAwarePopupOverlay(
                    weather: model.weatherModel,
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
}
