/// Decides whether the sky may move right now.
///
/// The sky is ambience, so it yields to every system and product signal that
/// says "spend nothing": Reduce Motion, an inactive scene, Low Power Mode, and
/// the host view being hidden.
struct SkyMotionPolicy: Equatable {
    var reduceMotion: Bool
    var isVisible: Bool
    var isSceneActive: Bool
    var isLowPowerModeEnabled: Bool
    /// The page is busy with its own motion, such as widget editing, and the
    /// sky must not compete for frames.
    var isFrozen = false

    var isAnimating: Bool {
        !reduceMotion && isVisible && isSceneActive && !isLowPowerModeEnabled && !isFrozen
    }

    /// Meteors are the one element with no static counterpart, so any pause,
    /// not only Reduce Motion, removes them rather than freezing one mid-streak.
    var allowsMeteor: Bool { isAnimating }
}
