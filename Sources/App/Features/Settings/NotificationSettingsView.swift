import SwiftUI

struct NotificationSettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    NotificationsHero {
                        Task { await model.sendTestNotification() }
                    }

                    LocationSelectionCard(model: model)

                    SpecialDaysCard(
                        masterEnabled: $model.settings.specialDaysMasterEnabled,
                        shabbatEnabled: $model.settings.shabbatEnabled,
                        holidayEnabled: $model.settings.holidayEnabled
                    )

                    DailyRulesCard(rules: $model.settings.rules)

                    CustomReminderCard { newRule in
                        model.settings.rules.append(newRule)
                    }

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
}
