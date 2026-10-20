import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension Color {
    /// Adaptive background color: warm cream in light mode, deep warm slate in dark mode.
    public static var zmanBackground: Color {
        #if canImport(UIKit)
        Color(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.11, green: 0.11, blue: 0.14, alpha: 1.0)
                : UIColor(red: 0.972, green: 0.966, blue: 0.936, alpha: 1.0)
        })
        #else
        Color(red: 0.972, green: 0.966, blue: 0.936)
        #endif
    }

    /// Adaptive card surface: light cream in light mode, dark elevated surface in dark mode.
    public static var zmanCard: Color {
        #if canImport(UIKit)
        Color(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.17, green: 0.17, blue: 0.22, alpha: 1.0)
                : UIColor(red: 0.965, green: 0.945, blue: 0.885, alpha: 1.0)
        })
        #else
        Color(red: 0.965, green: 0.945, blue: 0.885)
        #endif
    }

    /// Primary text/ink color: deep indigo/ink in light mode, crisp off-white in dark mode.
    public static var zmanInk: Color {
        #if canImport(UIKit)
        Color(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.94, green: 0.94, blue: 0.97, alpha: 1.0)
                : UIColor(red: 0.105, green: 0.105, blue: 0.20, alpha: 1.0)
        })
        #else
        Color(red: 0.105, green: 0.105, blue: 0.20)
        #endif
    }

    /// Brand accent indigo: royal indigo in light mode, softer indigo in dark mode.
    public static var zmanIndigo: Color {
        #if canImport(UIKit)
        Color(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.45, green: 0.45, blue: 0.85, alpha: 1.0)
                : UIColor(red: 0.245, green: 0.245, blue: 0.56, alpha: 1.0)
        })
        #else
        Color(red: 0.245, green: 0.245, blue: 0.56)
        #endif
    }

    /// Solar orange accent: vibrant daylight tone.
    public static let zmanOrange = Color(red: 0.93, green: 0.50, blue: 0.20)

    /// Twilight / night shade.
    public static let zmanNight = Color(red: 0.35, green: 0.29, blue: 0.55)
}
