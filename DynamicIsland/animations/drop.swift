import SwiftUI
import AppKit
import Foundation

// MARK: - Central animation library for Atoll (macOS Dynamic Island)

/// 原 `drop.swift` 只是空壳；现在升级为 Atoll 的中央动画库：
/// 1. 统一的动画预设（展开/收起、sneak peek、live activity、待机呼吸、反应弹出等）
/// 2. 系统事件"工作反应"的帧序列播放器，终于用上一直闲置的
///    `FluentAnim/Frames/*` 与 `MochiFrames/*` PNG 序列资源
public class DynamicIslandAnimations {

    /// 向后兼容：其它地方曾引用过的单个动画
    public var animation: Animation = .interactiveSpring(dampingFraction: 0.7, blendDuration: 0.4)

    public static let shared = DynamicIslandAnimations()

    public enum Preset: String, CaseIterable {
        case dropIn
        case dropOut
        case notchOpen
        case notchClose
        case sneakPeekIn
        case sneakPeekOut
        case liveActivityAppear
        case liveActivityDisappear
        case idleBreathe
        case reactionPop
        case tabSwitch
        case blurSwap
        case hapticTap
    }

    public static let presets: [Preset: Animation] = [
        .dropIn: .interactiveSpring(dampingFraction: 0.7, blendDuration: 0.35),
        .dropOut: .interactiveSpring(dampingFraction: 0.85, blendDuration: 0.35),
        .notchOpen: .spring(response: 0.42, dampingFraction: 0.72, blendDuration: 0.3),
        .notchClose: .spring(response: 0.38, dampingFraction: 0.82, blendDuration: 0.3),
        .sneakPeekIn: .spring(response: 0.34, dampingFraction: 0.78, blendDuration: 0.25),
        .sneakPeekOut: .spring(response: 0.3, dampingFraction: 0.88, blendDuration: 0.25),
        .liveActivityAppear: .spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0.3),
        .liveActivityDisappear: .spring(response: 0.4, dampingFraction: 0.84, blendDuration: 0.3),
        .idleBreathe: .easeInOut(duration: 3.2),
        .reactionPop: .spring(response: 0.28, dampingFraction: 0.6, blendDuration: 0.2),
        .tabSwitch: .interactiveSpring(dampingFraction: 0.9, blendDuration: 0.2),
        .blurSwap: .easeInOut(duration: 0.25),
        .hapticTap: .interactiveSpring(dampingFraction: 1.1, blendDuration: 0.12)
    ]

    public func preset(_ p: Preset) -> Animation {
        Self.presets[p] ?? animation
    }

    public static func transition(_ p: Preset) -> AnyTransition {
        switch p {
        case .sneakPeekIn:
            return .asymmetric(
                insertion: .scale(scale: 0.6).combined(with: .opacity).combined(with: .offset(y: -8)),
                removal: .scale(scale: 0.8).combined(with: .opacity)
            )
        case .liveActivityAppear:
            return .asymmetric(insertion: .scale(scale: 0.9).combined(with: .opacity), removal: .opacity)
        case .reactionPop:
            return .asymmetric(insertion: .scale(scale: 0.4).combined(with: .opacity), removal: .scale(scale: 0.9).combined(with: .opacity))
        default:
            return .opacity.combined(with: .scale)
        }
    }
}

// MARK: - 工作反应：系统事件对应的动画类型

/// 当系统事件发生（Siri 唤醒、复制、充电、计时结束、闹钟、下载等）时，
/// Notch 做出的"反应"动画。优先播放 bundled 的 FluentAnim/Mochi 帧序列，
/// 找不到资源时回退到 SF Symbol。
public enum ReactionAnimationKind: String, CaseIterable, Identifiable {
    case siri
    case clipboard
    case battery
    case charging
    case timer
    case alarm
    case cloud
    case coffee
    case water
    case move
    case bolt
    case bell
    case chart
    case mochi
    case brightness
    case volume
    case music
    case mic
    case download
    case focus
    case bluetooth
    case privacy
    case lock
    case app
    case capslock
    case agent
    case rain
    case storm
    case snowflake
    case suncloud
    case mooncloud
    case fog
    case snowcloud

    public var id: String { rawValue }

    /// FluentAnim 帧序列的基名（PNG 在 app bundle 内；nil = 无资源走手绘回退）
    var frameBaseName: String? {
        switch self {
        case .clipboard: return "envelope"       // 静帧
        case .battery: return "battery"          // 静帧
        case .charging, .bolt: return "bolt"     // 72 帧动画
        case .alarm: return "alarm"              // 37 帧
        case .timer: return "stopwatch"          // 72 帧
        case .cloud: return "cloud"              // 72 帧
        case .coffee, .water: return "coffee"    // 72 帧
        case .move: return "notice-move"         // 运动帧
        case .bell: return "bell"                // 静帧
        case .chart: return "chart"              // 静帧
        case .mochi: return "partying"           // 73 帧
        case .siri: return "glowstar"            // 72 帧
        case .brightness: return "sun"           // 72 帧
        case .volume: return "megaphone"         // 静帧
        case .music: return "party"              // 61 帧
        case .download: return "comet"           // 73 帧
        case .focus: return "moon"               // 静帧
        case .app: return "laptop"               // 静帧
        case .agent: return "robot"              // 52 帧
        case .rain: return "rain"                // 72 帧天气雨滴
        case .storm: return "storm"              // 72 帧雷雨
        case .snowflake: return "snowflake"      // 72 帧雪花/云雪兼容旧名
        case .suncloud: return "suncloud"        // 72 帧多云
        case .mooncloud: return "mooncloud"      // 72 帧夜间多云（官方月亮+云合成）
        case .fog: return "fog"                  // 72 帧雾
        case .snowcloud: return "snowcloud"      // 72 帧云雪
        default: return nil                       // mic/bluetooth/privacy/lock/capslock 手绘
        }
    }

    var fps: Double {
        switch self {
        case .rain, .storm, .snowflake, .suncloud, .mooncloud, .fog, .snowcloud:
            return 10
        default:
            return 30
        }
    }

    var fallbackSymbol: String {
        switch self {
        case .siri: return "waveform"
        case .clipboard: return "doc.on.clipboard"
        case .battery: return "battery.100"
        case .charging, .bolt: return "bolt.fill"
        case .timer, .alarm: return "alarm"
        case .cloud: return "icloud"
        case .coffee: return "cup.and.saucer.fill"
        case .water: return "drop.fill"
        case .move: return "figure.walk"
        case .bell: return "bell.fill"
        case .chart: return "chart.bar.fill"
        case .mochi: return "star.fill"
        case .rain: return "cloud.rain.fill"
        case .storm: return "cloud.bolt.rain.fill"
        case .snowflake, .snowcloud: return "cloud.snow.fill"
        case .suncloud: return "cloud.sun.fill"
        case .mooncloud: return "cloud.moon.fill"
        case .fog: return "cloud.fog.fill"
        default: return "sparkles"
        }
    }

    var tint: Color {
        switch self {
        case .siri: return .purple
        case .clipboard: return .blue
        case .battery, .charging, .bolt: return .green
        case .timer, .alarm, .bell: return .orange
        case .cloud: return .cyan
        case .coffee: return .brown
        case .water: return .cyan
        case .move: return .green
        case .chart: return .pink
        case .mochi: return .yellow
        case .rain, .storm, .snowflake, .suncloud, .mooncloud, .fog, .snowcloud: return .cyan
        default: return .accentColor
        }
    }

