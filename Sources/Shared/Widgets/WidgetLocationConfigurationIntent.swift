import AppIntents
import Foundation

public struct WidgetLocationConfigurationIntent: WidgetConfigurationIntent {
    public static var title: LocalizedStringResource = LocalizedStringResource("widget.configuration_title", defaultValue: "הגדרת מיקום הווידג'ט")
    public static var description = IntentDescription(LocalizedStringResource("widget.configuration_desc", defaultValue: "בחר את מקור המיקום של הווידג'ט: ברירת מחדל, מיקום נוכחי או עיר שמורה."))

    @Parameter(title: LocalizedStringResource("widget.location_param_title", defaultValue: "מיקום"))
    public var location: WidgetLocationEntity?

    public init() {
        self.location = nil
    }

    public init(location: WidgetLocationEntity?) {
        self.location = location
    }
}
