import SwiftUI
import WidgetKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        NotificationCoordinator.shared.install()
        return true
    }
}

@main
struct ZmanimApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    init() {
        NotificationCoordinator.shared.install()
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if let renderArg = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("-RenderWidget:") }) {
                let family = String(renderArg.dropFirst("-RenderWidget:".count))
                WidgetHarnessView(family: family, model: model)
                    .preferredColorScheme(.light)
                    .task { model.start() }
            } else {
                RootView()
                    .environmentObject(model)
                    .preferredColorScheme(.light)
                    .task {
                        if let previewArg = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("-WeatherPreview:") }) {
                            let key = String(previewArg.dropFirst("-WeatherPreview:".count))
                            if let preset = WeatherScenePreview.allCases.first(where: {
                                $0.rawValue == key || "\($0)".lowercased() == key.lowercased()
                            }) {
                                model.weatherModel.setPreview(preset)
                            }
                        }
                        model.start()
                    }
            }
            #else
            RootView()
                .environmentObject(model)
                .preferredColorScheme(.light)
                .task { model.start() }
            #endif
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label(LocalizedStringKey("today"), systemImage: "sun.max.fill") }
            NotificationSettingsView()
                .tabItem { Label(LocalizedStringKey("notifications"), systemImage: "bell.badge.fill") }
        }
        .tint(.zmanIndigo)
    }
}

#if DEBUG
struct WidgetHarnessView: View {
    let family: String
    @ObservedObject var model: AppModel

    var body: some View {
        ZStack {
            Color(red: 0.12, green: 0.14, blue: 0.18).ignoresSafeArea()
            VStack {
                Spacer()
                widgetCard
                Spacer()
            }
            .padding()
        }
    }

    @ViewBuilder
    private var widgetCard: some View {
        let snapshot = AppGroupStore.loadSnapshot() ?? ZmanSnapshot(
            cityName: model.cityName.isEmpty ? "ירושלים" : model.cityName,
            timeZoneID: model.timeZone.identifier,
            latitude: 31.778,
            longitude: 35.235,
            updatedAt: Date(),
            items: model.allItems
        )
        let entry = ZmanEntry(date: Date(), snapshot: snapshot, state: nil)

        switch family.lowercased() {
        case "small":
            ZmanWidgetView(entry: entry, explicitFamily: .systemSmall)
                .padding()
                .frame(width: 170, height: 170)
                .background(Color(red: 0.972, green: 0.966, blue: 0.936))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(radius: 8)
        case "large":
            ZmanWidgetView(entry: entry, explicitFamily: .systemLarge)
                .padding()
                .frame(width: 364, height: 382)
                .background(Color(red: 0.972, green: 0.966, blue: 0.936))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(radius: 8)
        case "extralarge":
            ZmanWidgetView(entry: entry, explicitFamily: .systemExtraLarge)
                .padding()
                .frame(width: 380, height: 382)
                .background(Color(red: 0.972, green: 0.966, blue: 0.936))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(radius: 8)
        default: // medium
            ZmanWidgetView(entry: entry, explicitFamily: .systemMedium)
                .padding()
                .frame(width: 364, height: 170)
                .background(Color(red: 0.972, green: 0.966, blue: 0.936))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(radius: 8)
        }
    }
}
#endif