    /// 解析 bundled PNG 帧 URL，兼容零填充(%03d)与纯数字(%d)命名
    func resolveFrameURLs() -> [URL] {
        guard let base = frameBaseName else { return [] }
        var urls: [URL] = []
        var i = 0
        while true {
            let padded = "\(base)_f\(String(format: "%03d", i))"
            if let u = Bundle.main.url(forResource: padded, withExtension: "png") {
                urls.append(u); i += 1
            } else {
                break
            }
        }
        return urls
    }

    /// 静帧资源（无动画集时用单张 Fluent 图代替 SF Symbol 回退）
    var staticFrameName: String? { frameBaseName.map { "\($0)" } }
}

// MARK: - 帧解码缓存（治 30fps 每帧打磁盘的硬伤）

/// NSCache 承载下采样解码位图：首次播放某集才读盘，之后全内存命中。
/// ponytail: 缓存上限由 NSCache 总成本约束（约 48MB 位图），LRU 自动逐出。
enum FluentFrameStore {
    static let cache: NSCache<NSString, NSImage> = {
        let c = NSCache<NSString, NSImage>()
        c.totalCostLimit = 48 * 1024 * 1024
        return c
    }()

    /// 取第 i 帧；磁盘未命中返回 nil。displaySize 用于下采样，省内存。
    static func frame(_ kind: ReactionAnimationKind, index i: Int, displaySize: CGFloat) -> NSImage? {
        guard let base = kind.frameBaseName else { return nil }
        let key = "\(base)_\(Int(displaySize))_\(i)" as NSString
        if let hit = cache.object(forKey: key) { return hit }
        let padded = "\(base)_f\(String(format: "%03d", i))"
        guard let url = Bundle.main.url(forResource: padded, withExtension: "png"),
              let src = NSImage(contentsOf: url) else { return nil }
        let target = displaySize * 2  // @2x Retina
        let img = downsample(src, to: target)
        cache.setObject(img, forKey: key, cost: bitmapBytes(img))
        return img
    }

    private static func downsample(_ img: NSImage, to side: CGFloat) -> NSImage {
        let sz = img.size
        guard max(sz.width, sz.height) > side + 1 else { return img }
        let scale = side / max(sz.width, sz.height)
        let newSz = NSSize(width: sz.width * scale, height: sz.height * scale)
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(newSz.width), pixelsHigh: Int(newSz.height),
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
        guard let ctx = NSGraphicsContext(bitmapImageRep: rep!) else { return img }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ctx
        img.draw(in: NSRect(origin: .zero, size: newSz))
        NSGraphicsContext.restoreGraphicsState()
        let out = NSImage(size: newSz)
        out.addRepresentation(rep!)
        return out
    }

    private static func bitmapBytes(_ img: NSImage) -> Int {
        let s = img.size
        return Int(s.width * s.height * 4)
    }

    /// 某类动画的帧数（0 = 无资源）。探测结果按基名缓存，避免每次扫 bundle。
    private static var countCache: [String: Int] = [:]
    private static let lock = NSLock()

    static func frameCount(of kind: ReactionAnimationKind) -> Int {
        guard let base = kind.frameBaseName else { return 0 }
        lock.lock(); defer { lock.unlock() }
        if let c = countCache[base] { return c }
        var i = 0
        while Bundle.main.url(forResource: "\(base)_f\(String(format: "%03d", i))", withExtension: "png") != nil { i += 1 }
        countCache[base] = i
        return i
    }

    /// 启动预热：把最常用的几组按目标尺寸提前解码进缓存
    static func warmup(kinds: [ReactionAnimationKind], displaySize: CGFloat) {
        for k in kinds where k.frameBaseName != nil {
            DispatchQueue.global(qos: .utility).async {
                var i = 0
                while FluentFrameStore.frame(k, index: i, displaySize: displaySize) != nil { i += 1 }
            }
        }
    }
}

// MARK: - 帧序列播放器（Fluent 帧全内存命中；无资源回退 SF Symbol）

extension FrameSequencePlayer {
    /// 该基名是否有帧资源（f000 存在即认为有）
    static func hasFrames(_ base: String) -> Bool {
        Bundle.main.url(forResource: "\(base)_f000", withExtension: "png") != nil
    }
}

/// 把一组 PNG 帧按时序播放；无资源时回退到 SF Symbol。
public struct FrameSequencePlayer: View {
    let kind: ReactionAnimationKind
    var loop: Bool
    var onFinished: (() -> Void)?
    var displaySize: CGFloat

    @State private var currentFrame = 0
    @State private var count = 0

    private var fps: Double { max(kind.fps, 1) }

    public init(kind: ReactionAnimationKind, loop: Bool = false, displaySize: CGFloat = 56, onFinished: (() -> Void)? = nil) {
        self.kind = kind
        self.loop = loop
        self.displaySize = displaySize
        self.onFinished = onFinished
    }

    public var body: some View {
        frameView()
            .task(id: kind.rawValue) {
                count = FluentFrameStore.frameCount(of: kind)
                FluentFrameStore.warmup(kinds: [kind], displaySize: displaySize)
                guard count > 1 else { return }
                currentFrame = 0
                let intervalNano = UInt64(1_000_000_000.0 / fps)
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: intervalNano)
                    if Task.isCancelled { break }
                    if currentFrame + 1 < count {
                        currentFrame += 1
                    } else if loop {
                        currentFrame = 0
                    } else {
                        onFinished?()
                        break
                    }
                }
            }
    }

    @ViewBuilder
    private func frameView() -> some View {
        if count == 0 {
            Image.cuteSymbol(kind.fallbackSymbol)
                .resizable()
                .scaledToFit()
                .foregroundStyle(kind.tint)
        } else if let img = FluentFrameStore.frame(kind, index: currentFrame, displaySize: displaySize) {
            Image(nsImage: img)
                .resizable()
                .scaledToFit()
        } else {
            Image.cuteSymbol(kind.fallbackSymbol)
                .resizable()
                .scaledToFit()
                .foregroundStyle(kind.tint)
        }
    }
}

// MARK: - 反应播放器（全局单例，供各 Manager 触发）

/// 任意系统事件都可调用 `ReactionAnimationPlayer.shared.present(.xxx)` 让 Notch 弹出反应动画。
public final class ReactionAnimationPlayer: ObservableObject {
    public static let shared = ReactionAnimationPlayer()
    public static let reactionSurfaceSize = CGSize(width: 140, height: 124)
    public static let clipboardToastSurfaceSize = CGSize(width: 420, height: 220)

    public struct ActiveReaction: Identifiable {
        public let id = UUID()
        let kind: ReactionAnimationKind
        let caption: String?
        let detail: String?
    }

    @Published public private(set) var active: ActiveReaction?

    public var activeSurfaceSize: CGSize? {
        guard let active else { return nil }
        if active.kind == .clipboard {
            return Self.clipboardToastSurfaceSize
        }
        return Self.reactionSurfaceSize
    }

    private var clearTask: Task<Void, Never>?

    private init() {}

    /// 触发一次反应。duration 传 nil 则按帧数自适应（30fps 放完一轮再留 0.4s）。
    public func present(
        _ kind: ReactionAnimationKind,
        caption: String? = nil,
        detail: String? = nil,
        duration: TimeInterval? = nil
    ) {
        let d = duration ?? Self.adaptiveDuration(for: kind)
        if Thread.isMainThread {
            apply(kind: kind, caption: caption, detail: detail, duration: d)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.apply(kind: kind, caption: caption, detail: detail, duration: d)
            }
        }
    }

    /// 72 帧 @30fps ≈ 2.4s；静帧给短窗口。上限 3s 防止久占刘海。
    static func adaptiveDuration(for kind: ReactionAnimationKind) -> TimeInterval {
        switch kind {
        case .download, .timer, .alarm, .agent:
            return 1.85
        case .music, .volume, .mic:
            return 1.65
        default:
            return 1.45
        }
    }

    public func clear() {
        clearTask?.cancel()
        active = nil
    }

    private func apply(kind: ReactionAnimationKind, caption: String?, detail: String?, duration: TimeInterval) {
        active = ActiveReaction(kind: kind, caption: caption, detail: detail)
        clearTask?.cancel()
        clearTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                guard !Task.isCancelled else { return }
                await MainActor.run { self?.active = nil }
            } catch {}
        }
    }
}

