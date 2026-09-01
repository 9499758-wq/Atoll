/*
 * Atoll (DynamicIsland)
 * Copyright (C) 2024-2026 Atoll Contributors
 *
 * 大厂风格 3D 动画媒体图标——纯 SwiftUI 手绘，替代系统 SF Symbol。
 * 所有图标均带轻微律动/呼吸动画，配合 FloatingMediaButton 的按压效果。
 */

import SwiftUI

// MARK: - 图标种类
enum MediaIconKind {
    case previousTrack
    case nextTrack
    case play
    case pause
    case seekBackward10
    case seekForward10
}

// MARK: - 通用 3D 玻璃质感修饰
private extension View {
    /// 给图标加一层柔和高光，模拟 3D 玻璃/果冻质感
    func glassy3D(accent: Color = .white) -> some View {
        self
            .overlay(
                LinearGradient(
                    colors: [accent.opacity(0.55), .clear, accent.opacity(0.12)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
}

// MARK: - 播放 / 暂停（核心，带动画）
struct PlayPauseIcon: View {
    let isPlaying: Bool
    var color: Color = .white
    var size: CGFloat = 28

    @State private var phase: CGFloat = 0

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 8.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            Canvas { ctx, _ in
                let s = size
                let cx = s / 2, cy = s / 2
                if isPlaying {
                    // 暂停：两根圆角竖条，带呼吸式亮度
                    let breathe = 0.85 + 0.15 * sin(t * 2.2)
                    let barW = s * 0.16
                    let barH = s * 0.46
                    let gap = s * 0.12
                    for dx in [-gap / 2 - barW / 2, gap / 2 + barW / 2] {
                        var path = Path(roundedRect:
                            CGRect(x: cx + dx - barW / 2, y: cy - barH / 2,
                                   width: barW, height: barH),
                            cornerRadius: barW / 2)
                        ctx.fill(path, with: .color(color.opacity(breathe)))
                        // 顶部高光
                        var hi = Path(roundedRect:
                            CGRect(x: cx + dx - barW / 2, y: cy - barH / 2,
                                   width: barW, height: barH * 0.4),
                            cornerRadius: barW / 2)
                        ctx.fill(hi, with: .color(.white.opacity(0.35 * breathe)))
                    }
                } else {
                    // 播放：三角形，带向外扩张的脉动光环
                    let pulse = (sin(t * 2.0) + 1) / 2 // 0..1
                    let scale = 1 + 0.08 * pulse
                    let tri = Path { p in
                        let w = s * 0.30 * scale
                        let h = s * 0.42 * scale
                        p.move(to: CGPoint(x: cx - w * 0.55, y: cy - h / 2))
                        p.addLine(to: CGPoint(x: cx - w * 0.55, y: cy + h / 2))
                        p.addLine(to: CGPoint(x: cx + w * 0.75, y: cy))
                        p.closeSubpath()
                    }
                    // 光环
                    ctx.stroke(
                        Path(ellipseIn: CGRect(x: cx - s * 0.42, y: cy - s * 0.42,
                                               width: s * 0.84, height: s * 0.84)),
                        with: .color(color.opacity(0.18 * (1 - pulse))),
                        lineWidth: 2
                    )
                    ctx.fill(tri, with: .color(color))
                    // 高光
                    var hi = tri
                    ctx.fill(hi, with: .color(.white.opacity(0.22)))
                }
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - 上一首 / 下一首（带尾迹的箭头）
struct TrackSkipIcon: View {
    let direction: Edge // .leading = 上一首, .trailing = 下一首
    var color: Color = .white
    var size: CGFloat = 24

    @State private var dashPhase: CGFloat = 0

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 8.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let flow = (t * 18).truncatingRemainder(dividingBy: 12)
            Canvas { ctx, _ in
                let s = size
                let cx = s / 2, cy = s / 2
                let sign: CGFloat = direction == .leading ? -1 : 1
                // 主箭头 + 竖条（典型 skip 造型）
                let barX = cx - sign * s * 0.30
                let barW = s * 0.10
                ctx.fill(
                    Path(roundedRect: CGRect(x: barX - barW / 2, y: cy - s * 0.22,
                                             width: barW, height: s * 0.44),
                         cornerRadius: barW / 2),
                    with: .color(color.opacity(0.9))
                )
                // 三角箭头
                let tipX = cx + sign * s * 0.18
                let baseX = cx + sign * s * 0.05
                let tri = Path { p in
                    p.move(to: CGPoint(x: baseX - sign * s * 0.18, y: cy - s * 0.24))
                    p.addLine(to: CGPoint(x: baseX - sign * s * 0.18, y: cy + s * 0.24))
                    p.addLine(to: CGPoint(x: tipX, y: cy))
                    p.closeSubpath()
                }
                ctx.fill(tri, with: .color(color))
                // 流动尾迹小点
                for i in 0..<3 {
                    let off = CGFloat(i) * 4.0 + flow
                    let px = baseX - sign * s * 0.18 - sign * (off + 6)
                    let alpha = max(0, 0.4 - off / 30)
                    if alpha > 0 {
                        ctx.fill(Path(ellipseIn: CGRect(x: px - 1.5, y: cy - 1.5,
                                                        width: 3, height: 3)),
                                 with: .color(color.opacity(alpha)))
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - 快退/快进 10 秒（环形 + 箭头 + 数字感）
struct Seek10Icon: View {
    let direction: Edge
    var color: Color = .white
    var size: CGFloat = 24

    @State private var spin: CGFloat = 0

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 8.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let rot: CGFloat = direction == .leading ? CGFloat(-t * 1.2) : CGFloat(t * 1.2)
            Canvas { ctx, _ in
                let s = size
                let cx = s / 2, cy = s / 2
                let sign: CGFloat = direction == .leading ? -1 : 1
                // 环形弧（带缺口，箭头指示方向）
                var arc = Path()
                let r = s * 0.34
                let start = direction == .leading ? 0.6 : .pi - 0.6
                let end = direction == .leading ? .pi * 2 - 0.6 : .pi + 0.6
                arc.addArc(center: CGPoint(x: cx, y: cy), radius: r,
                           startAngle: .init(radians: Double(start + rot)),
                           endAngle: .init(radians: Double(end + rot)), clockwise: direction == .leading)
                ctx.stroke(arc, with: .color(color.opacity(0.85)),
                           style: StrokeStyle(lineWidth: s * 0.10, lineCap: .round))
                // 箭头头部
                let headAng = Double((direction == .leading ? end : start) + rot)
                let hx = cx + cos(headAng) * r
                let hy = cy + sin(headAng) * r
                let aSize = s * 0.12
                let tri = Path { p in
                    p.move(to: CGPoint(x: hx, y: hy))
                    p.addLine(to: CGPoint(x: hx - sign * aSize, y: hy - aSize * 0.8))
                    p.addLine(to: CGPoint(x: hx - sign * aSize, y: hy + aSize * 0.8))
                    p.closeSubpath()
                }
                ctx.fill(tri, with: .color(color))
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - 统一入口
struct MediaGlyphIcon: View {
    let kind: MediaIconKind
    var color: Color = .white
    var size: CGFloat = 26

    var body: some View {
        switch kind {
        case .play:
            PlayPauseIcon(isPlaying: false, color: color, size: size)
        case .pause:
            PlayPauseIcon(isPlaying: true, color: color, size: size)
        case .previousTrack:
            TrackSkipIcon(direction: .leading, color: color, size: size)
        case .nextTrack:
            TrackSkipIcon(direction: .trailing, color: color, size: size)
        case .seekBackward10:
            Seek10Icon(direction: .leading, color: color, size: size)
        case .seekForward10:
            Seek10Icon(direction: .trailing, color: color, size: size)
        }
    }
}
