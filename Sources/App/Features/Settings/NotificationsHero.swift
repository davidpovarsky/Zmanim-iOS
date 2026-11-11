import SwiftUI

public struct NotificationsHero: View {
    public let onSendTestNotification: () -> Void

    public init(onSendTestNotification: @escaping () -> Void) {
        self.onSendTestNotification = onSendTestNotification
    }

    public var body: some View {
        VStack(spacing: 12) {
            Text("settings.personal_alerts")
                .font(.caption)
                .tracking(3)
                .foregroundStyle(.secondary)

            Text("settings.my_notifications")
                .font(.system(size: 36, weight: .bold))
                .lineLimit(1)

            Text("settings.notifications_desc")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button {
                onSendTestNotification()
            } label: {
                Label(LocalizedStringKey("settings.send_test_alert"), systemImage: "bell")
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 8)
    }
}
