import SwiftUI

public struct ZmanCardModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public init() {}

    public func body(content: Content) -> some View {
        let cardShape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        content
            .background(
                cardShape
                    .fill(Color.zmanCard.opacity(reduceTransparency ? 1.0 : 0.78))
                    .overlay(
                        cardShape
                            .stroke(Color.zmanInk.opacity(0.12), lineWidth: 1)
                    )
            )
    }
}

extension View {
    public func zmanCard() -> some View {
        modifier(ZmanCardModifier())
    }
}
