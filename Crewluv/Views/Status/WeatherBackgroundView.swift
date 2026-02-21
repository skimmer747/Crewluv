//
//  WeatherBackgroundView.swift
//  CrewLuve
//
//  Animated weather particle backgrounds for the sun circle detail view.
//  All positions are deterministic pure functions of (elapsed, index) — no @State arrays.
//

import SwiftUI

// MARK: - Animation Type

enum WeatherAnimationType {
    case clearDay
    case clearNight
    case rain
    case snow
    case cloudy
    case thunderstorm
    case fogMist
    case wind

    static func from(weather: WeatherSnapshot) -> WeatherAnimationType {
        let desc = weather.conditionDescription.lowercased()

        // Priority order: thunderstorm → snow → rain → fog → wind → cloudy → clear
        if desc.contains("thunderstorm") { return .thunderstorm }
        if desc.contains("snow") || desc.contains("sleet") || desc.contains("flurries") || desc.contains("blizzard") { return .snow }
        if desc.contains("rain") || desc.contains("drizzle") || desc.contains("shower") { return .rain }
        if desc.contains("fog") || desc.contains("haze") || desc.contains("mist") { return .fogMist }
        if desc.contains("wind") || desc.contains("breezy") { return .wind }
        if desc.contains("cloudy") || desc.contains("overcast") { return .cloudy }

        // Fallback: symbol matching
        let sym = weather.conditionSymbol
        if sym.contains("bolt") { return .thunderstorm }
        if sym.contains("snow") { return .snow }
        if sym.contains("rain") || sym.contains("drizzle") { return .rain }
        if sym.contains("fog") || sym.contains("haze") { return .fogMist }
        if sym.contains("wind") { return .wind }
        if sym.contains("cloud") { return .cloudy }

        return weather.isDaylight ? .clearDay : .clearNight
    }
}

// MARK: - View

struct WeatherBackgroundView: View {
    let animationType: WeatherAnimationType
    let opacity: Double

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let elapsed = timeline.date.timeIntervalSinceReferenceDate
                switch animationType {
                case .clearDay:     drawClearDay(context: context, size: size, elapsed: elapsed)
                case .clearNight:   drawClearNight(context: context, size: size, elapsed: elapsed)
                case .rain:         drawRain(context: context, size: size, elapsed: elapsed)
                case .snow:         drawSnow(context: context, size: size, elapsed: elapsed)
                case .cloudy:       drawCloudy(context: context, size: size, elapsed: elapsed)
                case .thunderstorm: drawThunderstorm(context: context, size: size, elapsed: elapsed)
                case .fogMist:      drawFog(context: context, size: size, elapsed: elapsed)
                case .wind:         drawWind(context: context, size: size, elapsed: elapsed)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(opacity)
        .allowsHitTesting(false)
    }

    // MARK: - Seeded Hash

    private func hash(_ seed: Int, _ index: Int) -> Double {
        // Simple deterministic hash → value in [0, 1)
        var h = UInt64(bitPattern: Int64(seed &* 2654435761 &+ index &* 340573321))
        h ^= h >> 16
        h &*= 0x45d9f3b
        h ^= h >> 16
        return Double(h % 10000) / 10000.0
    }

    // MARK: - Clear Day (radial sun rays)

    private func drawClearDay(context: GraphicsContext, size: CGSize, elapsed: Double) {
        let center = CGPoint(x: size.width * 0.85, y: size.height * 0.12)
        let baseAngle = elapsed * 0.15 // slow rotation
        let rayCount = 12

        for i in 0..<rayCount {
            let angle = baseAngle + Double(i) * (.pi * 2.0 / Double(rayCount))
            let seed = hash(7, i)
            let minLen: Double = 60
            let maxLen: Double = 180
            let pulse = sin(elapsed * (0.4 + seed * 0.3) + seed * .pi * 2) * 0.5 + 0.5
            let length = minLen + (maxLen - minLen) * pulse

            let start = CGPoint(
                x: center.x + cos(angle) * 20,
                y: center.y + sin(angle) * 20
            )
            let end = CGPoint(
                x: center.x + cos(angle) * length,
                y: center.y + sin(angle) * length
            )

            var path = Path()
            path.move(to: start)
            path.addLine(to: end)

            let alpha = 0.12 + pulse * 0.15
            let color = i % 2 == 0
                ? Color.orange.opacity(alpha)
                : Color.yellow.opacity(alpha)
            context.stroke(path, with: .color(color), lineWidth: 3.5)
        }
    }

    // MARK: - Clear Night (twinkling stars)

