import SwiftUI

/// Accessible button style with minimum 44pt touch target and haptic/press feedback.
public struct ZmanProminentButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minHeight: 44)
            .background(Color.zmanIndigo, in: Capsule())
            .opacity(configuration.isPressed ? 0.82 : 1.0)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

public struct ZmanSecondaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .foregroundStyle(Color.zmanInk)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(minHeight: 44)
            .background(Color.zmanCard, in: Capsule())
            .overlay(Capsule().stroke(Color.zmanInk.opacity(0.12), lineWidth: 1))
            .opacity(configuration.isPressed ? 0.80 : 1.0)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == ZmanProminentButtonStyle {
    public static var zmanProminent: ZmanProminentButtonStyle { ZmanProminentButtonStyle() }
}

extension ButtonStyle where Self == ZmanSecondaryButtonStyle {
    public static var zmanSecondary: ZmanSecondaryButtonStyle { ZmanSecondaryButtonStyle() }
}
