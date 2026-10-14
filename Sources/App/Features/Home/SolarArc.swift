import SwiftUI

/// Horizon arc shape adhering to the unified Bézier geometry.
/// Chronological progression: Sunrise on left -> Sunset on right.
public struct HorizonArcShape: Shape {
    public var progress: Double? = nil

    public init(progress: Double? = nil) {
        self.progress = progress
    }

    public func path(in rect: CGRect) -> Path {
        let geometry = SolarArcGeometry(size: rect.size)
        if let progress {
            return geometry.completedPath(progress: progress)
        } else {
            return geometry.fullPath()
        }
    }
}

public enum SolarMath {
    public static func progress(now: Date, sunrise: Date?, sunset: Date?) -> Double {
        SolarArcGeometry.progress(now: now, sunrise: sunrise, sunset: sunset)
    }

    public static func point(progress: Double, size: CGSize) -> CGPoint {
        let geometry = SolarArcGeometry(size: size)
        return geometry.point(at: progress)
    }
}
