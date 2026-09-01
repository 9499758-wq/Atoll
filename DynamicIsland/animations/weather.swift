import SwiftUI

/// 天气 Fluent 动画图标：替代系统 SF Symbol，覆盖 LockScreenWeatherSnapshot.symbolName 的全部取值。
///
/// symbolName 形如 "sun.max.fill" / "cloud.rain.fill" / "moon.stars.fill" / "cloud.moon.fill" 等，
/// 这里解析为天气种类后优先播放 Animated-Fluent-Emojis 拆出的 PNG 帧；缺资源才回退到简洁内置绘制。
public struct WeatherCuteIcon: View {
    public let symbolName: String
    public let size: CGFloat

    public init(symbolName: String, size: CGFloat = 26) {
        self.symbolName = symbolName
        self.size = size
    }

    private var kind: WeatherKind {
        WeatherKind.parse(symbolName)
    }

    public var body: some View {
        AtollDynamic3DWeatherIcon(condition: symbolName, size: size)
    }
}

enum WeatherKind {
    case sun
    case moon
    case cloud
    case cloudSun
    case cloudMoon
    case fog
    case drizzle
    case rain
    case heavyRain
    case sleet
    case snow
    case boltRain

    var isNight: Bool {
        switch self {
        case .moon, .cloudMoon: return true
        default: return false
        }
    }

    /// 判断 symbol 字符串是否为天气类（非天气的如 sparkles/terminal 返回 false）
    static func isWeatherSymbol(_ symbol: String) -> Bool {
        let s = symbol.lowercased()
        let keys = ["bolt", "snow", "sleet", "heavyrain", "drizzle", "rain",
                   "fog", "moon", "cloud", "sun"]
        return keys.contains { s.contains($0) }
    }

    static func parse(_ symbol: String) -> WeatherKind {
        if symbol.contains("bolt") { return .boltRain }
        if symbol.contains("snow") { return .snow }
        if symbol.contains("sleet") { return .sleet }
        if symbol.contains("heavyrain") { return .heavyRain }
        if symbol.contains("drizzle") { return .drizzle }
        if symbol.contains("rain") { return .rain }
        if symbol.contains("fog") { return .fog }
        if symbol.contains("moon") { return symbol.contains("cloud") ? .cloudMoon : .moon }
        if symbol.contains("cloud") { return symbol.contains("sun") ? .cloudSun : .cloud }
        if symbol.contains("sun") { return .sun }
        return .cloud
    }

    @ViewBuilder
    func view(phase t: Double, isNight: Bool) -> some View {
        AtollWeatherGlyph(kind: self, phase: t)
    }
}

// MARK: - 基础部件

private struct AtollWeatherGlyph: View {
    let kind: WeatherKind
    let phase: Double

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let palette = kind.atollPalette
            let pulse = 1 + 0.035 * CGFloat(0.5 + 0.5 * sin(phase * kind.atollTempo))

