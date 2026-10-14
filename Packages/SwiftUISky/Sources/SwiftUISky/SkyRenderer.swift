import SwiftUI

/// Draws one `SkyScene` frame into a `Canvas`.
public enum SkyRenderer {
    private static let starColor = Color(red: 0.96, green: 0.96, blue: 1)
    private static let meteorColor = Color(red: 0.98, green: 0.99, blue: 1)
    private static let rainColor = Color(red: 0.72, green: 0.80, blue: 0.92)
    private static let snowColor = Color(red: 0.95, green: 0.97, blue: 1.0)

    public static func draw(_ scene: SkyScene, in context: inout GraphicsContext, size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        drawSky(scene.palette, in: &context, size: size)
        drawHorizonGlow(scene.horizonGlow, palette: scene.palette, in: &context, size: size)
        drawStars(scene.stars, in: &context, size: size)
        if let meteor = scene.meteor {
            drawMeteor(meteor, in: &context, size: size)
        }
        drawWisps(scene.wisps, palette: scene.palette, in: &context, size: size)
        drawClouds(scene.clouds, palette: scene.palette, in: &context, size: size)

        if !scene.rainStreaks.isEmpty {
            drawRain(scene.rainStreaks, in: &context, size: size)
        }
        if !scene.snowFlakes.isEmpty {
            drawSnow(scene.snowFlakes, in: &context, size: size)
        }
        if scene.condition == .fog {
            drawFog(palette: scene.palette, in: &context, size: size)
        }
    }

