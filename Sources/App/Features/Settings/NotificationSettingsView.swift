import SwiftUI

struct NotificationSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var customName = ""
    @State private var customKey = "sunrise"
    @State private var customOffset = -15

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    hero
                    locationCard
                    specialCard
                    rulesCard
                    customCard
                    saveButton
                    #if DEBUG
                    NavigationLink(String(localized: "settings.debug_diagnostics")) {
                        DebugDiagnosticsView()
                    }
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                    #endif
                }
                .padding(18)
            }
            .background(Color.zmanBackground.ignoresSafeArea())
            .navigationTitle(Text("notifications"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var hero: some View {
        VStack(spacing: 12) {
            Text("settings.personal_alerts")
                .font(.caption)
                .tracking(3)
                .foregroundStyle(.secondary)
            Text("settings.my_notifications")
                .font(.system(size: 38, weight: .bold))
            Text("settings.notifications_desc")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button {
                Task { await model.sendTestNotification() }
            } label: {
                Label(LocalizedStringKey("settings.send_test_alert"), systemImage: "bell")
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 8)
    }

    private var locationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(LocalizedStringKey("settings.my_city"), systemImage: "location.circle.fill")
                .font(.title2.bold())
                .foregroundStyle(Color.zmanInk)
            Picker(String(localized: "settings.location_source"), selection: $model.settings.locationMode) {
                ForEach(LocationMode.allCases) {
                    Text($0.title).tag($0)
                }
            }
            .pickerStyle(.segmented)

            if model.settings.locationMode == .fixed {
                TextField(String(localized: "settings.search_city"), text: $model.settings.fixedCity)
                    .textFieldStyle(.roundedBorder)
            } else {
                Label(model.cityName, systemImage: "location.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .zmanCard()
    }

    private var specialCard: some View {
        VStack(spacing: 0) {
            settingToggle(
                title: NSLocalizedString("settings.shabbat_holiday_alert", comment: ""),
                subtitle: NSLocalizedString("settings.shabbat_holiday_desc", comment: ""),
                icon: "calendar.badge.clock",
                isOn: $model.settings.shabbatMasterEnabled
            )
            Divider()
            settingToggle(
                title: NSLocalizedString("settings.shabbat", comment: ""),
                subtitle: NSLocalizedString("settings.shabbat_desc", comment: ""),
                icon: "bell",
                isOn: $model.settings.shabbatMasterEnabled
            )
            Divider()
            settingToggle(
                title: NSLocalizedString("settings.holidays_fasts", comment: ""),
                subtitle: NSLocalizedString("settings.holidays_fasts_desc", comment: ""),
                icon: "calendar.badge.clock",
                isOn: $model.settings.holidayMasterEnabled
            )
        }
        .zmanCard()
    }

    private var rulesCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "clock").foregroundStyle(Color.zmanIndigo)
                VStack(alignment: .leading) {
                    Text("daily_zmanim").font(.title2.bold())
                    Text("settings.enable_zman_reminder").font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(18)

            Divider()

            ForEach($model.settings.rules) { $rule in
                RuleEditor(rule: $rule)
                if rule.id != model.settings.rules.last?.id {
                    Divider().padding(.horizontal, 16)
                }
            }
        }
        .zmanCard()
    }

    private var customCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(LocalizedStringKey("settings.custom_reminders"), systemImage: "sparkles")
                .font(.title2.bold())
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
            HStack {
                Stepper(value: $customOffset, in: -120...120, step: 5) {
                    Text(offsetText(customOffset)).monospacedDigit()
                }
                Button {
                    addCustom()
                } label: {
                    Label(LocalizedStringKey("settings.add_reminder"), systemImage: "plus")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(18)
        .zmanCard()
    }

    private var saveButton: some View {
        Button {
            Task { await model.saveSettings() }
        } label: {
            Label(LocalizedStringKey("settings.save_settings"), systemImage: "bell.badge")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .tint(.zmanIndigo)
        .controlSize(.large)
    }

    private func settingToggle(title: String, subtitle: String, icon: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Image(systemName: icon).foregroundStyle(Color.zmanOrange).frame(width: 34)
            VStack(alignment: .leading) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: isOn).labelsHidden()
        }
        .padding(16)
    }

    private func addCustom() {
        let name = customName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        model.settings.rules.append(.init(
            id: "custom-\(UUID().uuidString)",
            zmanKey: customKey,
            title: name,
            offsetMinutes: customOffset,
            isEnabled: true,
            customName: name
        ))
        customName = ""
    }

    private func offsetText(_ v: Int) -> String {
        if v == 0 {
            return NSLocalizedString("settings.exact_time", value: "במדויק", comment: "")
        } else if v < 0 {
            return String(format: NSLocalizedString("settings.minutes_before_format", value: "%d דק׳ לפני", comment: ""), abs(v))
        } else {
            return String(format: NSLocalizedString("settings.minutes_after_format", value: "%d דק׳ אחרי", comment: ""), abs(v))
        }
    }
}

private struct RuleEditor: View {
    @Binding var rule: NotificationRule
    private let presets = [0, -5, -10, -15, -20, -30, -45, -60]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon).foregroundStyle(.secondary).frame(width: 28)
                Text(rule.displayTitle).font(.headline)
                Spacer()
                Toggle("", isOn: $rule.isEnabled).labelsHidden()
            }
            if rule.isEnabled {
                HStack {
                    Button {
                        rule.offsetMinutes = max(-120, rule.offsetMinutes - 5)
                    } label: {
                        Image(systemName: "minus").frame(width: 32, height: 32)
                    }
                    .buttonStyle(.bordered)

                    Text(offsetText).frame(maxWidth: .infinity).font(.headline.monospacedDigit())

                    Button {
                        rule.offsetMinutes = min(120, rule.offsetMinutes + 5)
                    } label: {
                        Image(systemName: "plus").frame(width: 32, height: 32)
                    }
                    .buttonStyle(.bordered)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(presets, id: \.self) { value in
                            Button(presetLabel(value)) {
                                rule.offsetMinutes = value
                            }
                            .buttonStyle(.bordered)
                            .tint(rule.offsetMinutes == value ? .zmanIndigo : .secondary)
                        }
                    }
                }
            }
        }
        .padding(16)
    }

    private var icon: String { rule.zmanKey.contains("tzeit") ? "moon" : "clock" }

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
