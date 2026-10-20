import SwiftUI

/// Defines container width breakpoints for adaptive iPad windowed apps, Split View, and Stage Manager.
public enum ContainerWidthClass: Equatable, Sendable {
    /// Narrow window / Split View (e.g. < 500pt)
    case compact
    /// Intermediate window / half-screen iPad (500pt ..< 800pt)
    case intermediate
    /// Spacious window / full-screen iPad (>= 800pt)
    case spacious

    public static func resolve(width: CGFloat) -> ContainerWidthClass {
        if width < 500 {
            return .compact
        } else if width < 800 {
            return .intermediate
        } else {
            return .spacious
        }
    }
}

private struct ContainerWidthKey: EnvironmentKey {
    static let defaultValue: CGFloat = 390
}

private struct ContainerWidthClassKey: EnvironmentKey {
    static let defaultValue: ContainerWidthClass = .compact
}

extension EnvironmentValues {
    public var containerWidth: CGFloat {
        get { self[ContainerWidthKey.self] }
        set { self[ContainerWidthKey.self] = newValue }
    }

    public var containerWidthClass: ContainerWidthClass {
        get { self[ContainerWidthClassKey.self] }
        set { self[ContainerWidthClassKey.self] = newValue }
    }
}

/// A container that measures its available width and propagates both `containerWidth`
/// and `containerWidthClass` to its subviews via the SwiftUI environment.
public struct AdaptiveContainer<Content: View>: View {
    private let content: (ContainerWidthClass) -> Content

    public init(@ViewBuilder content: @escaping (ContainerWidthClass) -> Content) {
        self.content = content
    }

    public var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let widthClass = ContainerWidthClass.resolve(width: width)

            content(widthClass)
                .environment(\.containerWidth, width)
                .environment(\.containerWidthClass, widthClass)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
