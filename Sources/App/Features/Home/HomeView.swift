import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 30)) { timeline in
                ScrollView {
                    VStack(spacing: 22) {
                        header
                        SolarHero(
                            now: timeline.date,
                            items: model.todayItems,
                            city: model.cityName,
                            timeZone: model.timeZone
                        )
                        nextCard(now: timeline.date)
                        zmanList(now: timeline.date)

                        Text("נתוני הזמנים באדיבות Hebcal.com")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 24)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                }
                .background(Color.zmanBackground.ignoresSafeArea())
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
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).locale(Locale(identifier: "he_IL"))))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(hebrewDate)
                    .font(.title3.bold())
            }
            Spacer()
            if model.isLoading {
                ProgressView()
            } else {
                Label(model.cityName, systemImage: "location.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var hebrewDate: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .hebrew)
        formatter.locale = Locale(identifier: "he_IL")
        formatter.dateStyle = .long
        return formatter.string(from: .now)
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
}

private struct SolarHero: View {
    let now: Date
    let items: [ZmanItem]
    let city: String
    let timeZone: TimeZone

    private var sunrise: Date? { items.first { $0.key == "sunrise" }?.date }
    private var sunset: Date? { items.first { $0.key == "sunset" }?.date }
    private var progress: Double { SolarMath.progress(now: now, sunrise: sunrise, sunset: sunset) }

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack {
                    HorizonArcShape()
                        .stroke(Color.zmanInk.opacity(0.12), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    HorizonArcShape()
                        .trim(from: 0, to: progress)
                        .stroke(
                            LinearGradient(colors: [Color.yellow, Color.zmanOrange], startPoint: .trailing, endPoint: .leading),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )

                    if let sunrise {
                        label("זריחה", sunrise)
                            .position(x: geometry.size.width - 50, y: geometry.size.height - 12)
                    }
                    if let sunset {
                        label("שקיעה", sunset)
                            .position(x: 50, y: geometry.size.height - 12)
                    }
                    if let sunrise, let sunset, now >= sunrise, now <= sunset {
                        Circle()
                            .fill(Color.zmanOrange)
                            .frame(width: 30, height: 30)
                            .overlay(Image(systemName: "sun.max.fill").font(.caption).foregroundStyle(.white))
                            .shadow(color: .orange.opacity(0.25), radius: 12)
                            .position(SolarMath.point(progress: progress, size: geometry.size))
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
