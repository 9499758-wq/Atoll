import SwiftUI

// MARK: - Atoll 动画图标设计系统 (Iconography)
//
// 一套统一的 3D 玻璃质感视觉语言，覆盖 notch 内所有动画图标：
//   - 统一光源：左上方主光，右下方环境光遮蔽(AO)
//   - 统一材质：玻璃砖(GlassPod) + 内部品牌辉光 + 接触阴影
//   - 统一动效：轻微 3D 呼吸(rotation3DEffect) + 弹性入场
// 所有图标共用此基底，保证“像一家人”。

/// 设计令牌：统一圆角、光照角度、阴影参数
public enum IconTokens {
    public static let cornerRatio: CGFloat = 0.30   // 圆角占尺寸比例
    public static let lightAngle = UnitPoint(x: 0.32, y: 0.26) // 左上方主光
    public static let rimOpacity: CGFloat = 0.28
    public static let specularOpacity: CGFloat = 0.55
    public static let contactShadowOpacity: CGFloat = 0.30
}

/// 玻璃砖容器：所有图标的统一 3D 外壳
public struct GlassPod<Content: View>: View {
    public let palette: (primary: Color, secondary: Color)
    public let shape: PodShape
    public let animate: Bool
    public let size: CGFloat
    public let content: Content

    public enum PodShape { case roundedRect, circle }

    @State private var breathe: Double = 0

    public init(
        palette: (primary: Color, secondary: Color),
        shape: PodShape = .roundedRect,
        animate: Bool = true,
        size: CGFloat = 64,
        @ViewBuilder content: () -> Content
    ) {
        self.palette = palette
        self.shape = shape
        self.animate = animate
        self.size = size
        self.content = content()
    }

