import SwiftUI

extension View {
    /// Reports the iOS 27 system preference for reduced resource usage, the
    /// signal the system raises under thermal or battery pressure and in supported scenes. Animated skies
    /// treat it like Low Power Mode. Older systems never report `true`.
    func onSystemPrefersReducedResourceUsageChange(_ action: @escaping (Bool) -> Void) -> some View {
        modifier(ReducedResourceUsageReporter(onChange: action))
    }
}

private struct ReducedResourceUsageReporter: ViewModifier {
    let onChange: (Bool) -> Void

    func body(content: Content) -> some View {
        // The environment key exists only in the iOS 27 SDK (Swift 6.4). A
        // release Xcode 26 build must still compile for the App Store, so
        // the SDK check sits beside the runtime check.
        #if compiler(>=6.4)
        if #available(iOS 27.0, macOS 27.0, *) {
            content.modifier(ReducedResourceUsageEnvironmentReporter(onChange: onChange))
        } else {
            content
        }
        #else
        content
        #endif
    }
}

#if compiler(>=6.4)
@available(iOS 27.0, macOS 27.0, *)
private struct ReducedResourceUsageEnvironmentReporter: ViewModifier {
    @Environment(\.systemPrefersReducedResourceUsage) private var prefersReducedResourceUsage
    let onChange: (Bool) -> Void

    func body(content: Content) -> some View {
        content
            .onAppear { onChange(prefersReducedResourceUsage) }
            .onChange(of: prefersReducedResourceUsage) { _, value in
                onChange(value)
            }
    }
}
#endif