// MARK: - Polished Atoll reaction glyphs

public struct AtollReactionGlyphView: View {
    public let kind: ReactionAnimationKind
    public let size: CGFloat

    public init(kind: ReactionAnimationKind, size: CGFloat = 60) {
        self.kind = kind
        self.size = size
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { ctx in
            glyph(phase: ctx.date.timeIntervalSinceReferenceDate)
        }
        .frame(width: size, height: size)
    }

    private func glyph(phase t: Double) -> some View {
        let palette = kind.atollPalette
        let pulse = 1 + kind.atollPulseAmount * CGFloat(0.5 + 0.5 * sin(t * kind.atollTempo))
        let shimmer = 0.45 + 0.35 * sin(t * 2.4)
        let hitRadius = max(9, size * 0.28)

        return ZStack {
            if kind.atollUsesProgressRing {
                Circle()
                    .trim(from: 0, to: kind.atollProgress(phase: t))
                    .stroke(
                        LinearGradient(colors: [palette.primary, palette.secondary], startPoint: .top, endPoint: .bottom),
                        style: StrokeStyle(lineWidth: max(1.4, size * 0.035), lineCap: .round)
                    )
                    .frame(width: size * 0.78, height: size * 0.78)
                    .rotationEffect(.degrees(-90))
                    .opacity(0.9)
            }

            if kind.atollUsesSignalBars {
                HStack(alignment: .bottom, spacing: max(1.5, size * 0.04)) {
                    ForEach(0..<4, id: \.self) { i in
                        let height = size * (0.08 + 0.12 * CGFloat(0.5 + 0.5 * sin(t * 5.0 + Double(i) * 0.72)))
                        Capsule()
                            .fill(palette.secondary.opacity(0.86))
                            .frame(width: max(2, size * 0.045), height: height)
                    }
                }
                .offset(y: size * 0.28)
            }

            ForEach(0..<3, id: \.self) { i in
                let angle = t * kind.atollOrbitSpeed + Double(i) * 2.094 + kind.atollOrbitOffset
                Circle()
                    .fill(
                        LinearGradient(colors: [Color.white.opacity(0.92), palette.secondary.opacity(0.82)], startPoint: .top, endPoint: .bottom)
                    )
                    .frame(width: size * 0.055, height: size * 0.055)
                    .offset(x: CGFloat(cos(angle)) * size * 0.34, y: CGFloat(sin(angle)) * size * 0.34)
                    .opacity(kind.atollShowsOrbit ? 0.36 + 0.34 * shimmer : 0)
            }

            Image.cuteSymbol(kind.atollSymbol)
                .font(.system(size: size * kind.atollSymbolScale, weight: .semibold, design: .rounded))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(
                    LinearGradient(colors: [Color.white, palette.secondary.opacity(0.92)], startPoint: .top, endPoint: .bottom)
                )
                .shadow(color: palette.primary.opacity(0.55), radius: size * 0.09)
                .rotationEffect(.degrees(kind.atollRotation(phase: t)))
                .offset(y: kind.atollSymbolYOffset * size)
                .scaleEffect(pulse)
        }
        .frame(width: size, height: size)
        .contentShape(RoundedRectangle(cornerRadius: hitRadius, style: .continuous))
    }
}

extension ReactionAnimationKind {
    var atollSymbol: String {
        switch self {
        case .siri: return "sparkles"
        case .clipboard: return "doc.on.clipboard"
        case .battery: return "battery.100"
        case .charging, .bolt: return "bolt.fill"
        case .timer: return "timer"
        case .alarm: return "alarm.fill"
        case .cloud: return "cloud.fill"
        case .coffee: return "cup.and.saucer.fill"
        case .water: return "drop.fill"
        case .move: return "figure.walk"
        case .bell: return "bell.fill"
        case .chart: return "chart.bar.xaxis"
        case .mochi: return "circle.hexagongrid.fill"
        case .brightness: return "sun.max.fill"
        case .volume: return "speaker.wave.3.fill"
        case .music: return "music.note"
        case .mic: return "mic.fill"
        case .download: return "arrow.down.circle.fill"
        case .focus: return "moon.fill"
        case .bluetooth: return "dot.radiowaves.left.and.right"
        case .privacy: return "shield.fill"
        case .lock: return "lock.fill"
        case .app: return "square.grid.2x2.fill"
        case .capslock: return "capslock.fill"
        case .agent: return "cpu.fill"
        case .rain: return "cloud.rain.fill"
        case .storm: return "cloud.bolt.rain.fill"
        case .snowflake, .snowcloud: return "cloud.snow.fill"
        case .suncloud: return "cloud.sun.fill"
        case .mooncloud: return "cloud.moon.fill"
        case .fog: return "cloud.fog.fill"
        }
    }

    var atollPalette: (primary: Color, secondary: Color) {
        switch self {
        case .siri, .mochi:
            return (Color(red: 0.70, green: 0.42, blue: 1.00), Color(red: 0.24, green: 0.82, blue: 1.00))
        case .clipboard, .app:
            return (Color(red: 0.20, green: 0.58, blue: 1.00), Color(red: 0.39, green: 0.93, blue: 1.00))
        case .battery, .charging, .bolt:
            return (Color(red: 0.30, green: 0.92, blue: 0.50), Color(red: 1.00, green: 0.86, blue: 0.24))
        case .timer, .alarm, .bell:
            return (Color(red: 1.00, green: 0.55, blue: 0.22), Color(red: 1.00, green: 0.26, blue: 0.38))
        case .cloud, .download, .bluetooth, .rain, .storm, .snowflake, .suncloud, .mooncloud, .fog, .snowcloud:
            return (Color(red: 0.23, green: 0.74, blue: 1.00), Color(red: 0.44, green: 0.96, blue: 0.88))
        case .coffee:
            return (Color(red: 0.78, green: 0.48, blue: 0.24), Color(red: 1.00, green: 0.78, blue: 0.46))
        case .water:
            return (Color(red: 0.22, green: 0.72, blue: 1.00), Color(red: 0.45, green: 0.92, blue: 1.00))
        case .move:
            return (Color(red: 0.20, green: 0.88, blue: 0.58), Color(red: 0.55, green: 0.98, blue: 0.40))
        case .chart, .music:
            return (Color(red: 1.00, green: 0.33, blue: 0.70), Color(red: 0.72, green: 0.48, blue: 1.00))
        case .brightness:
            return (Color(red: 1.00, green: 0.80, blue: 0.18), Color(red: 1.00, green: 0.42, blue: 0.22))
        case .volume:
            return (Color(red: 0.31, green: 0.64, blue: 1.00), Color(red: 0.70, green: 0.86, blue: 1.00))
        case .mic, .privacy:
            return (Color(red: 1.00, green: 0.34, blue: 0.42), Color(red: 1.00, green: 0.72, blue: 0.64))
        case .focus, .lock:
            return (Color(red: 0.42, green: 0.40, blue: 1.00), Color(red: 0.78, green: 0.86, blue: 1.00))
        case .capslock:
            return (Color(red: 0.82, green: 0.82, blue: 0.90), Color(red: 1.00, green: 0.88, blue: 0.36))
        case .agent:
            return (Color(red: 0.24, green: 0.90, blue: 0.76), Color(red: 0.38, green: 0.62, blue: 1.00))
        }
    }

