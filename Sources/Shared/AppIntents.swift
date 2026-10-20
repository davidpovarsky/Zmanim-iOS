import AppIntents
import WidgetKit
struct ToggleQuickReminderIntent: AppIntent {
    static var title: LocalizedStringResource = LocalizedStringResource("widget.intent.toggle_reminder_title", defaultValue: "הפעל או כבה תזכורת מהירה")
    func perform() async throws -> some IntentResult {
        AppGroupStore.quickReminderEnabled.toggle()
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct OpenZmanimIntent: AppIntent {
    static var title: LocalizedStringResource = LocalizedStringResource("widget.intent.open_zmanim_title", defaultValue: "פתח את זמנים")
    static var openAppWhenRun = true
    func perform() async throws -> some IntentResult {
        .result()
    }
}
