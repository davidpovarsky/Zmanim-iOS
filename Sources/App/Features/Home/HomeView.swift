import OneBusAwayWeatherUI
import SwiftUI
import SwiftUISky

public struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @State private var isWeatherPopupPresented = false

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
                    display: model.weatherModel.weatherDisplay,
                    isLoading: model.isLoading,
                    textColor: headerTextColor,
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
        .onChange(of: timelineDate) { _, newDate in
            model.checkDayRollover(now: newDate)
        }
    }

    @ViewBuilder
    private func homeBackdrop(date: Date, sunrise: Date?, sunset: Date?) -> some View {
        ZStack(alignment: .top) {
            Color.zmanBackground.ignoresSafeArea()
            if model.weatherModel.isAvailable {
                ZmanimSkyBackdrop(
                    date: date,
                    timeZone: model.timeZone,
                    sunrise: sunrise,
                    sunset: sunset,
                    condition: model.weatherModel.condition,
                    cloudCover: model.weatherModel.cloudCover,
                    isPaused: scenePhase != .active
                )
            }
        }
    }

    private var homeAttributionFooter: some View {
        VStack(spacing: 4) {
            Text("zmanim_data_source")
            if model.weatherModel.isAvailable {
                Text(model.weatherModel.weatherDisplay?.sourceAttribution ?? WeatherSnapshot.attribution)
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.bottom, 24)
    }
}

private struct SolarHero: View {
    let now: Date
    let items: [ZmanItem]
    let city: String
    let timeZone: TimeZone

    private var sunrise: Date? { items.first { $0.key == "sunrise" }?.date }
    private var sunset: Date? { items.first { $0.key == "sunset" }?.date }
    private var progress: Double { SolarArcGeometry.progress(now: now, sunrise: sunrise, sunset: sunset) }

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                let arc = SolarArcGeometry(size: geometry.size)
                let p = progress

                ZStack {
                    arc.fullPath()
                        .stroke(Color.zmanInk.opacity(0.14), style: StrokeStyle(lineWidth: 2, lineCap: .round))

                    if p > 0 {
                        arc.completedPath(progress: p)
                            .stroke(
                                LinearGradient(colors: [Color.yellow, Color.zmanOrange], startPoint: .leading, endPoint: .trailing),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                    }

                    if let sunrise {
                        label(NSLocalizedString("sunrise", comment: ""), sunrise)
                            .position(x: arc.startPoint.x + 24, y: arc.base + 16)
                    }
                    if let sunset {
                        label(NSLocalizedString("sunset", comment: ""), sunset)
                            .position(x: arc.endPoint.x - 24, y: arc.base + 16)
                    }
                    if let sunrise, let sunset, now >= sunrise, now <= sunset {
                        Circle()
                            .fill(Color.zmanOrange)
                            .frame(width: 30, height: 30)
                            .overlay(Image(systemName: "sun.max.fill").font(.caption).foregroundStyle(.white))
                            .shadow(color: .orange.opacity(0.3), radius: 8)
                            .position(arc.point(at: p))
                    }
                }
            }
            .frame(height: 145)

            Text(time(now))
                .font(.system(size: 44, weight: .regular, design: .rounded))
                .monospacedDigit()
            HStack(spacing: 4) {
                Image(systemName: "location.fill")
                Text(city)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    private func label(_ text: String, _ date: Date) -> some View {
        VStack(spacing: 1) {
            Text(text).font(.caption2)
            Text(time(date)).font(.caption.monospacedDigit().bold())
        }
        .foregroundStyle(.secondary)
    }

    private func time(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
