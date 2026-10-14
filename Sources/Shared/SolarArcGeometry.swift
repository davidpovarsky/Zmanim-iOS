import CoreGraphics
import Foundation
import SwiftUI

/// Shared mathematical foundation for solar arc geometry and sun marker placement.
/// Guaranteed identical calculations across the containing application, widgets, and notification content.
public struct SolarArcGeometry: Sendable, Equatable {
    public let size: CGSize
    public let margin: CGFloat
    public let base: CGFloat
    public let arcHeight: CGFloat

    public var startPoint: CGPoint { CGPoint(x: margin, y: base) }
    public var endPoint: CGPoint { CGPoint(x: size.width - margin, y: base) }
    public var controlPoint: CGPoint { CGPoint(x: size.width / 2, y: base - 2 * arcHeight) }
    public var apexPoint: CGPoint { CGPoint(x: size.width / 2, y: base - arcHeight) }

    public init(
        size: CGSize,
        margin: CGFloat? = nil,
        base: CGFloat? = nil,
        arcHeight: CGFloat? = nil
    ) {
        self.size = size
        let m = margin ?? max(12, min(size.width * 0.08, 28))
        self.margin = m
        let b = base ?? (size.height - max(14, min(size.height * 0.22, 32)))
        self.base = b
        let h = arcHeight ?? max(20, b - max(12, min(size.height * 0.12, 18)))
        self.arcHeight = h
    }

    /// Evaluates quadratic Bézier curve: B(t) = (1-t)²P0 + 2(1-t)tP1 + t²P2
    public func point(at progress: Double) -> CGPoint {
        let t = CGFloat(max(0, min(1, progress)))
        let u = 1 - t
        let p0 = startPoint
        let p1 = controlPoint
        let p2 = endPoint

        let x = u * u * p0.x + 2 * u * t * p1.x + t * t * p2.x
        let y = u * u * p0.y + 2 * u * t * p1.y + t * t * p2.y
        return CGPoint(x: x, y: y)
    }

    /// Full horizon arc path (P0 -> P2 with control point P1)
    public func fullPath() -> Path {
        var path = Path()
        path.move(to: startPoint)
        path.addQuadCurve(to: endPoint, control: controlPoint)
        return path
    }

    /// Completed progress arc path using de Casteljau subdivision to guarantee exact matching with marker center.
    public func completedPath(progress: Double) -> Path {
        let t = CGFloat(max(0, min(1, progress)))
        guard t > 0 else { return Path() }

        var path = Path()
        path.move(to: startPoint)

        let p0 = startPoint
        let p1 = controlPoint
        let q0 = CGPoint(x: (1 - t) * p0.x + t * p1.x, y: (1 - t) * p0.y + t * p1.y)
        let bt = point(at: Double(t))

        path.addQuadCurve(to: bt, control: q0)
        return path
    }

    /// Halachic daylight progress calculation:
    /// progress = clamp((now - sunrise) / (sunset - sunrise), 0, 1)
    public static func progress(now: Date, sunrise: Date?, sunset: Date?) -> Double {
        guard let sunrise, let sunset, sunset > sunrise else { return 0 }
        let elapsed = now.timeIntervalSince(sunrise)
        let total = sunset.timeIntervalSince(sunrise)
        return min(max(elapsed / total, 0), 1)
    }
}
