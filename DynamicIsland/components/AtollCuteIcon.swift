import AppKit
import SwiftUI

enum AtollMotion {
    static let iconFloat = Animation.interpolatingSpring(stiffness: 150, damping: 17)
    static let agentFloat = Animation.interpolatingSpring(stiffness: 135, damping: 16)
    static let bubbleFloat = Animation.easeOut(duration: 0.46)
    static let mascotBreathe = Animation.interpolatingSpring(stiffness: 140, damping: 18)
    static let noticeDrift = Animation.easeOut(duration: 0.42)
    static let bridgePulse = Animation.easeInOut(duration: 0.46)
    static let bridgeIdlePulse = Animation.easeInOut(duration: 0.62)
    static let activityBar = Animation.interpolatingSpring(stiffness: 170, damping: 18)
    static let activityBarsPulse = Animation.easeInOut(duration: 0.40)
    static let press = Animation.interpolatingSpring(stiffness: 260, damping: 22)

    @MainActor
    static func runPulseLoop(
        isEnabled: Bool,
        initialDelay: UInt64 = 0,
        interval: UInt64 = 5_800_000_000,
        hold: UInt64 = 320_000_000,
        rise: Animation = Animation.easeOut(duration: 0.24),
        settle: Animation = Animation.easeInOut(duration: 0.30),
        setActive: @escaping (Bool) -> Void
    ) async {
        guard isEnabled else {
            setActive(false)
            return
        }

        if initialDelay > 0 {
            try? await Task.sleep(nanoseconds: initialDelay)
        }

        while !Task.isCancelled {
            withAnimation(rise) {
                setActive(true)
            }
            try? await Task.sleep(nanoseconds: hold)
            withAnimation(settle) {
                setActive(false)
            }
            try? await Task.sleep(nanoseconds: interval)
        }
    }
}

enum AtollCuteIconAssets {
    private static let cache = NSCache<NSString, NSImage>()

    static func image(named name: String) -> NSImage? {
        let key = NSString(string: name)
        if let cached = cache.object(forKey: key) {
            return cached
        }
        // 1. 优先从 Assets.xcassets 加载
        if let asset = NSImage(named: name) {
            cache.setObject(asset, forKey: key)
            return asset
        }
        // 2. 从 Bundle Resources / FluentAnim 加载
        let bundledURL = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "FluentAnim")
            ?? Bundle.main.url(forResource: name, withExtension: "png")
        guard let url = bundledURL,
              let image = NSImage(contentsOf: url) else {
            return nil
        }
        cache.setObject(image, forKey: key)
        return image
    }

    static func assetName(for symbolName: String) -> String? {
        let s = symbolName.lowercased()
        if s.isEmpty { return "sparkles" }

        // —— 天气系列：Fluent 3D / Cute 图标 ——
        if s.contains("sun.max") || s.contains("sunrise") || s.contains("clear") || s.contains("sunny") { return "sun" }
        if s.contains("moon") { return "moon" }
        if s.contains("cloud.bolt") || s.contains("thunder") || s.contains("storm") { return "storm" }
        if s.contains("cloud.rain") || s.contains("cloud.heavyrain") || s.contains("raindrop") || s.contains("drizzle") || s.contains("rain") { return "rain" }
        if s.contains("cloud.snow") || s.contains("snow") || s.contains("sleet") || s.contains("snowflake") { return "snowcloud" }
        if s.contains("fog") || s.contains("mist") || s.contains("haze") { return "fog" }
        if s.contains("cloud.sun") || s.contains("partly") { return "suncloud" }
        if s.contains("cloud.moon") { return "mooncloud" }
        if s.contains("cloud") { return "cloud" }
        if s.contains("wind") || s.contains("breeze") { return "wind" }
        if s.contains("tornado") { return "tornado" }

        // —— 生活与健康系列 ——
        if s.contains("cup") || s.contains("coffee") || s.contains("tea") { return "coffee" }

        // —— 硬件与电源系列 ——
        if s.contains("bolt") || s.contains("charging") { return "bolt" }
        if s.contains("plug") { return "plug" }

        // —— 计时与效率系列 ——
        if s.contains("stopwatch") { return "stopwatch" }
        if s.contains("alarm") { return "alarm" }
        if s.contains("hourglass") || s.contains("clock") { return "hourglass" }

        // —— Agent 与 AI 场景 ——
        if s.contains("terminal") || s.contains("curly") || s.contains("wand") || s.contains("hammer") || s.contains("q.circle") || s.contains("robot") { return "robot" }
        if s.contains("sparkles") || s.contains("agent") || s.contains("ai") { return "sparkles" }
        if s.contains("starstruck") { return "starstruck" }
        if s.contains("glowstar") { return "glowstar" }
        if s.contains("comet") { return "comet" }

        return nil
    }
}