    private static func drawSky(_ palette: SkyPalette, in context: inout GraphicsContext, size: CGSize) {
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: color(palette.skyTop), location: 0),
                    .init(color: color(palette.skyUpper), location: 0.30),
                    .init(color: color(palette.skyGlow), location: 0.62),
                    .init(color: color(palette.skyBase), location: 0.92),
                ]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: size.height)
            )
        )
    }

    private static func drawHorizonGlow(
        _ glow: SkyScene.HorizonGlow,
        palette: SkyPalette,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        guard glow.opacity > 0.01 else { return }
        let center = CGPoint(x: glow.x * size.width, y: glow.y * size.height)
        let radius = glow.radius * size.width
        let tint = color(palette.horizonGlow)
        context.fill(
            Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: tint.opacity(glow.opacity), location: 0),
                    .init(color: tint.opacity(glow.opacity * 0.45), location: 0.45),
                    .init(color: tint.opacity(0), location: 1),
                ]),
                center: center,
                startRadius: 0,
                endRadius: radius
            )
        )
    }

    private static func drawStars(_ stars: [SkyScene.Star], in context: inout GraphicsContext, size: CGSize) {
        for star in stars where star.opacity > 0.01 {
            let rect = CGRect(
                x: star.x * size.width - star.radius,
                y: star.y * size.height - star.radius,
                width: star.radius * 2,
                height: star.radius * 2
            )
            context.fill(Path(ellipseIn: rect), with: .color(starColor.opacity(star.opacity)))
        }
    }

    private static func drawMeteor(_ meteor: SkyScene.Meteor, in context: inout GraphicsContext, size: CGSize) {
        guard meteor.opacity > 0.01 else { return }
        let head = CGPoint(x: meteor.headX * size.width, y: meteor.headY * size.height)
        let tail = CGPoint(x: meteor.tailX * size.width, y: meteor.tailY * size.height)
        var path = Path()
        path.move(to: head)
        path.addLine(to: tail)
        context.stroke(
            path,
            with: .linearGradient(
                Gradient(colors: [meteorColor.opacity(meteor.opacity), meteorColor.opacity(0)]),
                startPoint: head,
                endPoint: tail
            ),
            style: StrokeStyle(lineWidth: 1.6, lineCap: .round)
        )
    }

    private static func drawWisps(
        _ wisps: [SkyScene.Wisp],
        palette: SkyPalette,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let aspect = SkyWispSprite.size.height / SkyWispSprite.size.width
        for wisp in wisps {
            guard let symbol = context.resolveSymbol(id: SkySpriteID.wisp(wisp.variant)) else { continue }
            let width = wisp.width * size.width
            let height = width * aspect
            let rect = CGRect(
                x: wisp.x * size.width - width / 2,
                y: wisp.y * size.height - height / 2,
                width: width,
                height: height
            )
            var layer = context
            layer.opacity = wisp.opacity * palette.wispOpacity
            layer.draw(symbol, in: rect)
        }
    }

    private static func drawClouds(
        _ clouds: [SkyScene.Cloud],
        palette: SkyPalette,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let aspect = SkyCloudSprite.size.height / SkyCloudSprite.size.width
        for cloud in clouds {
            guard let symbol = context.resolveSymbol(id: SkySpriteID.cloud(cloud.variant)) else { continue }
            let width = cloud.width * size.width
            let height = width * aspect
            let rect = CGRect(
                x: cloud.x * size.width - width / 2,
                y: cloud.y * size.height - height / 2,
                width: width,
                height: height
            )
            var layer = context
            layer.opacity = cloud.opacity * palette.cloudOpacity
            layer.draw(symbol, in: rect)
        }
    }

    private static func drawRain(
        _ streaks: [SkyScene.RainStreak],
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let slant: CGFloat = 0.08
        for streak in streaks {
            let start = CGPoint(x: streak.x * size.width, y: streak.y * size.height)
            let length = streak.length * size.height
            let end = CGPoint(x: start.x - length * slant, y: start.y + length)

            var path = Path()
            path.move(to: start)
            path.addLine(to: end)
            context.stroke(
                path,
                with: .color(rainColor.opacity(streak.opacity * 0.45)),
                style: StrokeStyle(lineWidth: 1.2, lineCap: .round)
            )
        }
    }

    private static func drawSnow(
        _ flakes: [SkyScene.SnowFlake],
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        for flake in flakes {
            let rect = CGRect(
                x: flake.x * size.width - flake.radius,
                y: flake.y * size.height - flake.radius,
                width: flake.radius * 2,
                height: flake.radius * 2
            )
            context.fill(Path(ellipseIn: rect), with: .color(snowColor.opacity(flake.opacity * 0.70)))
        }
    }

    private static func drawFog(
        palette: SkyPalette,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let rect = CGRect(x: 0, y: size.height * 0.35, width: size.width, height: size.height * 0.65)
        let fogColor = color(palette.skyGlow)
        context.fill(
            Path(rect),
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: fogColor.opacity(0.0), location: 0.0),
                    .init(color: fogColor.opacity(0.35), location: 0.5),
                    .init(color: fogColor.opacity(0.60), location: 1.0)
                ]),
                startPoint: CGPoint(x: size.width / 2, y: size.height * 0.35),
                endPoint: CGPoint(x: size.width / 2, y: size.height)
            )
        )
    }

    public static func color(_ rgb: SkyRGB) -> Color {
        Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }
}

/// The symbol set a `Canvas` needs so `SkyRenderer` can stamp clouds.
public struct SkySpriteSymbols: View {
    public let palette: SkyPalette

    private static let cloudIDs = (0 ..< SkyScene.cloudVariantCount).map(SkySpriteID.cloud)
    private static let wispIDs = (0 ..< SkyScene.wispVariantCount).map(SkySpriteID.wisp)

    public init(palette: SkyPalette) {
        self.palette = palette
    }

    public var body: some View {
        ForEach(Self.cloudIDs, id: \.self) { id in
            if case let .cloud(variant) = id {
                SkyCloudSprite(
                    variant: variant,
                    bodyColor: SkyRenderer.color(palette.cloudBody),
                    shade: SkyRenderer.color(palette.cloudShade)
                )
                .tag(id)
            }
        }
        ForEach(Self.wispIDs, id: \.self) { id in
            if case let .wisp(variant) = id {
                SkyWispSprite(variant: variant, color: SkyRenderer.color(palette.wisp))
                    .tag(id)
            }
        }
    }
}
