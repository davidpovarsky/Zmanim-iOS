import AppIntents
import Foundation

public struct WidgetLocationConfigurationIntent: WidgetConfigurationIntent {
    public static var title: LocalizedStringResource = LocalizedStringResource("widget.configuration_title")
    public static var description = IntentDescription(LocalizedStringResource("widget.configuration_desc"))

    @Parameter(title: LocalizedStringResource("widget.location_param_title"))
    public var location: WidgetLocationEntity?

    public init() {
        self.location = nil
    }

    public init(location: WidgetLocationEntity?) {
        self.location = location
    }
}
