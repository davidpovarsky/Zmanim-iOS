import SwiftUI

/// Painterly cloud sprites for `SkyBackdrop`.
///
/// These are SwiftUI views handed to `Canvas` as symbols, so each one is
/// rasterized once (blur included) and then stamped many times per frame.
/// That keeps the soft, watercolor edge of the reference look without paying
/// for a blur filter on every frame.
enum SkySpriteID: Hashable {
    case cloud(Int)
    case wisp(Int)
}

/// One cumulus mass: a bright body with a lavender-tinted underside.
/// Natural size is 320×180pt; the renderer scales it to the placement width.
struct SkyCloudSprite: View {
    let variant: Int
    let bodyColor: Color
    let shade: Color

    nonisolated static let size = CGSize(width: 320, height: 180)

    private struct Lobe {
        let x: CGFloat
        let y: CGFloat
        let width: CGFloat
        let height: CGFloat
    }

    private var lobes: [Lobe] {
        let seed = SkyNoise.seed(21, variant)
        var lobes: [Lobe] = [Lobe(x: 160, y: 116, width: 190, height: 72)]
        for index in 0 ..< 6 {
            let slot = index * 4
            lobes.append(
                Lobe(
                    x: 100 + 120 * SkyNoise.value(seed, slot),
                    y: 64 + 50 * SkyNoise.value(seed, slot + 1),
                    width: 64 + 70 * SkyNoise.value(seed, slot + 2),
                    height: 62 + 46 * SkyNoise.value(seed, slot + 3)
                )
            )
        }
        return lobes
    }

    var body: some View {
        let lobes = lobes
        ZStack {
            // Soft halo so the mass never ends in a hard edge.
            ForEach(lobes.indices, id: \.self) { index in
                Ellipse()
                    .fill(bodyColor.opacity(0.35))
                    .frame(width: lobes[index].width * 1.2, height: lobes[index].height * 1.2)
                    .position(x: lobes[index].x, y: lobes[index].y)
            }
            .blur(radius: 22)

            // Shaded underside, offset down and slightly blurred.
            ForEach(lobes.indices, id: \.self) { index in
                Ellipse()
                    .fill(shade.opacity(0.75))
                    .frame(width: lobes[index].width * 0.95, height: lobes[index].height * 0.85)
                    .position(x: lobes[index].x, y: lobes[index].y + 18)
            }
            .blur(radius: 12)

            // Lit body.
            ForEach(lobes.indices, id: \.self) { index in
                Ellipse()
                    .fill(bodyColor)
                    .frame(width: lobes[index].width, height: lobes[index].height)
                    .position(x: lobes[index].x, y: lobes[index].y)
            }
            .blur(radius: 11)
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }
}

/// A long, thin streak of cloud. Natural size is 360×48pt.
struct SkyWispSprite: View {
    let variant: Int
    let color: Color

    nonisolated static let size = CGSize(width: 360, height: 48)

    var body: some View {
        let seed = SkyNoise.seed(23, variant)
        ZStack {
            ForEach(0 ..< 3, id: \.self) { index in
                let slot = index * 3
                Ellipse()
                    .fill(color.opacity(0.55 + 0.35 * SkyNoise.value(seed, slot)))
                    .frame(
                        width: 200 + 150 * SkyNoise.value(seed, slot + 1),
                        height: 8 + 12 * SkyNoise.value(seed, slot + 2)
                    )
                    .position(
                        x: 120 + 120 * SkyNoise.value(seed, slot + 1),
                        y: 14 + 20 * SkyNoise.value(seed, slot + 2)
                    )
            }
        }
        .blur(radius: 7)
        .frame(width: Self.size.width, height: Self.size.height)
    }
}