            ZStack {
                if kind.atollShowsDrops {
                    ForEach(0..<3, id: \.self) { i in
                        let fall = (phase * kind.atollDropSpeed + Double(i) * 0.31).truncatingRemainder(dividingBy: 1)
                        Capsule()
                            .fill(palette.secondary.opacity(0.85))
                            .frame(width: max(1.2, side * 0.07), height: max(3, side * 0.20))
                            .offset(x: CGFloat(i - 1) * side * 0.18, y: side * (0.16 + 0.30 * CGFloat(fall)))
                            .opacity(0.75 * (1 - fall))
                    }
                }

                if kind.atollShowsSparkles {
                    ForEach(0..<3, id: \.self) { i in
                        let angle = phase * 0.9 + Double(i) * 2.094
                        Circle()
                            .fill(Color.white.opacity(0.86))
                            .frame(width: max(1.5, side * 0.08), height: max(1.5, side * 0.08))
                            .offset(x: CGFloat(cos(angle)) * side * 0.34, y: CGFloat(sin(angle)) * side * 0.30)
                            .opacity(0.28 + 0.34 * sin(phase * 2.8 + Double(i)).magnitude)
                    }
                }

                Image.cuteSymbol(kind.atollSymbol)
                    .font(.system(size: side * kind.atollSymbolScale, weight: .semibold, design: .rounded))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(
                        LinearGradient(colors: [Color.white, palette.secondary.opacity(0.95)], startPoint: .top, endPoint: .bottom)
                    )
                    .shadow(color: Color.black.opacity(0.38), radius: side * 0.05, y: side * 0.015)
                    .shadow(color: palette.primary.opacity(0.28), radius: side * 0.07)
                    .offset(y: kind.atollIconYOffset * side)
                    .rotationEffect(.degrees(kind.atollRotation(phase: phase)))
                    .scaleEffect(pulse)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

private struct WeatherFrameGlyph: View {
    let kind: WeatherKind
    let animationKind: ReactionAnimationKind

    @State private var frameIndex = 0
    @State private var frameCount = 0

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let palette = kind.atollPalette
            let resolvedCount = max(frameCount, FluentFrameStore.frameCount(of: animationKind))
            let currentFrame = resolvedCount > 0 ? frameIndex % resolvedCount : 0

            ZStack {
                if let image = FluentFrameStore.frame(animationKind, index: currentFrame, displaySize: max(side, 18)) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: side * kind.atollFrameScale, height: side * kind.atollFrameScale)
                        .offset(y: side * kind.atollFrameYOffset)
                        .shadow(color: Color.black.opacity(0.35), radius: side * 0.05, y: side * 0.015)
                        .shadow(color: palette.primary.opacity(0.24), radius: side * 0.07)
                } else {
                    kind.view(phase: Date().timeIntervalSinceReferenceDate, isNight: kind.isNight)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .task(id: animationKind.rawValue) {
            await runFrameLoop()
        }
    }

    @MainActor
    private func runFrameLoop() async {
        frameIndex = 0
        let count = FluentFrameStore.frameCount(of: animationKind)
        frameCount = count
        FluentFrameStore.warmup(kinds: [animationKind], displaySize: 24)
        guard count > 1 else { return }

        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: kind.atollFrameDelayNanoseconds)
            if Task.isCancelled { break }
            frameIndex = (frameIndex + kind.atollFrameStep) % count
        }
    }
}

private extension WeatherKind {
    var atollFrameAnimation: ReactionAnimationKind? {
        switch self {
        case .sun:
            return .brightness
        case .moon:
            return .focus
        case .cloud:
            return .cloud
        case .cloudSun:
            return .suncloud
        case .cloudMoon:
            return .mooncloud
        case .fog:
            return .fog
        case .drizzle, .rain, .heavyRain:
            return .rain
        case .sleet, .snow:
            return .snowcloud
        case .boltRain:
            return .storm
        }
    }

    var atollTimelineInterval: TimeInterval {
        switch self {
        case .sun, .moon, .cloudSun, .cloudMoon:
            return 1.0 / 12.0
        case .cloud, .fog:
            return 1.0 / 8.0
        default:
            return 1.0 / 10.0
        }
    }

    var atollFrameScale: CGFloat {
        switch self {
        case .heavyRain, .boltRain:
            return 1.12
        case .drizzle:
            return 1.04
        default:
            return 1.08
        }
    }

    var atollFrameYOffset: CGFloat {
        switch self {
        case .drizzle, .rain, .heavyRain, .sleet, .snow, .boltRain:
            return 0.03
        default:
            return 0
        }
    }

    var atollFrameDelayNanoseconds: UInt64 {
        switch self {
        case .heavyRain, .boltRain:
            return 80_000_000
        case .drizzle:
            return 120_000_000
        case .snow:
            return 110_000_000
        default:
            return 90_000_000
        }
    }

    var atollFrameStep: Int {
        switch self {
        case .heavyRain, .boltRain:
            return 3
        case .drizzle:
            return 1
        default:
            return 2
        }
    }

    var atollSymbol: String {
        switch self {
        case .sun: return "sun.max.fill"
        case .moon: return "moon.stars.fill"
        case .cloud: return "cloud.fill"
        case .cloudSun: return "cloud.sun.fill"
        case .cloudMoon: return "cloud.moon.fill"
        case .fog: return "cloud.fog.fill"
        case .drizzle, .rain: return "cloud.rain.fill"
        case .heavyRain: return "cloud.heavyrain.fill"
        case .sleet: return "cloud.sleet.fill"
        case .snow: return "cloud.snow.fill"
        case .boltRain: return "cloud.bolt.rain.fill"
        }
    }