    var atollSymbolScale: CGFloat {
        switch self {
        case .volume, .chart, .download, .bluetooth: return 0.40
        case .clipboard, .battery, .timer, .alarm, .coffee, .water, .move, .capslock: return 0.38
        default: return 0.43
        }
    }

    var atollSymbolYOffset: CGFloat {
        atollUsesSignalBars ? -0.07 : 0
    }

    var atollPulseAmount: CGFloat {
        switch self {
        case .battery, .clipboard, .privacy, .lock, .capslock: return 0.015
        default: return 0.055
        }
    }

    var atollTempo: Double {
        switch self {
        case .charging, .bolt, .volume, .music, .mic: return 5.2
        case .timer, .alarm, .bell: return 4.2
        default: return 3.0
        }
    }

    var atollOrbitSpeed: Double {
        switch self {
        case .charging, .bolt, .siri, .music, .agent: return 1.9
        default: return 0.9
        }
    }

    var atollOrbitOffset: Double {
        Double(rawValue.hashValue % 17) * 0.17
    }

    var atollShowsOrbit: Bool {
        switch self {
        case .battery, .clipboard, .capslock, .lock, .privacy:
            return false
        default:
            return true
        }
    }

    var atollUsesProgressRing: Bool {
        switch self {
        case .battery, .charging, .bolt, .download, .timer:
            return true
        default:
            return false
        }
    }

    var atollUsesSignalBars: Bool {
        switch self {
        case .volume, .music, .mic, .agent:
            return true
        default:
            return false
        }
    }

    func atollProgress(phase t: Double) -> CGFloat {
        switch self {
        case .battery:
            return 0.72 + 0.10 * CGFloat(0.5 + 0.5 * sin(t * 1.8))
        case .charging, .bolt:
            return 0.22 + 0.64 * CGFloat((t * 0.58).truncatingRemainder(dividingBy: 1))
        case .download:
            return 0.14 + 0.72 * CGFloat((t * 0.42).truncatingRemainder(dividingBy: 1))
        case .timer:
            return 0.18 + 0.70 * CGFloat(0.5 + 0.5 * sin(t * 1.5))
        default:
            return 0
        }
    }

    func atollRotation(phase t: Double) -> Double {
        switch self {
        case .timer, .alarm, .bell:
            return sin(t * 6.5) * 5
        case .charging, .bolt:
            return sin(t * 8.0) * 3
        case .download:
            return sin(t * 3.0) * 2
        default:
            return 0
        }
    }
}

// MARK: - 可爱的程序化反应动画（完全自绘，不依赖任何外部资源）

/// 每个系统事件对应一段手绘的可爱矢量动画，使用 SwiftUI 形状 + 时间驱动相位绘制，
/// 保证一定能渲染，彻底告别占位/兜底。
public struct CuteReactionView: View {
    public let kind: ReactionAnimationKind
    public let size: CGFloat
    @State private var start = Date()

    public init(kind: ReactionAnimationKind, size: CGFloat = 60) {
        self.kind = kind
        self.size = size
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { ctx in
            content(phase: ctx.date.timeIntervalSinceReferenceDate)
        }
        .frame(width: size, height: size)
    }

    // ponytail: 22 分支 @ViewBuilder 在 Debug 下单帧数 MB 直接爆栈(___chkstk SIGSEGV)，改 AnyView 早退 switch 压栈帧
    private func content(phase t: Double) -> AnyView {
        let pal = kind.atollPalette
        let inner: AnyView = {
            switch kind {
            case .mochi: return AnyView(mochi(t))
            case .siri: return AnyView(siri(t))
            case .clipboard: return AnyView(clipboard(t))
            case .battery: return AnyView(battery(t))
            case .charging, .bolt: return AnyView(bolt(t))
            case .timer, .alarm: return AnyView(alarm(t))
            case .cloud: return AnyView(cloud(t))
            case .coffee: return AnyView(coffee(t))
            case .water: return AnyView(water(t))
            case .move: return AnyView(move(t))
            case .bell: return AnyView(bell(t))
            case .chart: return AnyView(chart(t))
            case .brightness: return AnyView(brightness(t))
            case .volume: return AnyView(volume(t))
            case .music: return AnyView(music(t))
            case .mic: return AnyView(mic(t))
            case .download: return AnyView(download(t))
            case .focus: return AnyView(focus(t))
            case .bluetooth: return AnyView(bluetooth(t))
            case .privacy: return AnyView(privacy(t))
            case .lock: return AnyView(lock(t))
            case .app: return AnyView(app(t))
            case .capslock: return AnyView(capslock(t))
            case .agent: return AnyView(agentWorking(t))
            case .rain: return AnyView(WeatherCuteIcon(symbolName: "cloud.rain.fill", size: 46))
            case .storm: return AnyView(WeatherCuteIcon(symbolName: "cloud.bolt.rain.fill", size: 46))
            case .snowflake, .snowcloud: return AnyView(WeatherCuteIcon(symbolName: "cloud.snow.fill", size: 46))
            case .suncloud: return AnyView(WeatherCuteIcon(symbolName: "cloud.sun.fill", size: 46))
            case .mooncloud: return AnyView(WeatherCuteIcon(symbolName: "cloud.moon.fill", size: 46))
            case .fog: return AnyView(WeatherCuteIcon(symbolName: "cloud.fog.fill", size: 46))
            }
        }()
        // 统一套入 3D 玻璃质感外壳，保证全家族视觉一致
        return AnyView(
            GlassPod(palette: pal, shape: .roundedRect, size: max(48, size)) {
                inner
            }
            .frame(width: size, height: size)
        )
    }

    // 圆滚滚吉祥物：呼吸挤压 + 偶尔眨眼
    private func mochi(_ t: Double) -> some View {
        let squish = sin(t * 3)
        let scaleX = 1 + 0.10 * squish
        let scaleY = 1 - 0.10 * squish
        let blink = t.truncatingRemainder(dividingBy: 3) > 2.7
        return ZStack {
            Circle()
                .fill(LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom))
                .frame(width: 46, height: 46)
                .scaleEffect(x: CGFloat(scaleX), y: CGFloat(scaleY))
                .shadow(radius: 3, y: 2)
            HStack(spacing: 12) {
                if blink {
                    Capsule().fill(.black).frame(width: 7, height: 2)
                } else {
                    Circle().fill(.black).frame(width: 7, height: 7)
                }
                if blink {
                    Capsule().fill(.black).frame(width: 7, height: 2)
                } else {
                    Circle().fill(.black).frame(width: 7, height: 7)
                }
            }
            .offset(y: -4)
            Path { p in
                p.move(to: CGPoint(x: -9, y: 6))
                p.addQuadCurve(to: CGPoint(x: 9, y: 6), control: CGPoint(x: 0, y: 13))
            }
            .stroke(.black, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            // 腮红
            Circle().fill(.red.opacity(0.35)).frame(width: 7, height: 5).offset(x: -15, y: 3)
            Circle().fill(.red.opacity(0.35)).frame(width: 7, height: 5).offset(x: 15, y: 3)
        }
    }

