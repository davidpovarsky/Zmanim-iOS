import SwiftUI

public struct SpecialDaysCard: View {
    @Binding public var masterEnabled: Bool
    @Binding public var shabbatEnabled: Bool
    @Binding public var holidayEnabled: Bool

    public init(
        masterEnabled: Binding<Bool>,
        shabbatEnabled: Binding<Bool>,
        holidayEnabled: Binding<Bool>
    ) {
        self._masterEnabled = masterEnabled
        self._shabbatEnabled = shabbatEnabled
        self._holidayEnabled = holidayEnabled
    }

    public var body: some View {
        VStack(spacing: 0) {
            settingToggle(
                title: NSLocalizedString("settings.shabbat_holiday_alert", comment: ""),
                subtitle: NSLocalizedString("settings.shabbat_holiday_desc", comment: ""),
                icon: "calendar.badge.clock",
                isOn: $masterEnabled
            )

            if masterEnabled {
                Divider().padding(.horizontal, 16)

                settingToggle(
                    title: NSLocalizedString("settings.shabbat", comment: ""),
                    subtitle: NSLocalizedString("settings.shabbat_desc", comment: ""),
                    icon: "bell",
                    isOn: $shabbatEnabled
                )

                Divider().padding(.horizontal, 16)

                settingToggle(
                    title: NSLocalizedString("settings.holidays_fasts", comment: ""),
                    subtitle: NSLocalizedString("settings.holidays_fasts_desc", comment: ""),
                    icon: "sparkles",
                    isOn: $holidayEnabled
                )
            }
        }
        .zmanCard()
        .animation(.smooth(duration: 0.2), value: masterEnabled)
    }

    private func settingToggle(title: String, subtitle: String, icon: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(Color.zmanOrange)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.zmanInk)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
        }
        .padding(16)
    }
}