    var atollPalette: (primary: Color, secondary: Color) {
        switch self {
        case .sun, .cloudSun:
            return (Color(red: 1.00, green: 0.77, blue: 0.20), Color(red: 1.00, green: 0.45, blue: 0.18))
        case .moon, .cloudMoon:
            return (Color(red: 0.46, green: 0.48, blue: 1.00), Color(red: 0.74, green: 0.88, blue: 1.00))
        case .cloud, .fog:
            return (Color(red: 0.56, green: 0.68, blue: 0.82), Color(red: 0.86, green: 0.92, blue: 1.00))
        case .drizzle, .rain, .heavyRain, .sleet:
            return (Color(red: 0.22, green: 0.67, blue: 1.00), Color(red: 0.48, green: 0.94, blue: 1.00))
        case .snow:
            return (Color(red: 0.62, green: 0.82, blue: 1.00), Color.white)
        case .boltRain:
            return (Color(red: 0.28, green: 0.66, blue: 1.00), Color(red: 1.00, green: 0.84, blue: 0.18))
        }
    }

    var atollSymbolScale: CGFloat {
        switch self {
        case .rain, .heavyRain, .sleet, .boltRain: return 0.70
        case .cloudSun, .cloudMoon: return 0.74
        default: return 0.68
        }
    }

    var atollIconYOffset: CGFloat {
        switch self {
        case .drizzle, .rain, .heavyRain, .sleet, .snow, .boltRain:
            return -0.04
        default:
            return 0
        }
    }

    var atollTempo: Double {
        switch self {
        case .sun, .moon: return 2.4
        case .rain, .heavyRain, .boltRain: return 4.2
        default: return 2.9
        }
    }

    var atollShowsDrops: Bool {
        switch self {
        case .drizzle, .rain, .heavyRain, .sleet, .snow, .boltRain:
            return true
        default:
            return false
        }
    }

    var atollShowsSparkles: Bool {
        switch self {
        case .sun, .moon, .snow, .boltRain:
            return true
        default:
            return false
        }
    }

    var atollDropSpeed: Double {
        switch self {
        case .heavyRain: return 1.8
        case .drizzle: return 0.9
        case .snow: return 0.7
        default: return 1.25
        }
    }

    func atollRotation(phase t: Double) -> Double {
        switch self {
        case .sun:
            return sin(t * 0.7) * 2.5
        case .boltRain:
            return sin(t * 8.0) * 2.0
        default:
            return 0
        }
    }
}

/// 太阳：圆脸 + 旋转光芒 + 脉动
private struct SunView: View {
    let t: Double
    var body: some View {
        let pulse = 1 + 0.05 * sin(t * 3)
        ZStack {
            ForEach(0 ..< 8) { i in
                let a = t * 0.6 + Double(i) * (.pi / 4)
                Capsule().fill(Color.orange)
                    .frame(width: 3, height: 7)
                    .offset(x: CGFloat(cos(a) * 15), y: CGFloat(sin(a) * 15))
            }
            Circle().fill(
                RadialGradient(colors: [.yellow, .orange], center: .center, startRadius: 2, endRadius: 12)
            )
            .frame(width: 20, height: 20)
            .scaleEffect(pulse)
        }
    }
}

/// 月亮：月牙 + 闪烁星点
private struct MoonView: View {
    let t: Double
    var body: some View {
        ZStack {
            Image.cuteSymbol("moon.fill")
                .font(.system(size: 26))
                .foregroundStyle(Color(red: 0.85, green: 0.88, blue: 1.0))
            ForEach(0 ..< 3) { i in
                let base = Double(i) * 1.7
                let op = 0.3 + 0.7 * (0.5 + 0.5 * sin(t * 3 + base))
                Circle().fill(Color.white)
                    .frame(width: 2.5, height: 2.5)
                    .offset(x: CGFloat(cos(base) * 13), y: CGFloat(sin(base * 1.3) * 13))
                    .opacity(op)
            }
        }
    }
}

/// 云朵（可着不同色）
private struct CloudView: View {
    let t: Double
    var tint: Color
    var body: some View {
        let drift = sin(t * 0.8) * 2
        ZStack {
            Capsule().fill(tint)
                .frame(width: 26, height: 11)
                .offset(y: 6 + drift)
            Circle().fill(tint).frame(width: 15, height: 15).offset(x: -8, y: 1 + drift)
            Circle().fill(tint).frame(width: 18, height: 18).offset(x: 1, y: -2 + drift)
            Circle().fill(tint).frame(width: 12, height: 12).offset(x: 9, y: 2 + drift)
        }
    }
}