    // Siri：多层声波环 + 中心小球脉动
    private func siri(_ t: Double) -> some View {
        ZStack {
            ForEach(0 ..< 3) { i in
                let p = 1 + 0.35 * sin(t * 4 - Double(i) * 0.8)
                Circle()
                    .stroke(Color.purple.opacity(0.55), lineWidth: 3)
                    .frame(width: 22 + CGFloat(i) * 14 * CGFloat(p), height: 22 + CGFloat(i) * 14 * CGFloat(p))
                    .opacity(0.6 - Double(i) * 0.15)
            }
            Circle()
                .fill(LinearGradient(colors: [.purple, .indigo], startPoint: .top, endPoint: .bottom))
                .frame(width: 24, height: 24)
                .scaleEffect(1 + 0.08 * sin(t * 4))
                .shadow(radius: 4)
        }
    }

    // 复制：文档弹入 + 绿色对勾
    private func clipboard(_ t: Double) -> some View {
        let pop = min(1, t / 0.35)
        let bounce = sin(t * 6) * 0.5 * max(0, 1 - pop)
        return ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white)
                .frame(width: 34, height: 42)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.blue, lineWidth: 3))
                .scaleEffect(CGFloat(pop))
                .offset(y: CGFloat(bounce))
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.blue)
                .frame(width: 16, height: 9)
                .offset(y: -24)
                .scaleEffect(CGFloat(pop))
            Path { p in
                p.move(to: CGPoint(x: -8, y: 2))
                p.addLine(to: CGPoint(x: -2, y: 9))
                p.addLine(to: CGPoint(x: 10, y: -8))
            }
            .stroke(Color.green, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            .scaleEffect(CGFloat(pop))
        }
    }

    // 电池满电：绿色填充 + 笑脸
    private func battery(_ t: Double) -> some View {
        let fill = 0.5 + 0.5 * (0.5 + 0.5 * sin(t * 2))
        return ZStack {
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.green, lineWidth: 3)
                .frame(width: 46, height: 26)
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.green)
                .frame(width: 4, height: 9)
                .offset(x: 25)
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.green.opacity(0.85))
                .frame(width: 38 * CGFloat(fill), height: 18)
                .offset(x: CGFloat(-2 + (1 - fill) * 9))
            HStack(spacing: 9) {
                Circle().fill(.black).frame(width: 3.5, height: 3.5)
                Circle().fill(.black).frame(width: 3.5, height: 3.5)
            }
            .offset(y: -3)
            Path { p in
                p.move(to: CGPoint(x: -7, y: 3))
                p.addQuadCurve(to: CGPoint(x: 7, y: 3), control: CGPoint(x: 0, y: 9))
            }
            .stroke(.black, style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
    }

    // 充电 / 闪电：抖动 + 火花环绕
    private func bolt(_ t: Double) -> some View {
        let zap = 1 + 0.12 * sin(t * 10)
        return ZStack {
            ForEach(0 ..< 3) { i in
                let ang = Double(i) * 2.1 + t * 2
                Circle()
                    .fill(Color.yellow)
                    .frame(width: 5, height: 5)
                    .offset(x: CGFloat(cos(ang) * 22), y: CGFloat(sin(ang) * 22))
                    .opacity(0.6 + 0.4 * sin(t * 6 + Double(i)))
            }
            Path { p in
                p.move(to: CGPoint(x: 0, y: -22))
                p.addLine(to: CGPoint(x: -12, y: 4))
                p.addLine(to: CGPoint(x: 0, y: 4))
                p.addLine(to: CGPoint(x: -2, y: 22))
                p.addLine(to: CGPoint(x: 12, y: -4))
                p.addLine(to: CGPoint(x: 0, y: -4))
                p.closeSubpath()
            }
            .fill(LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom))
            .scaleEffect(CGFloat(zap))
            .rotationEffect(.degrees(Double(sin(t * 8) * 6)))
            .shadow(radius: 3, y: 2)
        }
    }

    // 闹钟 / 计时：摇摆 + 响铃声波
    private func alarm(_ t: Double) -> some View {
        let shake = sin(t * 8) * 0.12
        return ZStack {
            ForEach(0 ..< 2) { i in
                Circle()
                    .stroke(Color.orange.opacity(0.5), lineWidth: 2)
                    .frame(width: 42 + CGFloat(i) * 16, height: 42 + CGFloat(i) * 16)
                    .opacity(0.5 - Double(i) * 0.2 + 0.2 * sin(t * 5))
            }
            ZStack {
                Circle().fill(LinearGradient(colors: [.orange, .red], startPoint: .top, endPoint: .bottom)).frame(width: 36, height: 36)
                Circle().fill(.orange).frame(width: 9, height: 9).offset(x: -14, y: -17)
                Circle().fill(.orange).frame(width: 9, height: 9).offset(x: 14, y: -17)
                Circle().fill(.white).frame(width: 24, height: 24)
                Rectangle().fill(.black).frame(width: 2.5, height: 9).offset(y: -2)
                Rectangle().fill(.black).frame(width: 7, height: 2.5).offset(x: 2.5, y: 0)
            }
            .rotationEffect(.degrees(shake * 57.3))
        }
    }

    // 云朵：上下漂浮 + 落雨
    private func cloud(_ t: Double) -> some View {
        let float = sin(t * 2) * 6
        return ZStack {
            ZStack {
                Circle().fill(.white).frame(width: 22, height: 22).offset(x: -12, y: 3)
                Circle().fill(.white).frame(width: 28, height: 28)
                Circle().fill(.white).frame(width: 22, height: 22).offset(x: 12, y: 3)
                Capsule().fill(.white).frame(width: 46, height: 20).offset(y: 8)
            }
            .shadow(radius: 2, y: 2)
            ForEach(0 ..< 3) { i in
                let dt = (t * 2 + Double(i) * 0.5).truncatingRemainder(dividingBy: 1)
                Circle().fill(Color.cyan).frame(width: 4, height: 6)
                    .offset(x: CGFloat((Double(i) - 1) * 12), y: 20 + CGFloat(dt) * 14)
                    .opacity(1 - dt)
            }
        }
        .offset(y: CGFloat(float))
    }

    // 咖啡：杯体 + 上升热气
    private func coffee(_ t: Double) -> some View {
        ZStack {
            ForEach(0 ..< 3) { i in
                let s = sin(t * 3 + Double(i) * 1.5)
                Path { p in
                    p.move(to: CGPoint(x: 0, y: 0))
                    p.addQuadCurve(to: CGPoint(x: CGFloat(s * 6), y: -16), control: CGPoint(x: CGFloat(s * 4), y: -8))
                }
                .stroke(Color.gray.opacity(0.6), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .offset(x: CGFloat((Double(i) - 1) * 7), y: -16)
                .opacity(0.5 + 0.4 * (0.5 + 0.5 * s))
            }
            ZStack {
                RoundedRectangle(cornerRadius: 6).fill(Color(red: 0.45, green: 0.25, blue: 0.12)).frame(width: 32, height: 26)
                Circle().stroke(Color(red: 0.45, green: 0.25, blue: 0.12), lineWidth: 4).frame(width: 14, height: 14).offset(x: 20)
                Ellipse().fill(Color(red: 0.3, green: 0.15, blue: 0.05)).frame(width: 26, height: 6)
            }
        }
    }

    // 喝水提醒：晶莹水杯 + 水滴涟漪 + 上升气泡 + 弹跳水珠
    private func water(_ t: Double) -> some View {
        let wave = sin(t * 4.5) * 2.2
        let dropProgress = (t * 1.5).truncatingRemainder(dividingBy: 1.0)
        let dropY = -24.0 + dropProgress * 28.0
        let dropOpacity = dropProgress < 0.85 ? 1.0 : max(0.0, (1.0 - dropProgress) / 0.15)
        let splashScale = dropProgress > 0.7 ? (dropProgress - 0.7) / 0.3 : 0.0

        return ZStack {
            // 水杯外形
            Path { p in
                p.move(to: CGPoint(x: -13, y: -12))
                p.addLine(to: CGPoint(x: -10, y: 13))
                p.addQuadCurve(to: CGPoint(x: 10, y: 13), control: CGPoint(x: 0, y: 16))
                p.addLine(to: CGPoint(x: 13, y: -12))
                p.closeSubpath()
            }
            .fill(LinearGradient(colors: [Color.cyan.opacity(0.25), Color.blue.opacity(0.35)], startPoint: .top, endPoint: .bottom))
            .overlay(
                Path { p in
                    p.move(to: CGPoint(x: -13, y: -12))
                    p.addLine(to: CGPoint(x: -10, y: 13))
                    p.addQuadCurve(to: CGPoint(x: 10, y: 13), control: CGPoint(x: 0, y: 16))
                    p.addLine(to: CGPoint(x: 13, y: -12))
                }
                .stroke(Color.cyan.opacity(0.85), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
            )

            // 杯内水面与波浪
            Path { p in
                p.move(to: CGPoint(x: -11, y: 2 + wave))
                p.addQuadCurve(to: CGPoint(x: 11, y: 2 - wave), control: CGPoint(x: 0, y: 2 + wave * 1.2))
                p.addLine(to: CGPoint(x: 9, y: 12))
                p.addQuadCurve(to: CGPoint(x: -9, y: 12), control: CGPoint(x: 0, y: 15))
                p.closeSubpath()
            }
            .fill(LinearGradient(colors: [Color.cyan.opacity(0.85), Color.blue.opacity(0.95)], startPoint: .top, endPoint: .bottom))

            // 水中上升气泡
            ForEach(0 ..< 3) { i in
                let bubbleProgress = (t * 2.0 + Double(i) * 0.33).truncatingRemainder(dividingBy: 1.0)
                Circle()
                    .fill(Color.white.opacity(0.75))
                    .frame(width: 2.8, height: 2.8)
                    .offset(x: CGFloat((Double(i) - 1.0) * 4.5), y: CGFloat(11 - bubbleProgress * 9))
                    .opacity(1.0 - bubbleProgress)
            }

            // 滴落水珠
            if dropProgress < 0.85 {
                Circle()
                    .fill(LinearGradient(colors: [Color.white, Color.cyan], startPoint: .top, endPoint: .bottom))
                    .frame(width: 4.2, height: 5.5)
                    .offset(y: CGFloat(dropY))
                    .opacity(dropOpacity)
            }

            // 溅起微涟漪
            if splashScale > 0 {
                Ellipse()
                    .stroke(Color.white.opacity(0.85 * (1.0 - splashScale)), lineWidth: 1.4)
                    .frame(width: CGFloat(9 * splashScale), height: CGFloat(3.5 * splashScale))
                    .offset(y: 2.5)
            }
        }
    }

    // 运动/站立提醒：活力奔跑小人 + 运动能量粒子
    private func move(_ t: Double) -> some View {
        let bounce = abs(sin(t * 6)) * 3.5
        let legAngle = sin(t * 8) * 32
        let armAngle = -sin(t * 8) * 32

        return ZStack {
            // 环绕能量星芒
            ForEach(0 ..< 3) { i in
                let ang = Double(i) * 2.094 + t * 3.5
                Circle()
                    .fill(Color.green.opacity(0.85))
                    .frame(width: 3.5, height: 3.5)
                    .offset(x: CGFloat(cos(ang) * 19), y: CGFloat(sin(ang) * 19))
                    .opacity(0.5 + 0.5 * sin(t * 5 + Double(i)))
            }

            // 头部
            Circle()
                .fill(LinearGradient(colors: [Color.green, Color.mint], startPoint: .top, endPoint: .bottom))
                .frame(width: 12, height: 12)
                .offset(y: -13 - CGFloat(bounce))
                .shadow(radius: 2)

            // 身体躯干
            Capsule()
                .fill(Color.green)
                .frame(width: 5.5, height: 15)
                .offset(y: 0.5 - CGFloat(bounce))

            // 手臂摆动
            Capsule()
                .fill(Color.green.opacity(0.9))
                .frame(width: 3.8, height: 11)
                .offset(y: 4.5)
                .rotationEffect(.degrees(armAngle), anchor: .top)
                .offset(y: -4 - CGFloat(bounce))

            // 腿部奔跑
            HStack(spacing: 2) {
                Capsule()
                    .fill(Color.mint)
                    .frame(width: 3.8, height: 13)
                    .offset(y: 5.5)
                    .rotationEffect(.degrees(-legAngle), anchor: .top)
                Capsule()
                    .fill(Color.mint)
                    .frame(width: 3.8, height: 13)
                    .offset(y: 5.5)
                    .rotationEffect(.degrees(legAngle), anchor: .top)
            }
            .offset(y: 5.5 - CGFloat(bounce))
        }
    }

    // 铃铛：摆动 + 响铃环
    private func bell(_ t: Double) -> some View {
        let swing = sin(t * 6) * 0.2
        return ZStack {
            ForEach(0 ..< 2) { i in
                Circle()
                    .stroke(Color.orange.opacity(0.5), lineWidth: 2)
                    .frame(width: 38 + CGFloat(i) * 14, height: 38 + CGFloat(i) * 14)
                    .opacity(0.4 + 0.3 * sin(t * 5 + Double(i)))
            }
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: -14, y: 12))
                    p.addQuadCurve(to: CGPoint(x: 0, y: -18), control: CGPoint(x: -16, y: -10))
                    p.addQuadCurve(to: CGPoint(x: 14, y: 12), control: CGPoint(x: 16, y: -10))
                    p.addLine(to: CGPoint(x: -14, y: 12))
                }
                .fill(LinearGradient(colors: [.orange, .yellow], startPoint: .top, endPoint: .bottom))
                Circle().fill(.orange).frame(width: 6, height: 6).offset(y: 13)
                Circle().fill(.black).frame(width: 5, height: 5).offset(y: 16)
            }
            .rotationEffect(.degrees(swing * 57.3))
        }
    }

    // 图表：柱子生长 + 上升趋势箭头
    private func chart(_ t: Double) -> some View {
        let heights: [Double] = [0.5, 0.8, 1.0]
        return ZStack {
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(0 ..< 3) { i in
                    let h = heights[i] * (0.7 + 0.3 * max(0, sin(t * 3 + Double(i))))
                    Capsule()
                        .fill(LinearGradient(colors: [.pink, .purple], startPoint: .bottom, endPoint: .top))
                        .frame(width: 10, height: CGFloat(h) * 40)
                }
            }
            .frame(height: 40, alignment: .bottom)
            Path { p in
                p.move(to: CGPoint(x: -16, y: 16))
                p.addLine(to: CGPoint(x: 16, y: -16))
                p.move(to: CGPoint(x: 16, y: -16))
                p.addLine(to: CGPoint(x: 8, y: -16))
                p.move(to: CGPoint(x: 16, y: -16))
                p.addLine(to: CGPoint(x: 16, y: -8))
            }
            .stroke(Color.green, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        }
    }
}

    // 亮度：脉动太阳 + 旋转光芒
    private func brightness(_ t: Double) -> some View {
        let glow = 0.5 + 0.5 * sin(t * 2)
        return ZStack {
            ForEach(0 ..< 8) { i in
                let a = Double(i) * Double.pi / 4 + t * 0.3
                Rectangle()
                    .fill(Color.yellow.opacity(0.85))
                    .frame(width: 3, height: 10)
                    .offset(x: CGFloat(cos(a) * 18), y: CGFloat(sin(a) * 18))
                    .rotationEffect(.degrees(a * 57.3))
            }
            Circle()
                .fill(LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom))
                .frame(width: 24 + CGFloat(glow) * 6, height: 24 + CGFloat(glow) * 6)
                .shadow(radius: 5)
        }
    }

    // 音量：扬声器 + 跳动声波
    private func volume(_ t: Double) -> some View {
        ZStack {
            Path { p in
                p.move(to: CGPoint(x: -12, y: -6))
                p.addLine(to: CGPoint(x: -6, y: -6))
                p.addLine(to: CGPoint(x: 0, y: -12))
                p.addLine(to: CGPoint(x: 0, y: 12))
                p.addLine(to: CGPoint(x: -6, y: 6))
                p.addLine(to: CGPoint(x: -12, y: 6))
                p.closeSubpath()
            }
            .fill(Color.blue)
            ForEach(0 ..< 3) { i in
                let s = 0.5 + 0.5 * sin(t * 4 - Double(i) * 0.8)
                Path { p in
                    p.move(to: CGPoint(x: 5, y: -CGFloat(4 + i * 4)))
                    p.addQuadCurve(to: CGPoint(x: 5, y: CGFloat(4 + i * 4)), control: CGPoint(x: CGFloat(13 + Double(i) * 4) * CGFloat(s), y: 0))
                }
                .stroke(Color.blue.opacity(0.85), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            }
        }
    }

    // 音乐：浮动音符 + 均衡器条
    private func music(_ t: Double) -> some View {
        let eq: [Double] = [0.4, 0.8, 0.6, 1.0, 0.5]
        return ZStack {
            Image.cuteSymbol("music.note")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(LinearGradient(colors: [.pink, .purple], startPoint: .top, endPoint: .bottom))
                .offset(y: CGFloat(sin(t * 3) * 6))
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0 ..< 5) { i in
                    let h = eq[i] * (0.5 + 0.5 * sin(t * 5 + Double(i) * 0.7))
                    Capsule().fill(Color.pink).frame(width: 3, height: CGFloat(h) * 18)
                }
            }
            .offset(y: 18)
        }
    }

    // 麦克风 / 录音：话筒 + 脉冲环
    private func mic(_ t: Double) -> some View {
        ZStack {
            Capsule().fill(Color.red.opacity(0.9)).frame(width: 14, height: 22).offset(y: -2)
            Path { p in
                p.move(to: CGPoint(x: -8, y: 12))
                p.addQuadCurve(to: CGPoint(x: 8, y: 12), control: CGPoint(x: 0, y: 20))
            }
            .stroke(Color.red, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            ForEach(0 ..< 2) { i in
                Circle().stroke(Color.red.opacity(0.5), lineWidth: 2)
                    .frame(width: 20 + CGFloat(i) * 12, height: 20 + CGFloat(i) * 12)
                    .opacity(0.5 + 0.3 * sin(t * 4 + Double(i)))
            }
        }
    }

    // 下载：进度环 + 跳动箭头
    private func download(_ t: Double) -> some View {
        let prog = (t.truncatingRemainder(dividingBy: 2)) / 2
        return ZStack {
            Circle().stroke(Color.green.opacity(0.3), lineWidth: 4).frame(width: 40, height: 40)
            Circle()
                .trim(from: 0, to: CGFloat(prog))
                .stroke(Color.green, lineWidth: 4)
                .frame(width: 40, height: 40)
                .rotationEffect(.degrees(-90))
            Image.cuteSymbol("arrow.down")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.green)
                .offset(y: CGFloat(sin(t * 4) * 3))
        }
    }

    // 状态：月亮 + Zzz
    private func focus(_ t: Double) -> some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [.indigo, .purple], startPoint: .top, endPoint: .bottom))
                .frame(width: 32, height: 32)
                .shadow(radius: 4)
            ForEach(0 ..< 3) { i in
                let p = (t * 0.8 + Double(i) * 0.4).truncatingRemainder(dividingBy: 1)
                Text("Z").font(.system(size: CGFloat(10 + i * 3), weight: .bold))
                    .foregroundStyle(Color.indigo)
                    .offset(x: CGFloat(12 + i * 4), y: CGFloat(-10 - p * 16))
                    .opacity(1 - p)
            }
        }
    }

    // 蓝牙：双设备 + 跳动符文
    private func bluetooth(_ t: Double) -> some View {
        let pop = 1 + 0.1 * sin(t * 6)
        return ZStack {
            Circle().fill(Color.blue.opacity(0.8)).frame(width: 8, height: 8).offset(x: -16, y: -8)
            Circle().fill(Color.blue.opacity(0.8)).frame(width: 8, height: 8).offset(x: 16, y: 8)
            Path { p in
                p.move(to: CGPoint(x: 0, y: -14))
                p.addLine(to: CGPoint(x: -6, y: 0))
                p.addLine(to: CGPoint(x: 6, y: 0))
                p.addLine(to: CGPoint(x: 0, y: 14))
                p.addLine(to: CGPoint(x: -6, y: 0))
                p.addLine(to: CGPoint(x: 6, y: 0))
            }
            .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            .scaleEffect(CGFloat(pop))
        }
    }

    // 隐私：盾牌 + 相机镜头脉动
    private func privacy(_ t: Double) -> some View {
        let pulse = 0.5 + 0.5 * sin(t * 3)
        return ZStack {
            Path { p in
                p.move(to: CGPoint(x: 0, y: -16))
                p.addLine(to: CGPoint(x: 14, y: -10))
                p.addLine(to: CGPoint(x: 14, y: 4))
                p.addQuadCurve(to: CGPoint(x: 0, y: 16), control: CGPoint(x: 14, y: 12))
                p.addQuadCurve(to: CGPoint(x: -14, y: 4), control: CGPoint(x: -14, y: 12))
                p.addLine(to: CGPoint(x: -14, y: -10))
                p.closeSubpath()
            }
            .fill(Color.green.opacity(0.85))
            Circle().fill(.white).frame(width: 12, height: 12)
            Circle().fill(.black).frame(width: 6, height: 6)
            Circle().fill(Color.green).frame(width: 3, height: 3).opacity(CGFloat(pulse))
        }
    }

    // 锁屏：挂锁摇摆
    private func lock(_ t: Double) -> some View {
        let wiggle = sin(t * 10) * 0.15
        return ZStack {
            Path { p in
                p.move(to: CGPoint(x: -8, y: -2))
                p.addQuadCurve(to: CGPoint(x: 0, y: -14), control: CGPoint(x: -8, y: -14))
                p.addQuadCurve(to: CGPoint(x: 8, y: -2), control: CGPoint(x: 8, y: -14))
            }
            .stroke(Color.gray, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
            RoundedRectangle(cornerRadius: 5)
                .fill(LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom))
                .frame(width: 30, height: 24)
                .offset(y: 12)
            Circle().fill(.black).frame(width: 4, height: 4).offset(y: 12)
            Path { p in
                p.move(to: CGPoint(x: 0, y: 8))
                p.addLine(to: CGPoint(x: 0, y: 16))
            }
            .stroke(.black, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            .offset(y: 12)
        }
        .rotationEffect(.degrees(wiggle * 57.3))
    }

    // 第三方扩展活动：App 图标弹跳
    private func app(_ t: Double) -> some View {
        let bounce = abs(sin(t * 4))
        return RoundedRectangle(cornerRadius: 12)
            .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 36, height: 36)
            .scaleEffect(1 + 0.12 * CGFloat(bounce))
            .shadow(radius: 4)
    }

    // 大写锁定：键帽 + ⇪ 点亮
    private func capslock(_ t: Double) -> some View {
        let on = 0.5 + 0.5 * sin(t * 3)
        return ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 34, height: 30)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray, lineWidth: 2))
            Text("⇪")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.yellow.opacity(0.6 + 0.4 * CGFloat(on)))
        }
    }

    // 智能体工作：反重力太空宇航小萌宠 + 眨眼 + 旋转星轨 + 环绕星光粒子
    private func agentWorking(_ t: Double) -> some View {
        let bob = CGFloat(sin(t * 3.5) * 2.5)
        let blink = t.truncatingRemainder(dividingBy: 2.2) > 1.95
        return ZStack {
            // 环绕反重力能量星光
            ForEach(0 ..< 3) { i in
                let a = t * 2.8 + Double(i) * 2.094
                Circle()
                    .fill(LinearGradient(colors: [Color.cyan, Color.purple], startPoint: .top, endPoint: .bottom))
                    .frame(width: 4.5, height: 4.5)
                    .offset(x: CGFloat(cos(a) * 23), y: CGFloat(sin(a) * 23))
                    .opacity(0.6 + 0.4 * sin(t * 4 + Double(i)))
            }

            // 头顶反重力旋转星轨
            Ellipse()
                .stroke(
                    LinearGradient(colors: [Color(red: 0.85, green: 0.65, blue: 1.0), Color.cyan, Color.purple],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1.8
                )
                .frame(width: 32, height: 11)
                .rotationEffect(.degrees(-20))
                .offset(y: -15 + bob)

            // 太空宇航头盔
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.95, green: 0.90, blue: 1.0),
                            Color(red: 0.65, green: 0.45, blue: 0.98),
                            Color(red: 0.20, green: 0.82, blue: 0.95)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 32, height: 32)
                .shadow(color: Color.purple.opacity(0.5), radius: 3.5, y: 1.5)
                .offset(y: bob)

            // 高光镜面
            Circle()
                .stroke(Color.white.opacity(0.9), lineWidth: 1.5)
                .frame(width: 30, height: 30)
                .mask(LinearGradient(colors: [.white, .clear], startPoint: .topLeading, endPoint: .center))
                .offset(y: bob)

            // 大眼睛与眨眼
            HStack(spacing: 7) {
                if blink {
                    Capsule().fill(.black).frame(width: 6, height: 2)
                    Capsule().fill(.black).frame(width: 6, height: 2)
                } else {
                    ZStack {
                        Circle().fill(Color(red: 0.1, green: 0.05, blue: 0.2)).frame(width: 6.5, height: 7)
                        Circle().fill(.white).frame(width: 2.2, height: 2.2).offset(x: -1.2, y: -1.2)
                    }
                    ZStack {
                        Circle().fill(Color(red: 0.1, green: 0.05, blue: 0.2)).frame(width: 6.5, height: 7)
                        Circle().fill(.white).frame(width: 2.2, height: 2.2).offset(x: -1.2, y: -1.2)
                    }
                }
            }
            .offset(y: bob - 1)

            // 粉嫩腮红
            HStack(spacing: 16) {
                Circle().fill(Color.pink.opacity(0.6)).frame(width: 4.5, height: 3)
                Circle().fill(Color.pink.opacity(0.6)).frame(width: 4.5, height: 3)
            }
            .offset(y: bob + 4.5)

            // 小手向用户挥手
            Circle()
                .fill(Color.white.opacity(0.95))
                .frame(width: 5.5, height: 5.5)
                .offset(x: 15, y: bob - 1 + CGFloat(sin(t * 8) * 2.0))
        }
    }

