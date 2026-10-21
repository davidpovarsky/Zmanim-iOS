import AppIntents
import WidgetKit
struct ToggleQuickReminderIntent: AppIntent {
    static var title: LocalizedStringResource = LocalizedStringResource("widget.intent.toggle_reminder_title")
    func perform() async throws -> some IntentResult {
        AppGroupStore.quickReminderEnabled.toggle()
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct OpenZmanimIntent: AppIntent {
    static var title: LocalizedStringResource = LocalizedStringResource("widget.intent.open_zmanim_title")
    static var openAppWhenRun = true
    func perform() async throws -> some IntentResult {
        .result()
    }
}
