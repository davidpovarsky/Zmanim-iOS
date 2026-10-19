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
                let effectiveDate = effectiveDate(for: timeline.date)
                let sunrise = ZmanDayResolver.sunrise(from: model.todayItems, date: effectiveDate, timeZone: model.timeZone)
                let sunset = ZmanDayResolver.sunset(from: model.todayItems, date: effectiveDate, timeZone: model.timeZone)
                let nextResult = NextZmanResolver.resolve(
                    allItems: model.allItems,
                    now: effectiveDate,
                    timeZone: model.timeZone
                )

                let headerTextColor = ZmanimSkyBackdrop.headerColor(
                    for: effectiveDate,
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
                            date: effectiveDate,
                            timeZone: model.timeZone,
                            cityName: model.cityName,
                            presentation: model.weatherModel.presentation,
                            isLoading: model.isLoading,
                            textColor: headerTextColor,
                            onWeatherTap: {
                                isWeatherPopupPresented = true
                            }
                        )

                        SolarHero(
                            now: effectiveDate,
                            items: model.todayItems,
                            city: model.cityName,
                            timeZone: model.timeZone
                        )

                        NextZmanCard(
                            result: nextResult,
                            isLoading: model.isLoading,
                            errorMessage: model.errorMessage,
                            timeZone: model.timeZone
                        )

                        ZmanimDayList(
                            items: model.todayItems,
                            now: effectiveDate,
                            timeZone: model.timeZone
                        )

                        VStack(spacing: 4) {
                            Text("נתוני הזמנים באדיבות Hebcal.com")
                            if model.weatherModel.isAvailable {
                                Text(model.weatherModel.presentation?.attribution ?? WeatherSnapshot.attribution)
                            }
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 24)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                }
                .background {
                    ZStack(alignment: .top) {
                        Color.zmanBackground.ignoresSafeArea()
                        if model.weatherModel.isAvailable {
                            ZmanimSkyBackdrop(
                                date: effectiveDate,
                                timeZone: model.timeZone,
                                sunrise: sunrise,
                                sunset: sunset,
                                condition: model.weatherModel.condition,
                                cloudCover: model.weatherModel.cloudCover,
                                isPaused: model.weatherModel.previewOverride != nil
                            )
                        }
                    }
                }
                .onAppear {
                    model.checkDayRollover(now: timeline.date)
                }
                .onChange(of: timeline.date) { _, newDate in
                    model.checkDayRollover(now: newDate)
                }
            }
            .navigationTitle("זמנים")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        model.refresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }

                #if DEBUG
                ToolbarItem(placement: .topBarTrailing) {
                    weatherPreviewMenu
                }
                #endif
            }
            .overlay {
                WeatherDetailPopup(
                    presentation: model.weatherModel.presentation,
                    isPresented: $isWeatherPopupPresented
                )
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    model.checkDayRollover(now: Date())
                }
            }
        }
    }

    private func effectiveDate(for date: Date) -> Date {
        #if DEBUG
        if let preview = model.weatherModel.previewOverride {
            let rise = model.todayItems.first { $0.key == "sunrise" }?.date
            let set = model.todayItems.first { $0.key == "sunset" }?.date
            return preview.simulatedDate(for: date, sunrise: rise, sunset: set)
        }
        #endif
        return date
    }

    #if DEBUG
    private var weatherPreviewMenu: some View {
        Menu {
            Button("מזג אוויר חי (ברירת מחדל)") {
                model.weatherModel.setPreview(nil)
            }
            Divider()
            ForEach(WeatherScenePreview.allCases) { preview in
                Button(preview.rawValue) {
                    model.weatherModel.setPreview(preview)
                }
            }
        } label: {
            Image(systemName: "cloud.sun.fill")
        }
    }
    #endif
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
                        label("זריחה", sunrise)
                            .position(x: arc.startPoint.x + 24, y: arc.base + 16)
                    }
                    if let sunset {
                        label("שקיעה", sunset)
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
