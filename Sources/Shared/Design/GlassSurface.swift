import SwiftUI

public struct GlassSurfaceModifier<S: Shape>: ViewModifier {
    public let shape: S
    public let isClear: Bool
    public let isInteractive: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public init(shape: S, isClear: Bool = false, isInteractive: Bool = false) {
        self.shape = shape
        self.isClear = isClear
        self.isInteractive = isInteractive
    }

    public var body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(Color.zmanCard, in: shape)
                .overlay(shape.stroke(Color.zmanInk.opacity(0.12), lineWidth: 1))
        } else {
            #if canImport(SwiftUI)
            if #available(iOS 26.0, *) {
                content
                    .glassEffect(isClear ? .clear : .regular, in: shape)
            } else {
                content
                    .background(isClear ? .ultraThinMaterial : .regularMaterial, in: shape)
                    .overlay(shape.stroke(Color.zmanInk.opacity(0.08), lineWidth: 0.5))
            }
            #else
            content
                .background(Color.zmanCard, in: shape)
            #endif
        }
    }
}

extension View {
    public func zmanGlass<S: Shape>(in shape: S, isClear: Bool = false, isInteractive: Bool = false) -> some View {
        modifier(GlassSurfaceModifier(shape: shape, isClear: isClear, isInteractive: isInteractive))
    }
}
