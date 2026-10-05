#if DEBUG
import SwiftUI
import UserNotifications

struct DebugDiagnosticsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var notificationAuthStatus = "בדיקה…"
    @State private var registeredCategories: [String] = []

    var body: some View {
        List {
            Section("Main App") {
                LabeledContent("Bundle Identifier", value: Bundle.main.bundleIdentifier ?? "nil")
                LabeledContent("Build Version", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "nil")
                LabeledContent("App Group Available", value: AppGroupStore.isAvailable ? "כן (Yes)" : "לא (No - sideload issue)")
                LabeledContent("Notification Status", value: notificationAuthStatus)
                LabeledContent("Registered Categories", value: registeredCategories.joined(separator: ", "))
            }

            Section("Widget Data") {
                let snapshot = AppGroupStore.loadSnapshot()
                LabeledContent("Last Snapshot City", value: snapshot?.cityName ?? "אין נתונים")
                LabeledContent("Zmanim Count", value: "\(snapshot?.items.count ?? 0)")
                if let updatedAt = snapshot?.updatedAt {
                    LabeledContent("Timestamp", value: DateFormatter.localizedString(from: updatedAt, dateStyle: .short, timeStyle: .medium))
                } else {
                    LabeledContent("Timestamp", value: "—")
                }
                LabeledContent("Data Source", value: dataSourceDescription(snapshot))
            }

            Section("Notification Content Extension") {
                LabeledContent("Expected Category", value: NotificationSchedulerConstants.categoryID)
                let mainID = Bundle.main.bundleIdentifier ?? "com.davidpovarsky.Zmanim"
                LabeledContent("Expected Extension ID", value: "\(mainID).NotificationContent")
                LabeledContent("Expected Widgets ID", value: "\(mainID).Widgets")
            }

            Section("Diagnostics Actions") {
                Button("שלח התראת בדיקה (3 שניות)") {
                    Task {
                        await model.sendTestNotification()
                    }
                }
                Button("רענן בדיקות") {
                    Task {
                        await checkStatus()
                    }
                }
            }
        }
        .navigationTitle("דיאגנוסטיקה (DEBUG)")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await checkStatus()
        }
    }

    private func checkStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized:
            notificationAuthStatus = "Authorized (מאושר)"
        case .denied:
            notificationAuthStatus = "Denied (נדחה)"
        case .notDetermined:
            notificationAuthStatus = "Not Determined"
        case .provisional:
            notificationAuthStatus = "Provisional"
        case .ephemeral:
            notificationAuthStatus = "Ephemeral"
        @unknown default:
            notificationAuthStatus = "Unknown"
        }

        let categories = await UNUserNotificationCenter.current().notificationCategories()
        registeredCategories = categories.map(\.identifier).sorted()
    }

    private func dataSourceDescription(_ snapshot: ZmanSnapshot?) -> String {
        guard let snapshot else { return "ללא נתונים" }
        let isToday = Calendar.current.isDate(snapshot.updatedAt, inSameDayAs: Date())
        if isToday {
            return AppGroupStore.isAvailable ? "App Group (טרי מהיום)" : "Local Cache"
        } else {
            return "Stale Cache (מיום קודם)"
        }
    }
}
#endif