// MARK: - 反应动画叠层（挂到 NotchLayout 之上，不干扰既有渲染链）

/// 渲染当前激活的反应动画，弹入/弹出带弹簧过渡。
public struct ReactionAnimationOverlay: View {
    @ObservedObject private var player = ReactionAnimationPlayer.shared
    private let cameraSafeTop: CGFloat
    private let clipboardToastSize = CGSize(width: 310, height: 64)

    public init(cameraSafeTop: CGFloat = 0) {
        self.cameraSafeTop = max(0, cameraSafeTop)
    }

    private var clipboardToastYOffset: CGFloat {
        max(72, cameraSafeTop + 52)
    }

    private var reactionIconYOffset: CGFloat {
        max(8, cameraSafeTop + 10)
    }

    private var surfaceSize: CGSize {
        guard player.active?.kind == .clipboard else {
            return player.activeSurfaceSize ?? CGSize(width: 80, height: 80)
        }
        let base = player.activeSurfaceSize ?? ReactionAnimationPlayer.clipboardToastSurfaceSize
        return CGSize(
            width: max(base.width, clipboardToastSize.width),
            height: max(base.height, clipboardToastYOffset + clipboardToastSize.height + 24)
        )
    }

    public var body: some View {
        ZStack {
            if let active = player.active {
                if active.kind == .clipboard {
                    ClipboardReactionToast(
                        caption: active.caption ?? "剪贴板已保存",
                        detail: active.detail
                    )
                    .frame(width: clipboardToastSize.width, height: clipboardToastSize.height)
                    .offset(y: clipboardToastYOffset)
                    .zIndex(1000)
                    .transition(DynamicIslandAnimations.transition(.reactionPop))
                } else {
                    CuteReactionView(kind: active.kind, size: 62)
                        .offset(y: reactionIconYOffset)
                        .transition(DynamicIslandAnimations.transition(.reactionPop))
                }
            }
        }
        .frame(
            width: surfaceSize.width,
            height: surfaceSize.height,
            alignment: .top
        )
        .allowsHitTesting(false)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: player.active?.id)
    }
}