    private func shell(_ s: CGFloat) -> some View {
        let r = shape == .circle ? s / 2 : s * IconTokens.cornerRatio
        return ZStack {
            // 接触阴影（底部）
            RoundedRectangle(cornerRadius: r)
                .fill(Color.black.opacity(IconTokens.contactShadowOpacity))
                .blur(radius: s * 0.10)
                .offset(y: s * 0.16)
                .scaleEffect(0.92)
            // 砖体：垂直渐变（上亮下暗）
            RoundedRectangle(cornerRadius: r)
                .fill(LinearGradient(
                    colors: [palette.primary.opacity(0.32), palette.secondary.opacity(0.14)],
                    startPoint: .top, endPoint: .bottom))
                .overlay(
                    RoundedRectangle(cornerRadius: r)
                        .stroke(
                            LinearGradient(colors: [.white.opacity(IconTokens.rimOpacity),
                                                   .clear, .black.opacity(0.25)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: max(1, s * 0.03))
                )
            // 左上主光高光
            GeometryReader { geo in
                Ellipse()
                    .fill(RadialGradient(colors: [.white.opacity(IconTokens.specularOpacity), .clear],
                                         center: .center, startRadius: 1, endRadius: geo.size.width * 0.5))
                    .frame(width: geo.size.width * 0.55, height: geo.size.height * 0.42)
                    .offset(x: -geo.size.width * 0.16, y: -geo.size.height * 0.22)
                    .blur(radius: s * 0.04)
            }
            // 内部品牌辉光
            RadialGradient(colors: [palette.primary.opacity(0.40), .clear],
                           center: .center, startRadius: 1, endRadius: s * 0.6)
                .blur(radius: s * 0.08)
                .opacity(0.7)
        }
    }

    @State private var breathing = false

    public var body: some View {
        shell(size)
            .frame(width: size, height: size)
            .overlay(content.frame(maxWidth: .infinity, maxHeight: .infinity), alignment: .center)
            .rotation3DEffect(.degrees(animate && breathing ? 3.0 : (animate ? -3.0 : 0.0)), axis: (1, 0, 0), anchor: .center, perspective: 0.25)
            .scaleEffect(animate && breathing ? 1.018 : (animate ? 0.985 : 1.0))
            .animation(animate ? .easeInOut(duration: 2.4).repeatForever(autoreverses: true) : .default, value: breathing)
            .onAppear {
                if animate {
                    breathing = true
                }
            }
    }
}

/// 统一的“立体字形”底纹：给任意字形加玻璃高光与品牌渐变填充
public struct Glyph3D: View {
    public let palette: (primary: Color, secondary: Color)
    public let content: () -> AnyView

    public init(palette: (primary: Color, secondary: Color), @ViewBuilder content: @escaping () -> AnyView) {
        self.palette = palette
        self.content = content
    }

    public var body: some View {
        content()
            .overlay(
                LinearGradient(colors: [.white.opacity(0.45), .clear, .black.opacity(0.18)],
                               startPoint: .top, endPoint: .bottom)
                    .blendMode(.overlay)
                    .allowsHitTesting(false)
            )
    }
}

// MARK: - 补齐的图标（之前用系统 SF Symbol 占位的种类）

/// 统一绘制“缺失的反应图标 + 天气变体”，套用 GlassPod 视觉
public struct CuteIcon3D: View {
    public let kind: ReactionAnimationKind
    public let phase: Double

    public init(kind: ReactionAnimationKind, phase: Double = 0) {
        self.kind = kind
        self.phase = phase
    }

    public var body: some View {
        // 天气变体直接复用天气手绘，并套玻璃壳
        if let w = weatherSymbol(for: kind) {
            return AnyView(WeatherCuteIcon(symbolName: w, size: 64)
                .frame(width: 64, height: 64))
        }
        let pal = kind.atollPalette
        return AnyView(
            GlassPod(palette: pal, shape: podShape(for: kind)) {
                AnyView(glyph(for: kind, phase: phase, palette: pal))
            }
            .frame(width: 64, height: 64)
        )
    }

    private func podShape(for k: ReactionAnimationKind) -> GlassPod<AnyView>.PodShape {
        switch k {
        case .siri, .clipboard, .charging, .cloud, .coffee, .bolt, .chart, .mochi:
            return .roundedRect
        default:
            return .roundedRect
        }
    }

    private func weatherSymbol(for k: ReactionAnimationKind) -> String? {
        switch k {
        case .rain: return "cloud.rain.fill"
        case .storm: return "cloud.bolt.rain.fill"
        case .snowflake: return "cloud.snow.fill"
        default: return nil
        }
    }

    @ViewBuilder
    private func glyph(for k: ReactionAnimationKind, phase t: Double, palette pal: (primary: Color, secondary: Color)) -> some View {
        switch k {
        case .siri:
            // 语音光球：脉冲星点 + 声波环
            ZStack {
                ForEach(0..<3) { i in
                    let p = (t * 0.6 + Double(i) * 0.33).truncatingRemainder(dividingBy: 1)
                    Circle().stroke(pal.primary.opacity(1 - p), lineWidth: 2.5)
                        .frame(width: 14 + p * 30, height: 14 + p * 30)
                }
                Circle().fill(RadialGradient(colors: [.white, pal.primary], center: .center, startRadius: 1, endRadius: 12))
                    .frame(width: 18, height: 18)
                    .scaleEffect(1 + 0.15 * sin(t * 3))
            }
        case .clipboard:
            // 剪贴板：板 + 纸 + 勾
            ZStack {
                RoundedRectangle(cornerRadius: 6).fill(pal.secondary.opacity(0.9))
                    .frame(width: 34, height: 42).offset(y: 3)
                RoundedRectangle(cornerRadius: 4).fill(.white.opacity(0.92))
                    .frame(width: 26, height: 32).offset(y: 3)
                Capsule().fill(pal.primary).frame(width: 22, height: 7).offset(y: -16)
                Path { p in
                    p.move(to: CGPoint(x: -6, y: 2)); p.addLine(to: CGPoint(x: -1, y: 7)); p.addLine(to: CGPoint(x: 7, y: -4))
                }.stroke(pal.primary, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            }
        case .charging:
            // 电池 + 闪电（绿）
            ZStack {
                RoundedRectangle(cornerRadius: 5).stroke(pal.primary, lineWidth: 2.5)
                    .frame(width: 38, height: 22)
                RoundedRectangle(cornerRadius: 2).fill(pal.primary).frame(width: 4, height: 8).offset(x: 21)
                RoundedRectangle(cornerRadius: 2).fill(pal.primary.opacity(0.5)).frame(width: 30, height: 14)
                Image.cuteSymbol("bolt.fill").font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white).scaleEffect(1 + 0.1 * sin(t * 4))
            }
        case .cloud:
            // 云朵飘动
            CloudView3D(t: t, palette: pal)
        case .coffee:
            // 咖啡杯 + 热气
            ZStack {
                ForEach(0..<2) { i in
                    let p = (t * 0.5 + Double(i) * 0.5).truncatingRemainder(dividingBy: 1)
                    Capsule().fill(.white.opacity((1 - p) * 0.6)).frame(width: 4, height: 10 + p * 10)
                        .offset(x: CGFloat(i == 0 ? -5 : 6), y: -18 - p * 8)
                }
                RoundedRectangle(cornerRadius: 5).fill(pal.primary)
                    .frame(width: 28, height: 22).offset(y: 6)
                RoundedRectangle(cornerRadius: 3).fill(.white.opacity(0.85)).frame(width: 20, height: 14).offset(y: 6)
                Capsule().stroke(pal.secondary, lineWidth: 2.5).frame(width: 10, height: 10)
                    .offset(x: 18, y: 2)
            }
        case .bolt:
            // 闪电脉冲
            Image.cuteSymbol("bolt.fill").font(.system(size: 30, weight: .bold))
                .foregroundStyle(LinearGradient(colors: [.white, pal.primary], startPoint: .top, endPoint: .bottom))
                .scaleEffect(1 + 0.12 * sin(t * 5))
        case .chart:
            // 柱状图起伏
            HStack(spacing: 5) {
                ForEach(0..<4) { i in
                    let h = 10 + 14 * (0.5 + 0.5 * sin(t * 2 + Double(i)))
                    Capsule().fill(pal.primary).frame(width: 6, height: h)
                }
            }
        case .mochi:
            // 派对团子：弹跳 + 星星
            ZStack {
                Circle().fill(RadialGradient(colors: [.white, pal.primary], center: .center, startRadius: 1, endRadius: 16))
                    .frame(width: 30, height: 30).offset(y: -4 + 3 * abs(sin(t * 2)))
                ForEach(0..<4) { i in
                    let a = t + Double(i) * (.pi / 2)
                    Image.cuteSymbol("star.fill").font(.system(size: 8)).foregroundStyle(pal.secondary)
                        .offset(x: CGFloat(cos(a) * 22), y: CGFloat(sin(a) * 22))
                }
            }
        default:
            Image.cuteSymbol(kind.atollSymbol).font(.system(size: 30)).foregroundStyle(pal.primary)
        }
    }
}

/// 天气云朵 3D 版（带高光）
private struct CloudView3D: View {
    let t: Double
    let palette: (primary: Color, secondary: Color)
    var body: some View {
        let drift = sin(t * 0.8) * 2
        ZStack {
            Capsule().fill(palette.primary.opacity(0.9)).frame(width: 34, height: 14).offset(y: 7 + drift)
            Circle().fill(palette.primary.opacity(0.9)).frame(width: 18, height: 18).offset(x: -9, y: 1 + drift)
            Circle().fill(palette.primary.opacity(0.9)).frame(width: 22, height: 22).offset(x: 1, y: -2 + drift)
            Circle().fill(.white.opacity(0.5)).frame(width: 8, height: 6).offset(x: -6, y: -4 + drift)
        }
    }
}
