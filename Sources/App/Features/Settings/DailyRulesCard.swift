import SwiftUI

public struct DailyRulesCard: View {
    @Binding public var rules: [NotificationRule]

    public init(rules: Binding<[NotificationRule]>) {
        self._rules = rules
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "clock")
                    .foregroundStyle(Color.zmanIndigo)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text("daily_zmanim")
                        .font(.title2.bold())
                        .foregroundStyle(Color.zmanInk)
                    Text("settings.enable_zman_reminder")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(18)

            Divider()

            ForEach($rules) { $rule in
                ReminderRuleEditor(rule: $rule)
                if rule.id != rules.last?.id {
                    Divider().padding(.horizontal, 16)
                }
            }
        }
        .zmanCard()
    }
}