    private func drawClearNight(context: GraphicsContext, size: CGSize, elapsed: Double) {
        let starCount = 40

        for i in 0..<starCount {
            let x = hash(1, i) * size.width
            let y = hash(2, i) * size.height
            let radius = 1.0 + hash(3, i) * 2.0
            let speed = 0.5 + hash(4, i) * 1.5
            let phase = hash(5, i) * .pi * 2

            let twinkle = sin(elapsed * speed + phase) * 0.5 + 0.5
            let alpha = 0.2 + twinkle * 0.6

            let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
            context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(alpha)))
        }
    }

    // MARK: - Rain

    private func drawRain(context: GraphicsContext, size: CGSize, elapsed: Double, dropCount: Int = 60) {
        let margin: Double = 40

        for i in 0..<dropCount {
            let baseX = hash(10, i) * (size.width + 60) - 30
            let speed = 280 + hash(11, i) * 200
            let length = 12 + hash(12, i) * 8
            let phase = hash(13, i) * (size.height + margin)

            let y = ((elapsed * speed + phase).truncatingRemainder(dividingBy: size.height + margin)) - margin / 2
            let slant: Double = 8
            let x = baseX + (y / size.height) * slant

            var path = Path()
            path.move(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: x + slant * (length / size.height), y: y + length))

            let alpha = 0.25 + hash(14, i) * 0.15
            let color = i % 3 == 0
                ? Color.cyan.opacity(alpha)
                : Color.blue.opacity(alpha)
            context.stroke(path, with: .color(color), lineWidth: 1.5)
        }
    }

    // MARK: - Snow

    private func drawSnow(context: GraphicsContext, size: CGSize, elapsed: Double) {
        let flakeCount = 35
        let margin: Double = 30

        for i in 0..<flakeCount {
            let baseX = hash(20, i) * size.width
            let speed = 30 + hash(21, i) * 40
            let radius = 2 + hash(22, i) * 3
            let driftFreq = 0.3 + hash(23, i) * 0.5
            let driftAmp = 15 + hash(24, i) * 25
            let phase = hash(25, i) * (size.height + margin)

            let y = ((elapsed * speed + phase).truncatingRemainder(dividingBy: size.height + margin)) - margin / 2
            let x = baseX + sin(elapsed * driftFreq + hash(26, i) * .pi * 2) * driftAmp

            let alpha = 0.4 + hash(27, i) * 0.3
            let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
            context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(alpha)))
        }
    }

    // MARK: - Cloudy

    private func drawCloudy(context: GraphicsContext, size: CGSize, elapsed: Double) {
        let cloudCount = 7
        let cloudColor = Color(red: 0.55, green: 0.6, blue: 0.7)

        for i in 0..<cloudCount {
            let baseY = hash(30, i) * size.height
            let speed = 8 + hash(31, i) * 15
            let w = 120 + hash(32, i) * 150
            let h = 50 + hash(33, i) * 50
            let phase = hash(34, i) * (size.width + w)
            let alpha = 0.25 + hash(35, i) * 0.2

            let x = ((elapsed * speed + phase).truncatingRemainder(dividingBy: size.width + w)) - w / 2

            context.drawLayer { layerCtx in
                layerCtx.addFilter(.blur(radius: 18))
                let rect = CGRect(x: x, y: baseY - h / 2, width: w, height: h)
                layerCtx.fill(Path(ellipseIn: rect), with: .color(cloudColor.opacity(alpha)))
            }
        }
    }

    // MARK: - Thunderstorm (rain + lightning)

    private func drawThunderstorm(context: GraphicsContext, size: CGSize, elapsed: Double) {
        // Rain layer
        drawRain(context: context, size: size, elapsed: elapsed, dropCount: 60)

        // Lightning flash every ~6 seconds
        let cycle = elapsed / 6.0
        let frac = cycle - floor(cycle)
        if frac < 0.017 {
            // Full-screen flash
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(.white.opacity(0.25))
            )

            // Bolt shape seeded from cycle integer
            let boltSeed = Int(floor(cycle))
            let startX = hash(50, boltSeed) * size.width * 0.6 + size.width * 0.2
            let segments = 4

            var path = Path()
            path.move(to: CGPoint(x: startX, y: 0))

            var currentX = startX
            var currentY: Double = 0
            let segHeight = size.height * 0.5 / Double(segments)

            for s in 0..<segments {
                let jag = (hash(51 + s, boltSeed) - 0.5) * 60
                currentX += jag
                currentY += segHeight
                path.addLine(to: CGPoint(x: currentX, y: currentY))
            }

            context.stroke(path, with: .color(.white.opacity(0.8)), lineWidth: 2)
        }
    }

    // MARK: - Fog / Mist

    private func drawFog(context: GraphicsContext, size: CGSize, elapsed: Double) {
        let bandCount = 4
        let fogColor = Color(red: 0.6, green: 0.63, blue: 0.68)

        for i in 0..<bandCount {
            let baseY = size.height * (0.2 + hash(40, i) * 0.6)
            let speed = 0.15 + hash(41, i) * 0.25
            let amplitude = 20 + hash(42, i) * 30
            let h: Double = 60 + hash(43, i) * 40
            let alpha = 0.15 + hash(44, i) * 0.15

            let y = baseY + sin(elapsed * speed + hash(45, i) * .pi * 2) * amplitude

            context.drawLayer { layerCtx in
                layerCtx.addFilter(.blur(radius: 30))
                let rect = CGRect(x: -20, y: y - h / 2, width: size.width + 40, height: h)
                layerCtx.fill(Path(ellipseIn: rect), with: .color(fogColor.opacity(alpha)))
            }
        }
    }

    // MARK: - Wind (horizontal streaks)

    private func drawWind(context: GraphicsContext, size: CGSize, elapsed: Double) {
        let streakCount = 25
        let margin: Double = 100

        for i in 0..<streakCount {
            let baseY = hash(60, i) * size.height
            let speed = 200 + hash(61, i) * 250
            let length = 40 + hash(62, i) * 60
            let phase = hash(63, i) * (size.width + margin + length)
            let alpha = 0.3 + hash(64, i) * 0.2

            let x = ((elapsed * speed + phase).truncatingRemainder(dividingBy: size.width + margin + length)) - length
            let yWobble = sin(elapsed * 0.5 + hash(65, i) * .pi * 2) * 5

            var path = Path()
            path.move(to: CGPoint(x: x, y: baseY + yWobble))
            path.addLine(to: CGPoint(x: x + length, y: baseY + yWobble))

            context.stroke(path, with: .color(Color(white: 0.55).opacity(alpha)), lineWidth: 1.5)
        }
    }
}
