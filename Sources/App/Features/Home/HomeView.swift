import SwiftUI
import SwiftUISky

public struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    public var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 30)) { timeline in
                let effectiveDate = effectiveDate(for: timeline.date)
                let sunrise = model.todayItems.first { $0.key == "sunrise" }?.date
                let sunset = model.todayItems.first { $0.key == "sunset" }?.date

                ScrollView {
                    VStack(spacing: 20) {
                        header(for: effectiveDate, sunrise: sunrise, sunset: sunset)
                        SolarHero(
                            now: effectiveDate,
                            items: model.todayItems,
                            city: model.cityName,
                            timeZone: model.timeZone
                        )
                        nextCard(now: effectiveDate)
                        zmanList(now: effectiveDate)

                        VStack(spacing: 4) {
                            Text("נתוני הזמנים באדיבות Hebcal.com")
                            Text("נתוני מזג אוויר באדיבות Open-Meteo.com")
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
                        ZmanimSkyBackdrop(
                            date: effectiveDate,
                            sunrise: sunrise,
                            sunset: sunset,
                            condition: model.weatherModel.condition,
                            cloudCover: model.weatherModel.cloudCover,
                            isPaused: model.weatherModel.previewOverride != nil
                        )
                    }
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

    private func header(for date: Date, sunrise: Date?, sunset: Date?) -> some View {
        let textColor = ZmanimSkyBackdrop.headerColor(
            for: date,
            sunrise: sunrise,
            sunset: sunset,
            condition: model.weatherModel.condition,
            cloudCover: model.weatherModel.cloudCover,
            colorScheme: colorScheme
        )

        return HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(date.formatted(.dateTime.weekday(.wide).locale(Locale(identifier: "he_IL"))))
                    .font(.subheadline)
                    .foregroundStyle(textColor.opacity(0.85))
                Text(hebrewDate(for: date))
                    .font(.title3.bold())
                    .foregroundStyle(textColor)
            }
            Spacer()
            if model.isLoading {
                ProgressView().tint(textColor)
            } else {
                HStack(spacing: 6) {
                    Label(model.cityName, systemImage: "location.fill")
                        .font(.subheadline)
                        .foregroundStyle(textColor.opacity(0.85))
                    Text("·")
                        .foregroundStyle(textColor.opacity(0.60))
                    Text(model.weatherModel.condition.rawValue)
                        .font(.caption.bold())
                        .foregroundStyle(textColor.opacity(0.85))
                }
            }
        }
    }

    private func hebrewDate(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .hebrew)
        formatter.locale = Locale(identifier: "he_IL")
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }

    @ViewBuilder
    private func nextCard(now: Date) -> some View {
        if let next = model.todayItems.first(where: { $0.date > now }) {
            HStack(spacing: 14) {
                Image(systemName: next.icon)
                    .font(.title2)
                    .foregroundStyle(Color.zmanOrange)
                    .frame(width: 48, height: 48)
                    .background(Color.zmanOrange.opacity(0.12), in: RoundedRectangle(cornerRadius: 15))
                VStack(alignment: .leading) {
                    Text("הזמן הבא").font(.caption).foregroundStyle(.secondary)
                    Text(next.hebrewTitle).font(.headline)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text(time(next.date)).font(.title2.monospacedDigit().bold())
                    Text(next.date, style: .relative).font(.caption).foregroundStyle(Color.zmanOrange)
                }
            }
            .padding(18)
            .zmanCard()
        } else {
            Text(model.errorMessage ?? "טוען את זמני היום…")
                .frame(maxWidth: .infinity)
                .padding(22)
                .zmanCard()
        }
    }

    private func zmanList(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("זמני היום").font(.title3.bold())
            VStack(spacing: 0) {
                ForEach(model.todayItems) { item in
                    HStack {
                        Image(systemName: item.icon)
                            .foregroundStyle(item.date > now ? Color.zmanIndigo : Color.secondary)
                            .frame(width: 28)
                        VStack(alignment: .leading) {
                            Text(item.hebrewTitle).font(.body.weight(.medium))
                            Text(item.englishTitle).font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(time(item.date)).monospacedDigit().font(.body.weight(.semibold))
                    }
                    .opacity(item.date < now ? 0.48 : 1)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)

                    if item.id != model.todayItems.last?.id {
                        Divider().padding(.leading, 48)
                    }
                }
            }
            .zmanCard()
        }
    }

    private func time(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = model.timeZone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
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
            Label(city, systemImage: "location.fill")
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
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
