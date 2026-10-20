import SwiftUI

public struct CustomReminderCard: View {
    public let onAdd: (NotificationRule) -> Void

    @State private var customName: String = ""
    @State private var customKey: String = "sunrise"
    @State private var customOffset: Int = -15

    public init(onAdd: @escaping (NotificationRule) -> Void) {
        self.onAdd = onAdd
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(LocalizedStringKey("settings.custom_reminders"), systemImage: "sparkles")
                .font(.title2.bold())
                .foregroundStyle(Color.zmanInk)

            Text("settings.custom_reminders_desc")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField(String(localized: "settings.reminder_name_placeholder"), text: $customName)
                .textFieldStyle(.roundedBorder)

            Picker(String(localized: "settings.base_zman"), selection: $customKey) {
                ForEach(HebcalService.definitions, id: \.key) { def in
                    Text(def.localizedTitle()).tag(def.key)
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    stepperView
                    addButton
                }
                VStack(spacing: 10) {
                    stepperView
                    addButton
                }
            }
        }
        .padding(18)
        .zmanCard()
    }

    private var stepperView: some View {
        Stepper(value: $customOffset, in: -120...120, step: 5) {
            Text(offsetText(customOffset))
                .monospacedDigit()
                .foregroundStyle(Color.zmanInk)
        }
    }

    private var addButton: some View {
        Button {
            addCustom()
        } label: {
            Label(LocalizedStringKey("settings.add_reminder"), systemImage: "plus")
        }
        .buttonStyle(.bordered)
        .disabled(customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private func addCustom() {
        let trimmed = customName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let newRule = NotificationRule(
            id: "custom-\(UUID().uuidString)",
            zmanKey: customKey,
            title: trimmed,
            offsetMinutes: customOffset,
            isEnabled: true,
            customName: trimmed
        )
        onAdd(newRule)
        customName = ""
    }

    private func offsetText(_ v: Int) -> String {
        if v == 0 {
            return NSLocalizedString("settings.exact_time", comment: "")
        } else if v < 0 {
            return String(format: NSLocalizedString("settings.minutes_before_format", comment: ""), abs(v))
        } else {
            return String(format: NSLocalizedString("settings.minutes_after_format", comment: ""), abs(v))
        }
    }
}
