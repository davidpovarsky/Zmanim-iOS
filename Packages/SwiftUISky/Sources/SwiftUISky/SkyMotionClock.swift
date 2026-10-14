import Foundation

/// Accumulates only active time, including when the view initially appears paused.
struct SkyMotionClock {
    private var anchor: Date?
    private var elapsed: TimeInterval = 0

    mutating func setAnimating(_ isAnimating: Bool, at date: Date) {
        if isAnimating {
            if anchor == nil { anchor = date }
        } else if let anchor {
            elapsed += max(0, date.timeIntervalSince(anchor))
            self.anchor = nil
        }
    }

    func time(at date: Date) -> TimeInterval {
        elapsed + (anchor.map { max(0, date.timeIntervalSince($0)) } ?? 0)
    }
}
