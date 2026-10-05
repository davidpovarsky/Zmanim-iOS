import AppIntents
import WidgetKit
struct ToggleQuickReminderIntent:AppIntent { static var title:LocalizedStringResource="הפעל או כבה תזכורת מהירה"; func perform() async throws -> some IntentResult { AppGroupStore.quickReminderEnabled.toggle(); WidgetCenter.shared.reloadAllTimelines(); return .result() } }
struct OpenZmanimIntent:AppIntent { static var title:LocalizedStringResource="פתח את זמנים"; static var openAppWhenRun=true; func perform() async throws -> some IntentResult { .result() } }