private struct CloudSunView: View {
    let t: Double
    var body: some View {
        let pulse = 1 + 0.05 * sin(t * 3)
        ZStack {
            ForEach(0 ..< 7) { i in
                let a = t * 0.6 + Double(i) * (.pi / 3.5)
                Capsule().fill(Color.orange)
                    .frame(width: 2.5, height: 6)
                    .offset(x: CGFloat(cos(a) * 11), y: CGFloat(sin(a) * 11) - 6)
            }
            Circle().fill(RadialGradient(colors: [.yellow, .orange], center: .center, startRadius: 1, endRadius: 8))
                .frame(width: 13, height: 13)
                .offset(x: -2, y: -6)
                .scaleEffect(pulse)
            CloudView(t: t, tint: .gray).offset(y: 4)
        }
    }
}

private struct CloudMoonView: View {
    let t: Double
    var body: some View {
        ZStack {
            Image.cuteSymbol("moon.fill")
                .font(.system(size: 13))
                .foregroundStyle(Color(red: 0.85, green: 0.88, blue: 1.0))
                .offset(x: -2, y: -6)
            CloudView(t: t, tint: Color(red: 0.55, green: 0.58, blue: 0.7)).offset(y: 4)
        }
    }
}

private struct FogView: View {
    let t: Double
    var body: some View {
        let drift = sin(t * 0.7) * 2
        VStack(spacing: 3) {
            ForEach(0 ..< 3) { i in
                Capsule().fill(Color(red: 0.7, green: 0.72, blue: 0.78))
                    .frame(width: 26 - CGFloat(i) * 3, height: 4)
                    .offset(x: CGFloat(drift) * (i % 2 == 0 ? 1 : -1))
            }
        }
    }
}

private struct RainView: View {
    let t: Double
    let count: Int
    let speed: Double
    var tint: Color
    var body: some View {
        ZStack {
            CloudView(t: t, tint: .gray)
            ForEach(0 ..< count, id: \.self) { i in
                let x = Double(i) / Double(count) * 24 - 12
                let fall = (t * speed * 14 + Double(i) * 6).truncatingRemainder(dividingBy: 16)
                Capsule().fill(tint)
                    .frame(width: 2, height: 7)
                    .offset(x: CGFloat(x), y: CGFloat(10 + fall))
                    .opacity(0.85)
            }
        }
    }
}

private struct SnowView: View {
    let t: Double
    let count: Int
    var body: some View {
        ZStack {
            CloudView(t: t, tint: .gray)
            ForEach(0 ..< count, id: \.self) { i in
                let phase = Double(i) * 1.3
                let x = Double(i) / Double(count) * 22 - 11 + sin(t + phase) * 3
                let fall = (t * 12 + Double(i) * 7).truncatingRemainder(dividingBy: 18)
                Circle().fill(Color.white)
                    .frame(width: 3, height: 3)
                    .offset(x: CGFloat(x), y: CGFloat(10 + fall))
            }
        }
    }
}

private struct BoltRainView: View {
    let t: Double
    var body: some View {
        let flash = t.truncatingRemainder(dividingBy: 1.6) < 0.25
        return ZStack {
            CloudView(t: t, tint: .gray)
            ForEach(0 ..< 5, id: \.self) { i in
                let x = Double(i) / 5 * 22 - 11
                let fall = (t * 1.4 * 14 + Double(i) * 5).truncatingRemainder(dividingBy: 16)
                Capsule().fill(.blue).frame(width: 2, height: 7)
                    .offset(x: CGFloat(x), y: CGFloat(10 + fall)).opacity(0.85)
            }
            Path { p in
                p.move(to: CGPoint(x: 2, y: 6))
                p.addLine(to: CGPoint(x: -3, y: 16))
                p.addLine(to: CGPoint(x: 1, y: 16))
                p.addLine(to: CGPoint(x: -2, y: 26))
            }
            .stroke(Color.yellow, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            .opacity(flash ? 1 : 0.25)
        }
    }
}
