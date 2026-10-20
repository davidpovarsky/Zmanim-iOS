import SwiftUI

public struct ReminderRuleEditor: View {
    @Binding public var rule: NotificationRule
    private let presets = [0, -5, -10, -15, -20, -30, -45, -60]

    public init(rule: Binding<NotificationRule>) {
        self._rule = rule
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(Color.zmanIndigo)
                    .frame(width: 28)
                Text(rule.displayTitle)
                    .font(.headline)
                    .foregroundStyle(Color.zmanInk)
                Spacer()
                Toggle("", isOn: $rule.isEnabled)
                    .labelsHidden()
            }

            if rule.isEnabled {
                ViewThatFits(in: .horizontal) {
                    wideOffsetControls
                    compactOffsetControls
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(presets, id: \.self) { value in
                            Button(presetLabel(value)) {
                                rule.offsetMinutes = value
                            }
                            .buttonStyle(.bordered)
                            .tint(rule.offsetMinutes == value ? .zmanIndigo : .secondary)
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
        .padding(16)
        .animation(.smooth(duration: 0.2), value: rule.isEnabled)
    }

    private var wideOffsetControls: some View {
        HStack {
            Button {
                rule.offsetMinutes = max(-120, rule.offsetMinutes - 5)
            } label: {
                Image(systemName: "minus")
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.bordered)

            Text(offsetText)
                .frame(maxWidth: .infinity)
                .font(.headline.monospacedDigit())
                .foregroundStyle(Color.zmanInk)

            Button {
                rule.offsetMinutes = min(120, rule.offsetMinutes + 5)
            } label: {
                Image(systemName: "plus")
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.bordered)
        }
    }

    private var compactOffsetControls: some View {
        VStack(spacing: 8) {
            Text(offsetText)
                .font(.headline.monospacedDigit())
                .foregroundStyle(Color.zmanInk)
            HStack(spacing: 16) {
                Button {
                    rule.offsetMinutes = max(-120, rule.offsetMinutes - 5)
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.bordered)

                Button {
                    rule.offsetMinutes = min(120, rule.offsetMinutes + 5)
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var icon: String {
        rule.zmanKey.contains("tzeit") ? "moon" : "clock"
    }

    private var offsetText: String {
        if rule.offsetMinutes == 0 {
            return NSLocalizedString("settings.exact_time", value: "במדויק", comment: "")
        } else if rule.offsetMinutes < 0 {
            return String(format: NSLocalizedString("settings.minutes_before_format", value: "%d דק׳ לפני", comment: ""), abs(rule.offsetMinutes))
        } else {
            return String(format: NSLocalizedString("settings.minutes_after_format", value: "%d דק׳ אחרי", comment: ""), abs(rule.offsetMinutes))
        }
    }

    private func presetLabel(_ value: Int) -> String {
        if value == 0 {
            return NSLocalizedString("settings.exact_time", value: "במדויק", comment: "")
        } else {
            return String(format: NSLocalizedString("settings.minutes_before_format", value: "%d דק׳ לפני", comment: ""), abs(value))
        }
    }
}