struct AtollCuteIcon: View {
    let symbolName: String
    var size: CGFloat = 18
    var accent: Color = .white.opacity(0.9)
    var secondary: Color = Color(red: 0.45, green: 0.9, blue: 1.0)
    var showsPlate: Bool = false
    var animated: Bool = false
    var weight: Font.Weight = .semibold
    var assetScale: CGFloat = 0.95
    @State private var floating = false

    var body: some View {
        render(isLifted: animated && floating)
            .onAppear {
                if animated {
                    floating = true
                }
            }
    }

    @ViewBuilder
    private func render(isLifted: Bool) -> some View {
        let s = symbolName.lowercased()
        let isWeather = ["sun", "moon", "cloud", "rain", "storm", "snow", "fog", "sleet", "drizzle", "thunder"].contains(where: { s.contains($0) })

        if isWeather {
            AtollDynamic3DWeatherIcon(
                condition: symbolName,
                size: size,
                accent: accent,
                secondary: secondary
            )
        } else if s.contains("walk") || s.contains("stand") || s.contains("move") || s.contains("figure") || s.contains("break") || s.contains("stretch") {
            StandBreak3DMascot(size: size)
        } else if s.contains("water") || s.contains("drop") || s.contains("drink") {
            WaterDrop3DMascot(size: size)
        } else if s.contains("tomato") || s.contains("pomodoro") {
            PomodoroTomato3DMascot(size: size)
        } else {
            let assetName = AtollCuteIconAssets.assetName(for: symbolName)
            let bounce: CGFloat = animated ? (isLifted ? 1.05 : 0.98) : 1.0
            let bob: CGFloat = animated ? (isLifted ? -size * 0.03 : size * 0.02) : 0

            ZStack {
                if let assetName, let image = AtollCuteIconAssets.image(named: assetName) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: size * assetScale, height: size * assetScale)
                        .scaleEffect(bounce)
                        .offset(y: bob)
                        .shadow(color: Color.black.opacity(0.35), radius: max(1.2, size * 0.08), y: 0.8)
                        .shadow(color: accent.opacity(0.20), radius: max(1, size * 0.08))
                        .animation(
                            animated ? .easeInOut(duration: 2.2).repeatForever(autoreverses: true) : .default,
                            value: floating
                        )
                } else {
                    Image(systemName: symbolName.isEmpty ? "sparkles" : symbolName)
                        .font(.system(size: size * 0.74, weight: weight, design: .rounded))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.white.opacity(0.98), secondary.opacity(0.96), accent.opacity(0.86)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(bounce)
                        .offset(y: bob)
                        .shadow(color: Color.black.opacity(0.40), radius: max(1, size * 0.06), y: 0.6)
                        .shadow(color: secondary.opacity(0.22), radius: max(1, size * 0.08))
                        .animation(
                            animated ? .easeInOut(duration: 2.2).repeatForever(autoreverses: true) : .default,
                            value: floating
                        )
                }
            }
            .frame(width: size, height: size)
        }
    }
}