private struct ClipboardReactionToast: View {
    let caption: String
    let detail: String?

    var body: some View {
        HStack(spacing: 9) {
            ClipboardToastIcon()
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(caption)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.78))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(maxWidth: 212, alignment: .leading)
        }
        .padding(.leading, 9)
        .padding(.trailing, 14)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.88))
                .shadow(color: Color.black.opacity(0.42), radius: 14, y: 6)
        }
    }
}

private struct ClipboardToastIcon: View {
    @State private var bounce = false

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.cyan.opacity(0.42),
                            Color.blue.opacity(0.12),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 2,
                        endRadius: 28
                    )
                )
                .scaleEffect(bounce ? 1.08 : 0.96)

            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white, Color(red: 0.80, green: 0.94, blue: 1.0)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 26, height: 31)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color(red: 0.26, green: 0.64, blue: 1.0), lineWidth: 2)
                )
                .rotationEffect(.degrees(-5))
                .offset(x: -2, y: 1)

            Capsule(style: .continuous)
                .fill(Color(red: 0.38, green: 0.82, blue: 1.0))
                .frame(width: 16, height: 7)
                .offset(x: -2, y: -17)

            Path { p in
                p.move(to: CGPoint(x: -8, y: 2))
                p.addLine(to: CGPoint(x: -2, y: 8))
                p.addLine(to: CGPoint(x: 11, y: -8))
            }
            .stroke(Color(red: 0.24, green: 0.95, blue: 0.60), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            .offset(x: 5, y: 6)
            .scaleEffect(bounce ? 1.0 : 0.92)

            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 4, height: 4)
                .offset(x: -16, y: -12)
            Circle()
                .fill(Color.cyan.opacity(0.8))
                .frame(width: 5, height: 5)
                .offset(x: 17, y: -14)
        }
        .task {
            await AtollMotion.runPulseLoop(
                isEnabled: true,
                initialDelay: 120_000_000,
                interval: 1_800_000_000,
                hold: 320_000_000
            ) { bounce = $0 }
        }
    }
}
