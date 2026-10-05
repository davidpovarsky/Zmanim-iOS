import SwiftUI
@main struct ZmanimApp:App { @StateObject private var model=AppModel(); var body:some Scene { WindowGroup { RootView().environmentObject(model).environment(\.layoutDirection,.rightToLeft).preferredColorScheme(.light).task{model.start()} } } }
struct RootView:View { var body:some View { TabView { HomeView().tabItem{Label("היום",systemImage:"sun.max.fill")}; NotificationSettingsView().tabItem{Label("התראות",systemImage:"bell.badge.fill")} }.tint(.zmanIndigo) } }
