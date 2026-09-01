/*
 * Atoll (DynamicIsland)
 * Copyright (C) 2024-2026 Atoll Contributors
 *
 * Originally from boring.notch project
 * Modified and adapted for Atoll (DynamicIsland)
 * See NOTICE for details.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <https://www.gnu.org/licenses/>.
 */

import AVFoundation
import Combine
import Defaults
import Foundation
import KeyboardShortcuts
import SwiftUI
import SwiftUIIntrospect
import AtollExtensionKit
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

@MainActor
private struct AtollBridgeClosedLiveActivity: View {
    let status: AtollBridgeStatus
    var closedNotchWidth: CGFloat = 195

    private var leftWingWidth: CGFloat { 105 }
    private var rightWingWidth: CGFloat { 75 }
    private var cameraGap: CGFloat { max(closedNotchWidth + 24, 210) }
    private var totalWidth: CGFloat { leftWingWidth + cameraGap + rightWingWidth }
    private let height: CGFloat = 34

    /// v3 轮播队列：活跃 agent、全部 agent、通知提醒与实时天气全面参与轮播，每 4.5 秒平滑切换。
    private var rotationEntities: [AtollBridgeEntity] {
        var queue: [AtollBridgeEntity] = []
        // 1. 活跃的 Agent（或已注册 Agent）
        let working = (status.agents ?? []).filter { $0.active == true }
        if !working.isEmpty {
            queue.append(contentsOf: working)
        } else if let agents = status.agents, !agents.isEmpty {
            queue.append(contentsOf: agents)
        }
        // 2. 健康/任务通知提醒 (Notices)
        if let notices = status.notices, !notices.isEmpty {
            queue.append(contentsOf: notices)
        }
        // 3. 实时天气 (Weather)
        if let weather = status.weather {
            queue.append(weather)
        }
        return queue.isEmpty ? [status.legacyEntity] : queue
    }

    @State private var carouselTick: Int = 0

    private var hasPriorityStatus: Bool {
        !(status.notices ?? []).isEmpty || (status.agents ?? []).contains { $0.active == true }
    }

    private var faceEntity: AtollBridgeEntity {
        let queue = rotationEntities
        guard !queue.isEmpty else { return status.legacyEntity }
        return queue[carouselTick % queue.count]
    }
    private var accent: Color { Color(atollHex: faceEntity.accent ?? "#8B5CF6") }
    private var secondary: Color { Color(atollHex: faceEntity.secondary ?? "#06B6D4") }
    private var isWeather: Bool { faceEntity.agent == "Weather" }
    private var isActive: Bool { !isWeather && faceEntity.kind == nil }
    private var isNotice: Bool { faceEntity.kind != nil }
    private var weatherLocationTitle: String {
        let title = faceEntity.title
        let parts = title.split(separator: " ")
        if let first = parts.first, !first.contains("°") && !first.contains("℃") {
            let s = String(first)
            return s.replacingOccurrences(of: "市", with: "").replacingOccurrences(of: "省", with: "")
        }
        return ""
    }

    private var initials: String {
        if isWeather { return "气" }
        if faceEntity.agent == "Hermes" { return "灵" }
        if faceEntity.agent == "Antigravity" { return "AG" }
        return faceEntity.initials ?? "AI"
    }
    private var weatherCondition: String {
        faceEntity.detail
            .split(separator: "·")
            .first
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""
    }

    private var compactTitle: String {
        if isActive { return faceEntity.agent ?? "AI" }
        if isWeather {
            let rawTemp = faceEntity.title.split(separator: " ").last.map(String.init) ?? ""
            let cleaned = rawTemp
                .replacingOccurrences(of: "°C", with: "")
                .replacingOccurrences(of: "℃", with: "")
                .replacingOccurrences(of: ".0", with: "")
            let wholeDegrees = cleaned.split(separator: ".").first.map(String.init) ?? cleaned
            let condition = faceEntity.detail
                .split(separator: "·")
                .first
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""
            let tempText = wholeDegrees.isEmpty ? "" : "\(wholeDegrees)°"
            return tempText + condition
        }
        return faceEntity.title
    }
    private var compactDetail: String {
        if isActive { return "工作中" }
        if isNotice { return faceEntity.detail }   // 提醒卡右翼直接显示详情文案
        let parts = faceEntity.detail.split(separator: "·").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let condition = parts.first ?? "天气"
        let wind = parts.first(where: { $0.contains("风") })
            .map { $0.replacingOccurrences(of: "风", with: "").replacingOccurrences(of: "级", with: "") }
        let humidity = parts.first(where: { $0.contains("湿度") })
            .map { $0.replacingOccurrences(of: "湿度", with: "湿") }
        return [wind, humidity]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// 当前脸面的稳定标识：驱动淡入淡出
    private var faceKey: String { "\(faceEntity.agent ?? "-")|\(faceEntity.title)" }

    /// 进程级轮播时钟：每 4.5 秒平滑切换一次
    private static let tickPublisher = Timer.publish(every: 4.5, on: .main, in: .common).autoconnect()

    var body: some View {
        content
            .id(faceKey)
            .transition(.opacity)
            .animation(.smooth(duration: 0.55), value: faceKey)
            .onReceive(Self.tickPublisher) { _ in
                carouselTick += 1
            }
    }

    private var content: some View {
        HStack(spacing: 0) {
            // 左翼：仅放置萌宠卡通头像 + 极简名称
            HStack(spacing: 6) {
                if isNotice {
                    NoticeMiniScene(symbolName: faceEntity.symbol,
                                    accent: accent, secondary: secondary)
                    AtollShimmeringTitleView(text: compactTitle, accent: accent, secondary: secondary)
                } else if isActive {
                    AgentMiniScene(agent: faceEntity.agent ?? "AI",
                                   initials: faceEntity.initials ?? initials,
                                   appIconPath: faceEntity.appIconPath,
                                   accent: accent,
                                   secondary: secondary)
                    AtollShimmeringTitleView(text: compactTitle, accent: accent, secondary: secondary)
                } else if isWeather {
                    AtollDynamic3DWeatherIcon(
                        condition: weatherCondition,
                        size: 22,
                        accent: accent,
                        secondary: secondary
                    )
                    .frame(width: 24, height: 22)
                    AtollShimmeringTitleView(text: "\(weatherLocationTitle) \(compactTitle)", accent: accent, secondary: secondary)
                } else {
                    CuteAgentRobotBadge(agent: faceEntity.agent ?? "AI",
                                        initials: initials,
                                        appIconPath: faceEntity.appIconPath,
                                        accent: accent,
                                        secondary: secondary)
                    AtollShimmeringTitleView(text: compactTitle, accent: accent, secondary: secondary)
                }
            }
            .frame(width: leftWingWidth, alignment: .leading)

            // 中央绝对避让硬件物理摄像头与刘海
            Spacer(minLength: cameraGap)
                .frame(width: cameraGap)

            // 右翼：活力能量律动条 / 状态
            HStack(spacing: 6) {
                if isActive {
                    HermesCuteWorkingIndicator(accent: accent, secondary: secondary)
                } else {
                    Text(compactDetail)
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(1)
                }
            }
            .frame(width: rightWingWidth, alignment: .trailing)
        }
        .padding(.horizontal, 4)
        .frame(width: totalWidth, height: height)
    }
}

@MainActor
private struct WeatherCuteConditionView: View {
    let text: String
    let condition: String
    let accent: Color
    let secondary: Color

    var body: some View {
        HStack(spacing: 5) {
            AtollDynamic3DWeatherIcon(
                condition: condition,
                size: 20,
                accent: accent,
                secondary: secondary
            )
            Text(text)
                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: 95, alignment: .leading)
    }
}

/// ⛅️ Atoll 3D 原生动态拟态天气系统：
/// 纯矢量 60fps 动态渲染，支持晴、多云、阴、雨、雷雨、雪、夜月、雾霾
@MainActor
struct AtollDynamic3DWeatherIcon: View {
    let condition: String
    var size: CGFloat = 28
    var accent: Color = Color(red: 0.35, green: 0.75, blue: 1.0)
    var secondary: Color = Color(red: 0.95, green: 0.80, blue: 0.30)

    enum WeatherType {
        case sunny, sunCloudy, cloudy, rain, storm, snow, moon, fog
    }

    private var weatherType: WeatherType {
        let c = condition.lowercased()
        if c.contains("雷") || c.contains("暴") { return .storm }
        if c.contains("雪") { return .snow }
        if c.contains("雨") { return .rain }
        if c.contains("雾") || c.contains("霾") { return .fog }
        if c.contains("多云") || c.contains("晴间") { return .sunCloudy }
        if c.contains("阴") { return .cloudy }
        if c.contains("夜") || c.contains("月") { return .moon }
        if c.contains("晴") { return .sunny }
        return .sunCloudy
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let bob = sin(time * 2.2) * 1.0

            ZStack {
                switch weatherType {
                case .sunny:
                    // ☀️ 3D 黄金旋转太阳
                    ZStack {
                        ForEach(0..<8) { i in
                            Capsule()
                                .fill(Color.orange.opacity(0.85))
                                .frame(width: size * 0.10, height: size * 0.25)
                                .offset(y: -size * 0.38)
                                .rotationEffect(.degrees(Double(i) * 45.0 + time * 22.0))
                        }
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 1.0, green: 0.95, blue: 0.4), Color(red: 1.0, green: 0.55, blue: 0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: size * 0.52, height: size * 0.52)
                            .shadow(color: Color.orange.opacity(0.8), radius: 4)
                        Circle()
                            .fill(Color.white.opacity(0.8))
                            .frame(width: size * 0.15, height: size * 0.15)
                            .offset(x: -size * 0.10, y: -size * 0.10)
                    }
                    .offset(y: bob)

                case .sunCloudy:
                    // ⛅️ 3D 晴转多云
                    ZStack {
                        ZStack {
                            ForEach(0..<6) { i in
                                Capsule()
                                    .fill(Color.orange.opacity(0.7))
                                    .frame(width: size * 0.08, height: size * 0.18)
                                    .offset(y: -size * 0.26)
                                    .rotationEffect(.degrees(Double(i) * 60.0 + time * 20.0))
                            }
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(red: 1.0, green: 0.92, blue: 0.35), Color(red: 1.0, green: 0.52, blue: 0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: size * 0.40, height: size * 0.40)
                                .shadow(color: Color.orange.opacity(0.6), radius: 3)
                        }
                        .offset(x: size * 0.20, y: -size * 0.16 + bob * 0.5)

                        Cute3DCloudShape(size: size, isDark: false)
                            .offset(x: -size * 0.05, y: size * 0.10 + bob)
                    }

                case .cloudy:
                    // ☁️ 3D 阴天双层云
                    ZStack {
                        Cute3DCloudShape(size: size * 0.85, isDark: true)
                            .offset(x: -size * 0.12, y: -size * 0.08 + bob * 0.7)
                        Cute3DCloudShape(size: size, isDark: false)
                            .offset(y: size * 0.06 + bob)
                    }

                case .rain:
                    // 🌧 3D 雨天
                    ZStack {
                        Cute3DCloudShape(size: size, isDark: true)
                            .offset(y: -size * 0.10 + bob)

                        ForEach(0..<3) { i in
                            let dropPhase = (time * 1.8 + Double(i) * 0.33).truncatingRemainder(dividingBy: 1.0)
                            Capsule()
                                .fill(LinearGradient(colors: [Color.cyan, Color.blue], startPoint: .top, endPoint: .bottom))
                                .frame(width: size * 0.07, height: size * 0.20)
                                .rotationEffect(.degrees(15))
                                .offset(
                                    x: CGFloat(Double(i) - 1.0) * (size * 0.25) + size * 0.04,
                                    y: size * 0.12 + CGFloat(dropPhase) * (size * 0.35)
                                )
                                .opacity(1.0 - dropPhase * 0.7)
                        }
                    }

                case .storm:
                    // ⛈ 3D 雷雨
                    let flash = (sin(time * 8.0) > 0.55)
                    ZStack {
                        Cute3DCloudShape(size: size, isDark: true)
                            .shadow(color: flash ? Color.yellow.opacity(0.8) : Color.clear, radius: 5)
                            .offset(y: -size * 0.10 + bob)

                        if flash {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: size * 0.40, weight: .bold))
                                .foregroundStyle(LinearGradient(colors: [.white, .yellow, .orange], startPoint: .top, endPoint: .bottom))
                                .shadow(color: .yellow, radius: 4)
                                .offset(x: -size * 0.02, y: size * 0.20)
                        }

                        ForEach(0..<2) { i in
                            let dropPhase = (time * 2.2 + Double(i) * 0.5).truncatingRemainder(dividingBy: 1.0)
                            Capsule()
                                .fill(Color.cyan)
                                .frame(width: size * 0.07, height: size * 0.20)
                                .rotationEffect(.degrees(15))
                                .offset(
                                    x: (CGFloat(i) * 0.5 - 0.25) * size,
                                    y: size * 0.15 + CGFloat(dropPhase) * (size * 0.30)
                                )
                                .opacity(1.0 - dropPhase)
                        }
                    }

                case .snow:
                    // 🌨 3D 雪天
                    ZStack {
                        Cute3DCloudShape(size: size, isDark: false)
                            .offset(y: -size * 0.10 + bob)

                        ForEach(0..<3) { i in
                            let snowPhase = (time * 0.8 + Double(i) * 0.33).truncatingRemainder(dividingBy: 1.0)
                            let sway = sin(time * 2.0 + Double(i) * 1.5) * (size * 0.08)
                            Image(systemName: "snowflake")
                                .font(.system(size: size * 0.18, weight: .bold))
                                .foregroundStyle(Color.white)
                                .rotationEffect(.degrees(time * 45.0 + Double(i) * 60.0))
                                .offset(
                                    x: CGFloat(Double(i) - 1.0) * (size * 0.24) + sway,
                                    y: size * 0.12 + CGFloat(snowPhase) * (size * 0.32)
                                )
                                .opacity(1.0 - snowPhase * 0.6)
                        }
                    }

                case .moon:
                    // 🌙 3D 星月夜
                    ZStack {
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: size * 0.65, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(red: 1.0, green: 0.95, blue: 0.6), Color(red: 0.95, green: 0.75, blue: 0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: Color.yellow.opacity(0.6), radius: 3)
                            .offset(y: bob)
                    }

                case .fog:
                    // 🌫 3D 雾霾
                    VStack(spacing: size * 0.10) {
                        ForEach(0..<3) { i in
                            let sway = sin(time * 1.8 + Double(i) * 1.0) * (size * 0.12)
                            Capsule()
                                .fill(LinearGradient(colors: [Color.white.opacity(0.85), Color(red: 0.75, green: 0.88, blue: 1.0).opacity(0.4)], startPoint: .leading, endPoint: .trailing))
                                .frame(width: size * (0.8 - CGFloat(i) * 0.15), height: size * 0.10)
                                .offset(x: sway)
                        }
                    }
                    .offset(y: bob)
                }
            }
            .frame(width: size, height: size)
        }
    }
}

/// 3D 渐变立体云朵 Shape
@MainActor
private struct Cute3DCloudShape: View {
    let size: CGFloat
    let isDark: Bool

    var body: some View {
        let lightGrad = LinearGradient(
            colors: [Color.white, Color(red: 0.88, green: 0.94, blue: 1.0), Color(red: 0.72, green: 0.85, blue: 0.98)],
            startPoint: .top,
            endPoint: .bottom
        )
        let darkGrad = LinearGradient(
            colors: [Color(red: 0.75, green: 0.82, blue: 0.92), Color(red: 0.45, green: 0.55, blue: 0.70)],
            startPoint: .top,
            endPoint: .bottom
        )

        ZStack {
            Capsule()
                .fill(isDark ? darkGrad : lightGrad)
                .frame(width: size * 0.72, height: size * 0.34)
                .offset(y: size * 0.10)

            Circle()
                .fill(isDark ? darkGrad : lightGrad)
                .frame(width: size * 0.38, height: size * 0.38)
                .offset(x: -size * 0.15, y: size * 0.02)

            Circle()
                .fill(isDark ? darkGrad : lightGrad)
                .frame(width: size * 0.46, height: size * 0.46)
                .offset(x: size * 0.05, y: -size * 0.06)
        }
        .shadow(color: isDark ? Color.black.opacity(0.3) : Color(red: 0.3, green: 0.6, blue: 0.9).opacity(0.25), radius: 2.5, y: 1.5)
    }
}

/// 🌟 60fps 真正流动流水灯效果（Sweeping Liquid Flowing Light）：
/// 光斑沿着英文字符从左向右持续流动扫过，伴随高光流光脉冲与柔和辉光
@MainActor
public struct AtollFlowingLightText: View {
    public let text: String
    public var font: Font = .system(size: 12, weight: .bold, design: .rounded)
    public var baseColor: Color = .white
    public var accent: Color = Color(red: 0.2, green: 0.8, blue: 1.0)
    public var secondary: Color = Color(red: 0.9, green: 0.95, blue: 1.0)
    public var isWorking: Bool = true

    public init(
        text: String,
        font: Font = .system(size: 12, weight: .bold, design: .rounded),
        baseColor: Color = .white,
        accent: Color = Color(red: 0.2, green: 0.8, blue: 1.0),
        secondary: Color = Color(red: 0.9, green: 0.95, blue: 1.0),
        isWorking: Bool = true
    ) {
        self.text = text
        self.font = font
        self.baseColor = baseColor
        self.accent = accent
        self.secondary = secondary
        self.isWorking = isWorking
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let speed = isWorking ? 1.6 : 2.6
            let phase = CGFloat(time.truncatingRemainder(dividingBy: speed) / speed) // 0.0 -> 1.0
            let startX = -1.2 + phase * 2.4
            let endX = startX + 0.9

            Text(text)
                .font(font)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(
                    LinearGradient(
                        stops: [
                            .init(color: baseColor.opacity(0.82), location: 0.0),
                            .init(color: baseColor.opacity(0.82), location: max(0, startX)),
                            .init(color: accent, location: max(0, min(1, startX + 0.2))),
                            .init(color: Color.white, location: max(0, min(1, startX + 0.45))), // 核心极亮流水光斑
                            .init(color: secondary, location: max(0, min(1, startX + 0.7))),
                            .init(color: baseColor.opacity(0.82), location: min(1, endX)),
                            .init(color: baseColor.opacity(0.82), location: 1.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(
                    color: accent.opacity(isWorking ? 0.45 + 0.25 * sin(time * 3.5) : 0.2),
                    radius: isWorking ? 2.5 + 1.0 * sin(time * 3.5) : 1.5,
                    y: 0.5
                )
        }
    }
}

@MainActor
private struct AtollShimmeringTitleView: View {
    let text: String
    let accent: Color
    let secondary: Color

    var body: some View {
        AtollFlowingLightText(
            text: text,
            font: .system(size: 12, weight: .bold, design: .rounded),
            baseColor: .white,
            accent: accent,
            secondary: secondary,
            isWorking: true
        )
    }
}

@MainActor
private struct WeatherMiniScene: View {
    let condition: String
    let accent: Color
    let secondary: Color
    let floating: Bool

    var body: some View {
        ZStack {
            if condition.contains("雨") {
                rainyScene
            } else if condition.contains("雪") {
                snowyScene
            } else if condition.contains("雾") || condition.contains("霾") {
                hazyScene
            } else if condition.contains("阴") {
                cloudyScene
            } else if condition.contains("晴") || condition.contains("多云") {
                sunnyScene
            } else {
                cloudyScene
            }
        }
        .frame(width: 25, height: 22)
    }

    private var sunnyScene: some View {
        ZStack {
            Circle()
                .fill(Color.yellow.opacity(0.95))
                .frame(width: 10, height: 10)
                .offset(x: floating ? -6.5 : -5, y: floating ? -6 : -4)
                .shadow(color: Color.yellow.opacity(0.45), radius: 4)
            cloudBody
                .offset(x: floating ? 1.2 : -0.8, y: floating ? -0.6 : 0.6)
        }
    }

    private var cloudyScene: some View {
        cloudBody
            .offset(x: floating ? 1.8 : -1.2, y: floating ? -0.8 : 0.8)
    }

    private var rainyScene: some View {
        ZStack {
            cloudBody
                .offset(x: floating ? 0.8 : -0.8, y: floating ? -0.3 : 0.3)
            #if canImport(AppKit)
            WeatherPrecipitationLayerView(style: .rain)
                .frame(width: 25, height: 22)
                .offset(y: 1.5)
                .allowsHitTesting(false)
            #endif
        }
    }

    private var snowyScene: some View {
        ZStack {
            cloudBody
                .offset(x: floating ? 0.7 : -0.7, y: floating ? -0.2 : 0.2)
            #if canImport(AppKit)
            WeatherPrecipitationLayerView(style: .snow)
                .frame(width: 25, height: 22)
                .offset(y: 1.5)
                .allowsHitTesting(false)
            #endif
        }
    }

    private var hazyScene: some View {
        ZStack {
            cloudBody.opacity(0.9)
                .offset(x: floating ? 0.8 : -0.4, y: floating ? -0.2 : 0.4)
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(Color.white.opacity(0.28))
                .frame(width: 14, height: 1.6)
                .offset(y: 7)
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(Color.white.opacity(0.18))
                .frame(width: 11, height: 1.2)
                .offset(y: 10)
        }
    }

    private var cloudBody: some View {
        ZStack {
            Capsule(style: .continuous)
                .fill(cloudGradient)
                .frame(width: 21, height: 9)
                .offset(y: 3)
            Circle()
                .fill(cloudGradient)
                .frame(width: 11, height: 11)
                .offset(x: -5, y: 0)
            Circle()
                .fill(cloudGradient)
                .frame(width: 14, height: 14)
                .offset(x: 2, y: -2)
            Circle()
                .fill(cloudGradient)
                .frame(width: 9, height: 9)
                .offset(x: 8, y: 1)
        }
        .shadow(color: secondary.opacity(0.36), radius: 3)
    }

    private var cloudGradient: LinearGradient {
        LinearGradient(
            colors: [Color.white.opacity(0.98), secondary.opacity(0.86), accent.opacity(0.46)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

#if canImport(AppKit)
private struct WeatherPrecipitationLayerView: View {
    enum Style: Equatable {
        case rain
        case snow
    }

    let style: Style
    @State private var animating = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                switch style {
                case .rain:
                    rainDrops(in: proxy.size)
                case .snow:
                    snowFlakes(in: proxy.size)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .onAppear {
                animating = true
            }
        }
    }

    @ViewBuilder
    private func rainDrops(in size: CGSize) -> some View {
        let specs: [(x: CGFloat, length: CGFloat, width: CGFloat, duration: Double, delay: Double)] = [
            (0.16, 5.6, 1.55, 0.75, 0.00),
            (0.31, 7.2, 1.90, 0.85, 0.22),
            (0.48, 5.8, 1.55, 0.70, 0.10),
            (0.64, 7.0, 1.90, 0.90, 0.35),
            (0.79, 5.4, 1.45, 0.80, 0.18),
            (0.90, 6.2, 1.60, 0.78, 0.40)
        ]

        ForEach(specs.indices, id: \.self) { index in
            let spec = specs[index]
            RoundedRectangle(cornerRadius: spec.width, style: .continuous)
                .fill(Color(red: 0.34, green: 0.90, blue: 1.0).opacity(0.85))
                .frame(width: spec.width, height: spec.length)
                .rotationEffect(.degrees(12))
                .shadow(color: Color.cyan.opacity(0.28), radius: 1.5, y: 0.5)
                .offset(
                    x: size.width * spec.x - size.width / 2,
                    y: animating ? (size.height / 2 + 6) : (-size.height / 2 - 4)
                )
                .animation(
                    .linear(duration: spec.duration)
                    .repeatForever(autoreverses: false)
                    .delay(spec.delay),
                    value: animating
                )
        }
    }

    @ViewBuilder
    private func snowFlakes(in size: CGSize) -> some View {
        let specs: [(x: CGFloat, diameter: CGFloat, duration: Double, delay: Double)] = [
            (0.24, 2.5, 1.4, 0.00),
            (0.50, 3.0, 1.6, 0.30),
            (0.74, 2.4, 1.3, 0.15),
            (0.36, 2.2, 1.5, 0.50)
        ]

        ForEach(specs.indices, id: \.self) { index in
            let spec = specs[index]
            Circle()
                .fill(Color.white.opacity(0.88))
                .frame(width: spec.diameter, height: spec.diameter)
                .shadow(color: Color.cyan.opacity(0.16), radius: 1.2)
                .offset(
                    x: size.width * spec.x - size.width / 2,
                    y: animating ? (size.height / 2 + 5) : (-size.height / 2 - 3)
                )
                .animation(
                    .linear(duration: spec.duration)
                    .repeatForever(autoreverses: false)
                    .delay(spec.delay),
                    value: animating
                )
        }
    }
}

#endif

@MainActor
private struct AgentMiniScene: View {
    let agent: String
    let initials: String
    let appIconPath: String?
    let accent: Color
    let secondary: Color

    var body: some View {
        CuteAgentRobotBadge(
            agent: agent,
            initials: initials,
            appIconPath: appIconPath,
            accent: accent,
            secondary: secondary
        )
        .frame(width: 28, height: 24)
    }
}

/// 💧 3D 水晶活力水滴：流光透明渐变 + 内部涟漪波动 + 晶莹高光
@MainActor
struct WaterDrop3DMascot: View {
    var size: CGFloat = 22

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let bob = sin(time * 2.5) * 1.0

            ZStack {
                Circle()
                    .fill(Color(red: 0.2, green: 0.7, blue: 1.0).opacity(0.35 + 0.15 * sin(time * 3.0)))
                    .frame(width: size * 0.88, height: size * 0.88)
                    .blur(radius: 2)

                Image(systemName: "drop.fill")
                    .font(.system(size: size * 0.75, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 0.35, green: 0.85, blue: 1.0), Color(red: 0.08, green: 0.48, blue: 0.98)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Color.blue.opacity(0.6), radius: 2.5)

                Circle()
                    .fill(Color.white.opacity(0.85))
                    .frame(width: size * 0.18, height: size * 0.18)
                    .offset(x: -size * 0.12, y: size * 0.05)
            }
            .offset(y: bob)
        }
    }
}

/// 🏃‍♂️ 3D 动态走动活力萌宠（Walking Vitality Mascot）：
/// 彻底告别生硬线条人，采用 3D 萌系圆润小人 + 60fps 灵动前后迈步摆腿 + 欢快双臂摆动 + 身体韵律弹跳 + 萌系眨眼与活力头带 + 走动扬尘微光粒子
@MainActor
struct StandBreak3DMascot: View {
    var size: CGFloat = 24
    @State private var isBlinking = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let walkSpeed = 6.8
            let walkPhase = time * walkSpeed

            // 1. 身体上下韵律弹跳 (Hop)
            let hop = abs(sin(walkPhase)) * 2.0
            // 2. 左右侧倾微晃动 (Waddle)
            let waddle = sin(walkPhase) * 4.0
            // 3. 手臂与腿部前后摆动幅度
            let legSwing = sin(walkPhase) * 5.0
            let armSwing = cos(walkPhase) * 4.5

            ZStack {
                // 外层运动柔光能量场
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(red: 0.6, green: 0.5, blue: 1.0).opacity(0.35), Color.clear],
                            center: .center,
                            startRadius: 2,
                            endRadius: size * 0.75
                        )
                    )
                    .frame(width: size * 1.2, height: size * 1.2)
                    .offset(y: -hop * 0.5)

                // 脚下走动扬起的小微光气泡/足迹光斑 (Walking Dust Sparkles)
                ForEach(0..<3) { i in
                    let sparkOffset = (walkPhase * 0.4 + Double(i) * 1.2).truncatingRemainder(dividingBy: 2.0)
                    Circle()
                        .fill(Color(red: 0.75, green: 0.65, blue: 1.0).opacity(max(0, 0.7 - sparkOffset * 0.35)))
                        .frame(width: 2.2 - CGFloat(sparkOffset) * 0.5, height: 2.2 - CGFloat(sparkOffset) * 0.5)
                        .offset(
                            x: -6.0 - CGFloat(sparkOffset) * 4.5,
                            y: size * 0.38 + CGFloat(sin(sparkOffset * 3.0)) * 1.0
                        )
                }

                // 2 条 3D 灵动迈步小短腿 (Stepping Feet)
                // 左腿（后腿）
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.55, green: 0.40, blue: 0.95), Color(red: 0.40, green: 0.25, blue: 0.85)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 3.5, height: 6.0)
                    .offset(x: -2.8 - legSwing * 0.6, y: size * 0.30 + legSwing * 0.4 - hop)
                    .rotationEffect(.degrees(-legSwing * 4.0))

                // 右腿（前腿）
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.70, green: 0.55, blue: 1.0), Color(red: 0.50, green: 0.35, blue: 0.95)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 3.5, height: 6.0)
                    .offset(x: 2.8 + legSwing * 0.6, y: size * 0.30 - legSwing * 0.4 - hop)
                    .rotationEffect(.degrees(legSwing * 4.0))

                // 3. 3D 萌萌身体 (Cute Rounded Body)
                ZStack {
                    // 身体球体
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.88, green: 0.78, blue: 1.0), Color(red: 0.62, green: 0.48, blue: 0.98)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: size * 0.68, height: size * 0.68)
                        .shadow(color: Color(red: 0.60, green: 0.40, blue: 0.95).opacity(0.55), radius: 2.5)

                    // 运动活力头带 (Sporty Energy Headband)
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.25, green: 0.95, blue: 0.75), Color(red: 0.15, green: 0.80, blue: 0.95)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: size * 0.64, height: 3.0)
                        .offset(y: -size * 0.18)

                    // 灵动大眼睛 (Blinking Eyes)
                    HStack(spacing: 3.8) {
                        if isBlinking {
                            Capsule().fill(.black).frame(width: 2.8, height: 1.0)
                            Capsule().fill(.black).frame(width: 2.8, height: 1.0)
                        } else {
                            Circle().fill(.black).frame(width: 3.0, height: 3.0)
                                .overlay(alignment: .topTrailing) {
                                    Circle().fill(.white).frame(width: 1.0, height: 1.0).offset(x: -0.3, y: 0.3)
                                }
                            Circle().fill(.black).frame(width: 3.0, height: 3.0)
                                .overlay(alignment: .topTrailing) {
                                    Circle().fill(.white).frame(width: 1.0, height: 1.0).offset(x: -0.3, y: 0.3)
                                }
                        }
                    }
                    .offset(x: 1.0, y: -size * 0.04) // 略微朝向右边行走方向

                    // 俏皮腮红 (Blush)
                    HStack(spacing: 8.5) {
                        Circle().fill(Color.pink.opacity(0.6)).frame(width: 2.2, height: 1.4)
                        Circle().fill(Color.pink.opacity(0.6)).frame(width: 2.2, height: 1.4)
                    }
                    .offset(x: 1.0, y: size * 0.14)
                }
                .offset(y: -hop)
                .rotationEffect(.degrees(waddle))

                // 4. 2 只前后摆动的小手 (Cute Swinging Arms)
                // 左小手（后）
                Circle()
                    .fill(Color(red: 0.65, green: 0.50, blue: 0.95))
                    .frame(width: 4.2, height: 4.2)
                    .offset(x: -size * 0.36 - armSwing * 0.7, y: -hop + armSwing * 0.3)

                // 右小手（前）
                Circle()
                    .fill(Color(red: 0.82, green: 0.70, blue: 1.0))
                    .frame(width: 4.5, height: 4.5)
                    .shadow(color: Color.black.opacity(0.2), radius: 1)
                    .offset(x: size * 0.36 + armSwing * 0.7, y: -hop - armSwing * 0.3)
            }
            .offset(y: -1.0)
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_800_000_000)
                if Task.isCancelled { break }
                isBlinking = true
                try? await Task.sleep(nanoseconds: 150_000_000)
                if Task.isCancelled { break }
                isBlinking = false
            }
        }
    }
}

/// 🍅 3D 番茄钟番茄：鲜艳果实 + 嫩绿叶子 + 旋转活力光圈
@MainActor
struct PomodoroTomato3DMascot: View {
    var size: CGFloat = 22

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let bob = sin(time * 2.2) * 1.0

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 1.0, green: 0.42, blue: 0.38), Color(red: 0.85, green: 0.18, blue: 0.18)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size * 0.68, height: size * 0.68)
                    .shadow(color: Color.red.opacity(0.6), radius: 2.5)

                Circle()
                    .fill(Color.white.opacity(0.75))
                    .frame(width: size * 0.16, height: size * 0.16)
                    .offset(x: -size * 0.12, y: -size * 0.10)

                HStack(spacing: -1) {
                    Circle().fill(Color(red: 0.3, green: 0.85, blue: 0.4)).frame(width: size * 0.20, height: size * 0.14)
                    Circle().fill(Color(red: 0.3, green: 0.85, blue: 0.4)).frame(width: size * 0.20, height: size * 0.14)
                }
                .offset(y: -size * 0.32)
            }
            .offset(y: bob)
        }
    }
}

/// ✴️ Claude 温暖智友星灵：Anthropic 温暖琥珀色 + 3D 旋转星芒光晕 + 晶莹大眼与腮红
@MainActor
struct ClaudeCuteSparkleMascot: View {
    var accent: Color = Color(red: 0.95, green: 0.55, blue: 0.35)
    var secondary: Color = Color(red: 1.0, green: 0.80, blue: 0.50)
    var floating: Bool = false
    @State private var isBlinking = false

    var body: some View {
        let bob: CGFloat = floating ? -2.0 : 0.8

        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            ZStack {
                // 1. 围绕头部的 4 芒暖星光环
                ZStack {
                    ForEach(0..<4) { i in
                        Image(systemName: "sparkle")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(secondary.opacity(0.85))
                            .offset(
                                x: cos(Double(i) * .pi / 2.0 + time * 1.5) * 11.5,
                                y: sin(Double(i) * .pi / 2.0 + time * 1.5) * 7.5
                            )
                            .scaleEffect(0.8 + 0.3 * sin(time * 3.0 + Double(i)))
                    }
                }
                .offset(y: -4.0 + bob)

                // 2. 温暖陶土色头盔/身体
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.98, green: 0.62, blue: 0.42), Color(red: 0.88, green: 0.42, blue: 0.28)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 20, height: 20)
                    .shadow(color: Color(red: 0.95, green: 0.45, blue: 0.25).opacity(0.55), radius: 3)

                // 3. 晶莹高光面罩
                Circle()
                    .stroke(Color.white.opacity(0.35), lineWidth: 0.8)
                    .frame(width: 19, height: 19)

                // 4. 灵动眨眼
                HStack(spacing: 4.5) {
                    if isBlinking {
                        Capsule().fill(.black).frame(width: 3.5, height: 1.2)
                        Capsule().fill(.black).frame(width: 3.5, height: 1.2)
                    } else {
                        Circle().fill(.black).frame(width: 3.6, height: 3.6)
                            .overlay(alignment: .topTrailing) {
                                Circle().fill(.white).frame(width: 1.2, height: 1.2).offset(x: -0.4, y: 0.4)
                            }
                        Circle().fill(.black).frame(width: 3.6, height: 3.6)
                            .overlay(alignment: .topTrailing) {
                                Circle().fill(.white).frame(width: 1.2, height: 1.2).offset(x: -0.4, y: 0.4)
                            }
                    }
                }
                .offset(y: bob - 0.5)

                // 5. 温暖腮红
                HStack(spacing: 10.0) {
                    Circle().fill(Color.orange.opacity(0.6)).frame(width: 2.8, height: 1.8)
                    Circle().fill(Color.orange.opacity(0.6)).frame(width: 2.8, height: 1.8)
                }
                .offset(y: bob + 3.0)
            }
            .offset(y: bob)
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_200_000_000)
                if Task.isCancelled { break }
                isBlinking = true
                try? await Task.sleep(nanoseconds: 160_000_000)
                if Task.isCancelled { break }
                isBlinking = false
            }
        }
    }
}

/// 提醒卡专属小场景：自绘水滴/站立/告警/agent 图形，不再回退到白色 SF Symbol。
@MainActor
struct NoticeMiniScene: View {
    let symbolName: String
    var accent: Color = .white
    var secondary: Color = .cyan

    var body: some View {
        let s = symbolName.lowercased()
        if s.contains("water") || s.contains("drop") || s.contains("drink") {
            WaterDrop3DMascot(size: 22)
        } else if s.contains("stand") || s.contains("walk") || s.contains("move") || s.contains("figure") {
            StandBreak3DMascot(size: 22)
        } else if s.contains("tomato") || s.contains("pomodoro") {
            PomodoroTomato3DMascot(size: 22)
        } else {
            AtollCuteIcon(
                symbolName: symbolName,
                size: 22,
                accent: accent,
                secondary: secondary,
                showsPlate: false,
                animated: true
            )
        }
    }
}

@MainActor
private struct AtollAgentWorkScene: View {
    let agent: String
    let initials: String
    let appIconPath: String?
    let accent: Color
    let secondary: Color

    var body: some View {
        HStack(spacing: 3) {
            CuteAgentRobotBadge(
                agent: agent,
                initials: initials,
                appIconPath: appIconPath,
                accent: accent,
                secondary: secondary
            )
            .frame(width: 30, height: 24)

            CuteThoughtBubbles(accent: accent, secondary: secondary, spread: 21)
                .frame(width: 24, height: 20)
        }
        .frame(width: 58, height: 24)
    }
}

@MainActor
private struct CuteAgentRobotBadge: View {
    var agent: String = "AI"
    let initials: String
    let appIconPath: String?
    let accent: Color
    let secondary: Color
    @State private var floating = false

    var body: some View {
        Group {
            if agent.lowercased().contains("antigravity") {
                AntigravityCuteAstroMascot(accent: accent, secondary: secondary, floating: floating)
            } else if agent.lowercased().contains("codex") {
                CodexCuteRobotMascot(accent: accent, secondary: secondary, floating: floating)
            } else if agent.lowercased().contains("hermes") {
                HermesCuteFoxMascot(accent: accent, secondary: secondary, floating: floating)
            } else if agent.lowercased().contains("claude") {
                ClaudeCuteSparkleMascot(accent: accent, secondary: secondary, floating: floating)
            } else {
                GeneralCuteRobotMascot(initials: initials, accent: accent, secondary: secondary, floating: floating)
            }
        }
        .frame(width: 30, height: 24)
        .shadow(color: Color.black.opacity(0.40), radius: 2, y: 0.8)
        .shadow(color: accent.opacity(0.28), radius: 3)
        .task {
            await AtollMotion.runPulseLoop(
                isEnabled: true,
                initialDelay: 100_000_000,
                interval: 4_200_000_000,
                hold: 350_000_000
            ) { floating = $0 }
        }
    }
}

/// 🪐 Antigravity 专属冥王星/土星 3D 环绕行星星灵：
/// 3D 倾斜行星环（后环在脑后，前环在身前）+ 绕头公转的闪耀行星伴星（环绕一周，穿梭前后）+ 萌系大眼眨眼 + 腮红呼吸失重浮动
@MainActor
struct AntigravityCuteAstroMascot: View {
    let accent: Color
    let secondary: Color
    let floating: Bool
    @State private var isBlinking = false

    var body: some View {
        let bob: CGFloat = floating ? -2.2 : 0.8
        let scale: CGFloat = floating ? 1.05 : 0.98
        let tilt: Double = floating ? 2.5 : -1.5

        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let period = 2.4 // 2.4s per full orbit
            let angle = (time.truncatingRemainder(dividingBy: period) / period) * 2.0 * Double.pi

            // 3D 轨道椭圆参数 (3D Orbit parameters)
            let rx: CGFloat = 14.5
            let ry: CGFloat = 5.2
            let orbitTiltDegrees: Double = -18.0
            let orbitTiltRad = orbitTiltDegrees * .pi / 180.0

            // 伴星星球的 3D 极坐标
            let rawX = rx * cos(angle)
            let rawY = ry * sin(angle)
            let satX = rawX * cos(orbitTiltRad) - rawY * sin(orbitTiltRad)
            let satY = rawX * sin(orbitTiltRad) + rawY * cos(orbitTiltRad)
            let isBehind = sin(angle) < 0 // 处于星球后方

            ZStack {
                // -------------------------------------------------------------
                // 层 1：后半圈行星环与后方公转伴星 (Back Ring & Back Moon - Behind Head)
                // -------------------------------------------------------------
                // 1.1 后半圈光环（被星球遮挡的后半部）
                Ellipse()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 0.85, green: 0.65, blue: 1.0).opacity(0.65),
                                secondary.opacity(0.7),
                                accent.opacity(0.6)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 2.2
                    )
                    .frame(width: rx * 2.0, height: ry * 2.0)
                    .rotationEffect(.degrees(orbitTiltDegrees))
                    .mask(
                        Rectangle()
                            .frame(width: 40, height: 20)
                            .offset(y: -10)
                            .rotationEffect(.degrees(orbitTiltDegrees))
                    )
                    .offset(y: bob)

                // 1.2 后方飞行中的伴星 (When Moon is behind planet)
                if isBehind {
                    Circle()
                        .fill(Color.white.opacity(0.85))
                        .frame(width: 3.0, height: 3.0)
                        .shadow(color: accent.opacity(0.6), radius: 2)
                        .offset(x: satX, y: satY + bob)
                }

                // -------------------------------------------------------------
                // 层 2：中心星球本体 (Central Planet Mascot Head)
                // -------------------------------------------------------------
                ZStack {
                    // 太空宇航头盔外壳 (Glass Helmet)
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
                        .frame(width: 20, height: 20)
                        .shadow(color: accent.opacity(0.65), radius: 3, y: 1)

                    // 晶莹高光反光面
                    Circle()
                        .stroke(Color.white.opacity(0.85), lineWidth: 1.2)
                        .frame(width: 19, height: 19)
                        .mask(
                            LinearGradient(colors: [.white, .clear], startPoint: .topLeading, endPoint: .center)
                        )

                    // 可爱大眼睛与星光
                    HStack(spacing: 4.5) {
                        if isBlinking {
                            Capsule().fill(Color.black.opacity(0.9)).frame(width: 3.8, height: 1.4)
                            Capsule().fill(Color.black.opacity(0.9)).frame(width: 3.8, height: 1.4)
                        } else {
                            ZStack {
                                Circle().fill(Color(red: 0.1, green: 0.05, blue: 0.2)).frame(width: 4.5, height: 5.0)
                                Circle().fill(.white).frame(width: 1.6, height: 1.6).offset(x: -0.7, y: -0.9)
                            }
                            ZStack {
                                Circle().fill(Color(red: 0.1, green: 0.05, blue: 0.2)).frame(width: 4.5, height: 5.0)
                                Circle().fill(.white).frame(width: 1.6, height: 1.6).offset(x: -0.7, y: -0.9)
                            }
                        }
                    }
                    .offset(y: -0.5)

                    // 粉嫩腮红
                    HStack(spacing: 10.5) {
                        Circle().fill(Color.pink.opacity(0.6)).frame(width: 3.2, height: 2.2)
                        Circle().fill(Color.pink.opacity(0.6)).frame(width: 3.2, height: 2.2)
                    }
                    .offset(y: 3.0)
                }
                .offset(y: bob)

                // -------------------------------------------------------------
                // 层 3：前半圈行星环与前方公转伴星 (Front Ring & Front Moon - In Front of Head)
                // -------------------------------------------------------------
                // 3.1 前半圈行星流光环（横跨在星球前部）
                Ellipse()
                    .stroke(
                        LinearGradient(
                            colors: [
                                accent,
                                Color.white.opacity(0.95),
                                secondary,
                                Color(red: 0.95, green: 0.75, blue: 1.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 2.4
                    )
                    .frame(width: rx * 2.0, height: ry * 2.0)
                    .rotationEffect(.degrees(orbitTiltDegrees))
                    .mask(
                        Rectangle()
                            .frame(width: 40, height: 20)
                            .offset(y: 10)
                            .rotationEffect(.degrees(orbitTiltDegrees))
                    )
                    .shadow(color: secondary.opacity(0.9), radius: 3)
                    .offset(y: bob)

                // 3.2 前方飞行中的耀眼伴星 (When Moon is in front of planet)
                if !isBehind {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 4.2, height: 4.2)
                            .shadow(color: .white, radius: 2)
                            .shadow(color: accent, radius: 5)
                        Circle()
                            .fill(secondary)
                            .frame(width: 2.0, height: 2.0)
                    }
                    .offset(x: satX, y: satY + bob)
                }
            }
            .scaleEffect(scale)
            .rotationEffect(.degrees(tilt))
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 3_600_000_000)
                    if Task.isCancelled { break }
                    isBlinking = true
                    try? await Task.sleep(nanoseconds: 160_000_000)
                    if Task.isCancelled { break }
                    isBlinking = false
                }
            }
        }
    }
}

/// 🤖 Codex 薄荷绿小极客机器人：智慧发光天线（一闪一闪信号发射+电波光圈）+ 护目镜大眼眨眼 + 代码能量
@MainActor
struct CodexCuteRobotMascot: View {
    let accent: Color
    let secondary: Color
    let floating: Bool
    @State private var isBlinking = false

    var body: some View {
        let bob: CGFloat = floating ? -1.8 : 0.8
        let scale: CGFloat = floating ? 1.04 : 0.98

        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            // 信号闪烁波 (Pulse phase: 0 to 1 every 1.0s)
            let period: Double = 1.0
            let phase = (time.truncatingRemainder(dividingBy: period) / period)
            let pulseSin = (sin(phase * 2.0 * .pi) + 1.0) / 2.0 // 0..1 smooth curve

            let flashBrightness = pulseSin * 0.7 + 0.3
            let glowRadius: CGFloat = CGFloat(2.0 + pulseSin * 5.0)
            let beaconScale: CGFloat = CGFloat(0.88 + pulseSin * 0.35)

            // 向上扩散的代码信号波纹
            let waveScale: CGFloat = CGFloat(1.0 + phase * 2.2)
            let waveOpacity: Double = (1.0 - phase) * 0.75

            ZStack {
                // 1. 头顶天线与一闪一闪的能量信号球 + 发射光波
                ZStack {
                    // 1.1 扩散出的天线代码能量波纹 (Expanding Signal Ring)
                    Circle()
                        .stroke(Color(red: 0.2, green: 1.0, blue: 0.7).opacity(waveOpacity), lineWidth: 1.2)
                        .frame(width: 6, height: 6)
                        .scaleEffect(waveScale)
                        .offset(y: -13.5 + bob)

                    // 1.2 天线金属立杆
                    Rectangle()
                        .fill(LinearGradient(colors: [Color.white.opacity(0.9), Color.gray], startPoint: .top, endPoint: .bottom))
                        .frame(width: 1.4, height: 4.5)
                        .offset(y: -9.5 + bob)

                    // 1.3 一闪一闪的智慧天线信号小灯泡 (Flashing Neon Bulb)
                    ZStack {
                        // 外部强烈高光晕
                        Circle()
                            .fill(Color(red: 0.1, green: 0.95, blue: 0.6).opacity(flashBrightness))
                            .frame(width: 5.5, height: 5.5)
                            .shadow(color: Color(red: 0.2, green: 1.0, blue: 0.65), radius: glowRadius)

                        // 核心白亮光斑
                        Circle()
                            .fill(Color.white)
                            .frame(width: 2.2, height: 2.2)
                            .opacity(0.85 + pulseSin * 0.15)
                    }
                    .scaleEffect(beaconScale)
                    .offset(y: -13.5 + bob)
                }

                // 2. 机器人圆角头部外壳 (Mint Green Bot Body)
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.25, green: 0.90, blue: 0.70),
                                Color(red: 0.08, green: 0.68, blue: 0.52)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 21, height: 17)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color.white.opacity(0.7), lineWidth: 0.9)
                    )
                    .shadow(color: Color.green.opacity(0.4), radius: 2.5, y: 1)
                    .offset(y: bob)

                // 3. 黑色护目镜面板
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .fill(Color.black.opacity(0.88))
                    .frame(width: 16, height: 8.5)
                    .offset(y: bob + 0.5)

                // 4. 发光大眼睛（伴随高光与眨眼）
                HStack(spacing: 3.8) {
                    if isBlinking {
                        Capsule().fill(Color(red: 0.3, green: 1.0, blue: 0.7)).frame(width: 3.6, height: 1.1)
                        Capsule().fill(Color(red: 0.3, green: 1.0, blue: 0.7)).frame(width: 3.6, height: 1.1)
                    } else {
                        ZStack {
                            Circle().fill(Color(red: 0.3, green: 1.0, blue: 0.7)).frame(width: 3.5, height: 3.5)
                            Circle().fill(Color.white).frame(width: 1.2, height: 1.2).offset(x: -0.6, y: -0.6)
                        }
                        ZStack {
                            Circle().fill(Color(red: 0.3, green: 1.0, blue: 0.7)).frame(width: 3.5, height: 3.5)
                            Circle().fill(Color.white).frame(width: 1.2, height: 1.2).offset(x: -0.6, y: -0.6)
                        }
                    }
                }
                .offset(y: bob + 0.5)
            }
            .scaleEffect(scale)
            .offset(y: bob)
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 3_800_000_000)
                    if Task.isCancelled { break }
                    isBlinking = true
                    try? await Task.sleep(nanoseconds: 160_000_000)
                    if Task.isCancelled { break }
                    isBlinking = false
                }
            }
        }
    }
}

/// 🦊 Hermes 极速天蓝精灵：灵动耳朵 + 闪耀大眼 + 俏皮腮红
@MainActor
struct HermesCuteFoxMascot: View {
    let accent: Color
    let secondary: Color
    let floating: Bool
    @State private var isBlinking = false
    @State private var earTwitch = false

    var body: some View {
        let bob: CGFloat = floating ? -1.8 : 0.8

        ZStack {
            // 精灵耳朵
            HStack(spacing: 11) {
                Path { p in
                    p.move(to: CGPoint(x: 0, y: 0))
                    p.addLine(to: CGPoint(x: 2.5, y: -5))
                    p.addLine(to: CGPoint(x: 5, y: 0))
                }
                .fill(Color.cyan)
                .rotationEffect(.degrees(earTwitch ? -4 : 4))
                Path { p in
                    p.move(to: CGPoint(x: 0, y: 0))
                    p.addLine(to: CGPoint(x: 2.5, y: -5))
                    p.addLine(to: CGPoint(x: 5, y: 0))
                }
                .fill(Color.cyan)
                .rotationEffect(.degrees(earTwitch ? 4 : -4))
            }
            .offset(y: -6.5 + bob)
            .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: earTwitch)

            // 身体与脑袋
            Circle()
                .fill(LinearGradient(colors: [Color(red: 0.25, green: 0.75, blue: 1.0), Color(red: 0.15, green: 0.90, blue: 0.75)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 19, height: 19)
                .shadow(color: Color.cyan.opacity(0.5), radius: 2.5)

            // 大眼睛
            HStack(spacing: 4.5) {
                if isBlinking {
                    Capsule().fill(.black).frame(width: 3.6, height: 1.3)
                    Capsule().fill(.black).frame(width: 3.6, height: 1.3)
                } else {
                    Circle().fill(.black).frame(width: 3.8, height: 3.8)
                    Circle().fill(.black).frame(width: 3.8, height: 3.8)
                }
            }
            .offset(y: bob - 0.5)

            // 腮红
            HStack(spacing: 9.5) {
                Circle().fill(Color.pink.opacity(0.55)).frame(width: 2.8, height: 1.8)
                Circle().fill(Color.pink.opacity(0.55)).frame(width: 2.8, height: 1.8)
            }
            .offset(y: bob + 2.8)
        }
        .offset(y: bob)
        .onAppear {
            earTwitch = true
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_400_000_000)
                if Task.isCancelled { break }
                isBlinking = true
                try? await Task.sleep(nanoseconds: 160_000_000)
                if Task.isCancelled { break }
                isBlinking = false
            }
        }
    }
}

/// 🤖 通用可爱萌物机器人
@MainActor
private struct GeneralCuteRobotMascot: View {
    let initials: String
    let accent: Color
    let secondary: Color
    let floating: Bool

    var body: some View {
        let bob: CGFloat = floating ? -1.5 : 0.8
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(LinearGradient(colors: [accent, secondary], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 20, height: 18)
                .shadow(color: accent.opacity(0.4), radius: 2)
            Text(initials.prefix(2))
                .font(.system(size: 8.5, weight: .black, design: .rounded))
                .foregroundStyle(Color.black.opacity(0.85))
        }
        .offset(y: bob)
    }
}

@MainActor
private struct CuteThoughtBubbles: View {
    let accent: Color
    let secondary: Color
    let spread: CGFloat
    @State private var floating = false

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                let baseSize: CGFloat = [4.2, 6.8, 4.8][index]
                let color = index == 1 ? secondary : accent
                let xOffset = -spread / 2 + CGFloat(index) * (spread / 2)
                let lift = floating ? [0.86, 1.0, 0.72][index] : [0.18, 0.34, 0.08][index]
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [color, Color.white.opacity(0.55)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: baseSize, height: baseSize)
                    .scaleEffect(0.88 + 0.34 * lift)
                    .offset(x: xOffset, y: 2.0 - 5.0 * lift)
                    .opacity(0.42 + 0.48 * lift)
                    .shadow(color: color.opacity(0.25 + 0.14 * lift), radius: 1.4 + 1.0 * lift)
            }
        }
        .task {
            await AtollMotion.runPulseLoop(
                isEnabled: true,
                initialDelay: 1_220_000_000,
                interval: 5_800_000_000,
                hold: 300_000_000
            ) { floating = $0 }
        }
    }
}

@MainActor
private struct CuteLaptopWorkIndicator: View {
    let accent: Color
    let secondary: Color

    private static let laptopImage = AtollCuteIconAssets.image(named: "laptop")
    @State private var floating = false

    var body: some View {
        HStack(spacing: 3) {
            ZStack {
                if let laptop = Self.laptopImage {
                    Image(nsImage: laptop)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .scaleEffect(floating ? 1.04 : 0.985)
                        .offset(y: floating ? -0.9 : 0.55)
                } else {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(LinearGradient(colors: [accent, secondary], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 18, height: 13)
                        .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.white.opacity(0.3), lineWidth: 1))
                        .scaleEffect(floating ? 1.04 : 0.985)
                        .offset(y: floating ? -0.9 : 0.55)
                }
            }
            .frame(width: 23, height: 20)

            CuteThoughtBubbles(accent: accent, secondary: secondary, spread: 24)
                .frame(width: 28, height: 18)
        }
        .frame(width: 58, height: 20)
        .shadow(color: secondary.opacity(0.28), radius: 3)
        .task {
            await AtollMotion.runPulseLoop(
                isEnabled: true,
                initialDelay: 1_650_000_000,
                interval: 5_400_000_000,
                hold: 320_000_000
            ) { floating = $0 }
        }
    }
}

@MainActor
private struct MiniWorkRail: View {
    let accent: Color
    let secondary: Color
    let phase: Double

    var body: some View {
        CuteThoughtBubbles(accent: accent, secondary: secondary, spread: 24)
    }
}

private enum AtollNoticeGlyphKind {
    case water
    case stand
    case move
    case weather
    case agent
    case alert
    case generic

    init(symbolName: String) {
        let s = symbolName.lowercased()
        if s.contains("drop") || s.contains("water") || s.contains("cup") || s.contains("drink") {
            self = .water
        } else if s.contains("walk") || s.contains("run") || s.contains("move") || s.contains("sport") || s.contains("exercise") {
            self = .move
        } else if s.contains("figure") || s.contains("stand") || s.contains("person") {
            self = .stand
        }
        else if s.contains("cloud") || s.contains("sun") || s.contains("rain") || s.contains("bolt") { self = .weather }
        else if s.contains("wand") || s.contains("curly") || s.contains("terminal") || s.contains("cpu") { self = .agent }
        else if s.contains("exclamation") || s.contains("bell") { self = .alert }
        else { self = .generic }
    }

    var symbolName: String {
        switch self {
        case .water: return "drop.fill"
        case .stand: return "figure.stand"
        case .move: return "figure.walk"
        case .weather: return "cloud.rain.fill"
        case .agent: return "terminal.fill"
        case .alert: return "bell.fill"
        case .generic: return "sparkles"
        }
    }

    var displaySize: CGFloat {
        switch self {
        case .water, .stand, .move: return 27
        default: return 24
        }
    }

    var assetScale: CGFloat {
        switch self {
        case .water, .stand, .move: return 1.02
        default: return 0.92
        }
    }
}

@MainActor
private struct AtollNoticeGlyph: View {
    let kind: AtollNoticeGlyphKind
    let accent: Color
    let secondary: Color

    var body: some View {
        AtollCuteIcon(symbolName: kind.symbolName,
                      size: kind.displaySize,
                      accent: accent,
                      secondary: secondary,
                      showsPlate: false,
                      animated: true,
                      weight: .black,
                      assetScale: kind.assetScale)
        .frame(width: 24, height: 24)
        .shadow(color: Color.black.opacity(0.42), radius: 1.8, y: 0.6)
        .shadow(color: accent.opacity(0.24), radius: 2.2)
    }
}

/// Closed-notch Hermes face: the same mochi cat mascot used by the expanded
/// bridge card, running in place at a low idle rate and tinted with the Hermes brand
/// gradient (cyan→green) so the notch instantly reads as "Hermes at work".
@MainActor
private struct HermesMochiAvatar: View {
    let accent: Color
    let secondary: Color
    @State private var breathing = false

    private static let frames: [NSImage] = {
        var images: [NSImage] = []
        for i in 0..<5 {
            if let url = Bundle.main.url(forResource: "mochi-frame-\(i)", withExtension: "png", subdirectory: "MochiFrames"),
               let img = NSImage(contentsOf: url) {
                img.isTemplate = true
                images.append(img)
            }
        }
        return images
    }()

    var body: some View {
        Group {
            if Self.frames.isEmpty {
                AtollCuteIcon(
                    symbolName: "terminal.fill",
                    size: 24,
                    accent: accent,
                    secondary: secondary,
                    showsPlate: false,
                    animated: true
                )
            } else {
                Image(nsImage: Self.frames[min(4, Self.frames.count - 1)])
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(
                        LinearGradient(
                            colors: [accent, secondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(breathing ? 1.045 : 0.965)
                    .offset(y: breathing ? -0.8 : 0.45)
                    .shadow(color: accent.opacity(breathing ? 0.48 : 0.28), radius: breathing ? 3.2 : 2.2)
            }
        }
        .frame(width: 24, height: 24)
        .task {
            await AtollMotion.runPulseLoop(
                isEnabled: true,
                initialDelay: 860_000_000,
                interval: 5_400_000_000,
                hold: 320_000_000
            ) { breathing = $0 }
        }
    }
}

@MainActor
private struct HermesThinkingAvatar: View {
    let accent: Color
    let secondary: Color
    @State private var thinking = false

    var body: some View {
        HStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.95), secondary.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 22, height: 22)
                    .shadow(color: accent.opacity(0.45), radius: 4)
                HStack(spacing: 3) {
                    Circle().fill(.black.opacity(0.72)).frame(width: 3.2, height: 3.2)
                    Circle().fill(.black.opacity(0.72)).frame(width: 3.2, height: 3.2)
                }
                .offset(y: thinking ? 0.8 : -0.2)
            }
            ZStack(alignment: .bottomLeading) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(index == 2 ? secondary : Color.white.opacity(0.9))
                        .frame(width: [4.0, 5.8, 8.0][index], height: [4.0, 5.8, 8.0][index])
                        .offset(
                            x: [0.0, 8.0, 17.0][index],
                            y: thinking ? [-1.0, -5.0, -9.0][index] : [0.8, -3.0, -7.0][index]
                        )
                        .opacity(thinking ? [0.45, 0.72, 1.0][index] : [1.0, 0.72, 0.45][index])
                }
            }
            .frame(width: 30, height: 22)
        }
        .frame(width: 58, height: 24)
        .task {
            await AtollMotion.runPulseLoop(
                isEnabled: true,
                initialDelay: 1_360_000_000,
                interval: 5_600_000_000,
                hold: 300_000_000
            ) { thinking = $0 }
        }
    }
}

@MainActor
private struct HermesCuteWorkingIndicator: View {
    let accent: Color
    let secondary: Color

    var body: some View {
        AtollCuteEnergyBars(accent: accent, secondary: secondary)
            .frame(width: 36, height: 16)
    }
}

/// 🌟 活力能量跳动波形条：4 根 Q 弹圆润能量柱，随时间律动跳跃
@MainActor
private struct AtollCuteEnergyBars: View {
    let accent: Color
    let secondary: Color
    @State private var animating = false

    var body: some View {
        HStack(spacing: 3.0) {
            bar(index: 0, low: 4.0, high: 13.0, duration: 0.42)
            bar(index: 1, low: 11.0, high: 5.0, duration: 0.36)
            bar(index: 2, low: 5.0, high: 14.0, duration: 0.48)
            bar(index: 3, low: 10.0, high: 4.5, duration: 0.38)
        }
        .onAppear {
            animating = true
        }
    }

    private func bar(index: Int, low: CGFloat, high: CGFloat, duration: Double) -> some View {
        Capsule(style: .continuous)
            .fill(
                LinearGradient(
                    colors: [accent, secondary],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .frame(width: 3.0, height: animating ? high : low)
            .shadow(color: accent.opacity(0.35), radius: 1.2)
            .animation(
                .easeInOut(duration: duration)
                .repeatForever(autoreverses: true)
                .delay(Double(index) * 0.08),
                value: animating
            )
    }
}

@MainActor
struct ContentView: View {
    @EnvironmentObject var vm: DynamicIslandViewModel
    @EnvironmentObject var webcamManager: WebcamManager

    @ObservedObject var coordinator = DynamicIslandViewCoordinator.shared
    @ObservedObject var musicManager = MusicManager.shared
    @ObservedObject var timerManager = TimerManager.shared
    @ObservedObject var reminderManager = ReminderLiveActivityManager.shared
    @ObservedObject var batteryModel = BatteryStatusViewModel.shared
    @ObservedObject var statsManager = StatsManager.shared
    @ObservedObject var recordingManager = ScreenRecordingManager.shared
    @ObservedObject var privacyManager = PrivacyIndicatorManager.shared
    @ObservedObject var doNotDisturbManager = DoNotDisturbManager.shared
    @ObservedObject var lockScreenManager = LockScreenManager.shared
    @ObservedObject var capsLockManager = CapsLockManager.shared
    @ObservedObject var extensionLiveActivityManager = ExtensionLiveActivityManager.shared
    @ObservedObject var extensionNotchExperienceManager = ExtensionNotchExperienceManager.shared
    @ObservedObject var localSendService = LocalSendService.shared
    @ObservedObject var reactionPlayer = ReactionAnimationPlayer.shared
    @State private var downloadManager = DownloadManager.shared
    @ObservedObject var shelfState = ShelfStateViewModel.shared
    @State private var bridgeClosedStatus = AtollBridgeStatus.load()
    private let bridgeClosedStatusRefresh = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    private var bridgeClosedHasPriorityStatus: Bool {
        !(bridgeClosedStatus.notices ?? []).isEmpty
            || (bridgeClosedStatus.agents ?? []).contains { $0.active == true }
    }
    
    @Default(.enableStatsFeature) var enableStatsFeature
    @Default(.showCpuGraph) var showCpuGraph
    @Default(.showMemoryGraph) var showMemoryGraph
    @Default(.showGpuGraph) var showGpuGraph
    @Default(.showNetworkGraph) var showNetworkGraph
    @Default(.showDiskGraph) var showDiskGraph
    @Default(.enableReminderLiveActivity) var enableReminderLiveActivity
    @Default(.enableTimerFeature) var enableTimerFeature
    @Default(.timerDisplayMode) var timerDisplayMode
    @Default(.enableHorizontalMusicGestures) var enableHorizontalMusicGestures
    @Default(.reminderPresentationStyle) var reminderPresentationStyle
    @Default(.timerShowsCountdown) var timerShowsCountdown
    @Default(.timerShowsProgress) var timerShowsProgress
    @Default(.timerProgressStyle) var timerProgressStyle
    @Default(.timerIconColorMode) var timerIconColorMode
    @Default(.timerSolidColor) var timerSolidColor
    @Default(.timerPresets) var timerPresets
    @Default(.showCapsLockLabel) var showCapsLockLabel
    @Default(.capsLockIndicatorTintMode) var capsLockTintMode
    @Default(.enableDoNotDisturbDetection) var enableDoNotDisturbDetection
    @Default(.showDoNotDisturbIndicator) var showDoNotDisturbIndicator
    @Default(.enableScreenRecordingDetection) var enableScreenRecordingDetection
    @Default(.enableCapsLockIndicator) var enableCapsLockIndicator
    @Default(.enableExtensionLiveActivities) var enableExtensionLiveActivities
    @Default(.showStandardMediaControls) var showStandardMediaControls
    @Default(.externalDisplayStyle) var externalDisplayStyle
    @Default(.hideNonNotchUntilHover) var hideNonNotchUntilHover
    @Default(.terminalStickyMode) var terminalStickyMode
    
    // Battery settings reactivity
    @Default(.showPowerStatusNotifications) var showPowerStatusNotifications
    @Default(.showChargingBatteryHUD) var showChargingBatteryHUD
    @Default(.showLowBatteryHUD) var showLowBatteryHUD
    @Default(.showFullBatteryHUD) var showFullBatteryHUD
    @Default(.showOnAllDisplays) var showOnAllDisplays
    @Default(.lowBatteryHUDStyle) var lowBatteryHUDStyle
    @Default(.fullBatteryHUDStyle) var fullBatteryHUDStyle
    
    // Dynamic sizing based on view type and graph count with smooth transitions
    var dynamicNotchSize: CGSize {
        let baseSize = Defaults[.enableMinimalisticUI] ? minimalisticOpenNotchSize(isDynamicIslandMode: isDynamicIslandMode) : openNotchSize
        func withReactionSurface(_ size: CGSize) -> CGSize {
            guard let surface = reactionPlayer.activeSurfaceSize else { return size }
            return CGSize(width: max(size.width, surface.width), height: max(size.height, surface.height))
        }
        
        // When inline sneak peek is active in closed notch, use the wider inline width
        // so the outer maxWidth frame doesn't clip the expanded content
        let airPodsListeningModeSneakActive = vm.notchState == .closed
            && coordinator.sneakPeek.show
            && coordinator.sneakPeek.type == .bluetoothAudio
            && coordinator.sneakPeek.value < 0
            && AirPodsListeningMode.fromHUDSymbol(coordinator.sneakPeek.icon) != nil
        let inlineSneakPeekActive = vm.notchState == .closed
            && (
                coordinator.expandingView.show
                    && (coordinator.expandingView.type == .music || coordinator.expandingView.type == .timer)
                    && Defaults[.sneakPeekStyles] == .inline
                || airPodsListeningModeSneakActive
            )
            && Defaults[.enableSneakPeek]
        if inlineSneakPeekActive {
            let inlineWidth: CGFloat = airPodsListeningModeSneakActive
                ? InlineHUD.airPodsListeningModeWidth(
                    closedNotchWidth: vm.closedNotchSize.width,
                    gestureProgress: gestureProgress,
                    minimalistic: Defaults[.enableMinimalisticUI]
                ) + notchHorizontalPadding * 2
                : 460
            return withReactionSurface(CGSize(width: max(baseSize.width, inlineWidth), height: baseSize.height))
        }
        
        // Handle battery HUD expansion sizing
        if vm.notchState == .closed && 
           coordinator.expandingView.show && 
           coordinator.expandingView.type == .battery &&
           isBatteryHUDVisibleOnCurrentScreen {
            
            if let kind = batteryModel.activeTemporaryHUDKind {
                let style: BatteryNotificationStyle = {
                    switch kind {
                    case .charging: return .compact
                    case .lowBattery: return Defaults[.lowBatteryHUDStyle]
                    case .fullBattery: return Defaults[.fullBatteryHUDStyle]
                    }
                }()
                
                var width = vm.closedNotchSize.width
                var height = vm.effectiveClosedNotchHeight
                
                switch (kind, style) {
                case (.charging, _), (.lowBattery, .compact), (.fullBattery, .compact):
                    width += 180
                case (.lowBattery, .standard):
                    width += 100
                    height += 75
                case (.fullBattery, .standard):
                    width += 80
                    height += 70
                }
                
                return withReactionSurface(CGSize(width: width, height: height))
            }
        }
        
        if coordinator.currentView == .timer {
            return withReactionSurface(CGSize(width: baseSize.width, height: 250)) // Extra height for timer presets
        }

        if vm.notchState == .closed,
           !Defaults[.enableMinimalisticUI],
           !(MusicManager.shared.hasActiveSession && !MusicManager.shared.isPlayerIdle),
           !Defaults[.showCalendar],
           !(Defaults[.showMirror] && WebcamManager.shared.cameraAvailable) {
            let safeNotchW = max(vm.closedNotchSize.width, 185)
            return withReactionSurface(CGSize(width: max(460, safeNotchW + 260), height: 40))
        }
        
        if coordinator.currentView == .notes {
            let preferredHeight = coordinator.notesLayoutState.preferredHeight
            let resolvedHeight = max(baseSize.height, preferredHeight)
            return withReactionSurface(CGSize(width: baseSize.width, height: resolvedHeight))
        }

        if coordinator.currentView == .clipboard {
            // Clipboard has its own fixed height source; don't inherit whatever notes
            // layout state happens to be set.
            let resolvedHeight = max(baseSize.height, NotesLayoutState.list.preferredHeight)
            return withReactionSurface(CGSize(width: baseSize.width, height: resolvedHeight))
        }

        if coordinator.currentView == .terminal {
            // Dynamic height: up to terminalMaxHeightFraction of screen, min 300pt
            let screenHeight = NSScreen.main?.visibleFrame.height ?? 800
            let maxFraction = Defaults[.terminalMaxHeightFraction]
            let terminalHeight = min(screenHeight * maxFraction, max(300, screenHeight * maxFraction))
            return withReactionSurface(CGSize(width: baseSize.width, height: terminalHeight))
        }

        if coordinator.currentView == .extensionExperience {
            if let preferredHeight = extensionTabPreferredHeight(baseSize: baseSize) {
                return withReactionSurface(CGSize(width: baseSize.width, height: preferredHeight))
            }
            return withReactionSurface(baseSize)
        }

        if enableMinimalisticUI,
           coordinator.currentView == .home,
           let preferredHeight = extensionMinimalisticPreferredHeight(baseSize: baseSize) {
            return withReactionSurface(CGSize(width: baseSize.width, height: preferredHeight))
        }
        
        guard coordinator.currentView == .stats else {
            return withReactionSurface(baseSize)
        }
        
        let rows = statsRowCount()
        if rows <= 1 {
            return withReactionSurface(baseSize)
        }
        
        let additionalRows = max(rows - 1, 0)
        let extraHeight = CGFloat(additionalRows) * statsAdditionalRowHeight
        return withReactionSurface(CGSize(width: baseSize.width, height: baseSize.height + extraHeight))
    }
    

    @State private var hoverTask: Task<Void, Never>?
    @State private var isHovering: Bool = false
    @State private var lastHapticTime: Date = Date()
    @State private var hoverClickMonitor: Any?
    @State private var hoverClickLocalMonitor: Any?
    @State private var stickyTerminalClickMonitor: Any?
    @State private var hiddenEdgeHoverPollingTask: Task<Void, Never>?
    @State private var isHoveringClosedMusicWaveformControl: Bool = false

    @State private var gestureProgress: CGFloat = .zero
    @State private var skipGestureActiveDirection: MusicManager.SkipDirection?
    @State private var isMusicControlWindowVisible = false
    @State private var pendingMusicControlTask: Task<Void, Never>?
    @State private var musicControlHideTask: Task<Void, Never>?
    @State private var musicControlVisibilityDeadline: Date?
    @State private var isMusicControlWindowSuppressed = false
    @State private var hasPendingMusicControlSync = false
    @State private var pendingMusicControlForceRefresh = false
    @State private var musicControlSuppressionTask: Task<Void, Never>?

    @State private var haptics: Bool = false

    @Namespace var albumArtNamespace

    @Default(.useMusicVisualizer) var useMusicVisualizer
    @Default(.musicControlWindowEnabled) var musicControlWindowEnabled
    @Default(.showNotHumanFace) var showNotHumanFace
    @Default(.useModernCloseAnimation) var useModernCloseAnimation
    @Default(.enableMinimalisticUI) var enableMinimalisticUI

    private static let musicControlLogFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    private func logMusicControlEvent(_ message: String) {
#if DEBUG
        let timestamp = Self.musicControlLogFormatter.string(from: Date())
        print("[MusicControl] \(timestamp): \(message)")
#endif
    }

    private func runAfter(_ delay: TimeInterval, _ action: @escaping @Sendable @MainActor () -> Void) {
        guard delay >= 0 else { return }
        Task { @MainActor in
            let nanoseconds = UInt64(delay * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            action()
        }
    }

    private func requestMusicControlWindowSyncIfHidden(forceRefresh: Bool = false, delay: TimeInterval = 0) {
        guard !isMusicControlWindowVisible else { return }
        enqueueMusicControlWindowSync(forceRefresh: forceRefresh, delay: delay)
    }
    private var dynamicNotchResizeAnimation: Animation? {
        nil
    }
    
    private let zeroHeightHoverPadding: CGFloat = 10
    private let statsAdditionalRowHeight: CGFloat = statsSecondRowContentHeight + statsGridSpacingHeight
    private let musicControlPauseGrace: TimeInterval = 5
    private let musicControlResumeDelay: TimeInterval = 0.24

    // MARK: - Tab switch direction for smooth transitions
    
    private var tabSwitchTransition: AnyTransition {
        if coordinator.tabSwitchForward {
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        } else {
            return .asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            )
        }
    }
    
    private var standardMediaControlsActive: Bool {
        showStandardMediaControls && !enableMinimalisticUI
    }

    private var closedMusicContentEnabled: Bool {
        enableMinimalisticUI || showStandardMediaControls
    }

    private var isMusicHUDDeferredAfterUnlock: Bool {
        lockScreenManager.shouldDelayPostUnlockMusicHUD
    }

    private var interactionsEnabled: Bool {
        !lockScreenManager.isLocked
    }

    private var isIslandMode: Bool {
        isDynamicIslandMode
    }

    private var notchHorizontalPadding: CGFloat {
        guard vm.notchState == .open else {
            return activeCornerRadiusInsets.closed.bottom
        }
        if Defaults[.cornerRadiusScaling] {
            return activeCornerRadiusInsets.opened.top - 5
        }
        return activeCornerRadiusInsets.opened.bottom - 5
    }

    private var bodyHoverAreaPadding: CGFloat {
        if vm.notchState == .open && Defaults[.extendHoverArea] {
            return 0
        }
        return vm.effectiveClosedNotchHeight == 0 ? zeroHeightHoverPadding : 0
    }

    private var notchBottomPadding: CGFloat {
        currentShadowPadding + bodyHoverAreaPadding
    }

    private var pillTopOffset: CGFloat {
        isIslandMode ? dynamicIslandTopOffset : 0
    }

    private func closedMusicPairingEligible(hasActiveMusicSnapshot: Bool) -> Bool {
        vm.notchState == .closed
            && hasActiveMusicSnapshot
            && !vm.hideOnClosed
            && !lockScreenManager.isLocked
            && !isMusicHUDDeferredAfterUnlock
    }

    private var closedLiveActivitySwapTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity
                .combined(with: .scale(scale: 0.965, anchor: .center))
                .animation(.spring(response: 0.34, dampingFraction: 0.88)),
            removal: .opacity
                .combined(with: .scale(scale: 0.92, anchor: .center))
                .animation(.smooth(duration: 0.22))
        )
    }
    
    // Use minimalistic corner radius ONLY when opened, keep normal when closed
    private var activeCornerRadiusInsets: (opened: (top: CGFloat, bottom: CGFloat), closed: (top: CGFloat, bottom: CGFloat)) {
        if enableMinimalisticUI {
            // Keep normal closed corner radius, use minimalistic when opened
            return (opened: minimalisticCornerRadiusInsets.opened, closed: cornerRadiusInsets.closed)
        }
        return cornerRadiusInsets
    }
    
    private var currentShadowPadding: CGFloat {
        notchShadowPaddingValue(isMinimalistic: enableMinimalisticUI)
    }

    private var currentNotchShape: NotchShape {
        let topRadius = (vm.notchState == .open && Defaults[.cornerRadiusScaling])
            ? activeCornerRadiusInsets.opened.top
            : activeCornerRadiusInsets.closed.top
        let bottomRadius = (vm.notchState == .open && Defaults[.cornerRadiusScaling])
            ? activeCornerRadiusInsets.opened.bottom
            : activeCornerRadiusInsets.closed.bottom
        return NotchShape(topCornerRadius: topRadius, bottomCornerRadius: bottomRadius)
    }

    /// Whether the current screen should render as a Dynamic Island pill
    /// rather than the standard notch shape. Always false on physical notch screens.
    private var isDynamicIslandMode: Bool {
        shouldUseDynamicIslandMode(for: currentScreenName)
    }

    private var currentScreenName: String {
        vm.screen ?? coordinator.selectedScreen
    }

    private var currentScreen: NSScreen? {
        NSScreen.screens.first(where: { $0.localizedName == currentScreenName }) ?? NSScreen.main
    }

    /// `screencapture` cannot show the physical camera cutout. Use AppKit's
    /// safe area instead so transient reactions clear the real MacBook notch.
    private var physicalNotchSafeTop: CGFloat {
        guard let currentScreen else { return 0 }
        guard currentScreen.safeAreaInsets.top > 0 else { return 0 }
        return currentScreen.safeAreaInsets.top
    }

    /// Whether the current screen lacks a physical notch.
    private var isNonNotchScreen: Bool {
        guard let screen = currentScreen else {
            return true
        }
        return screen.safeAreaInsets.top <= 0
    }

    /// Whether the global sneak peek is visible on this specific screen.
    private var isSneakPeekVisibleOnCurrentScreen: Bool {
        guard coordinator.sneakPeek.show else { return false }
        guard Defaults[.showOnAllDisplays] else { return true }
        guard let targetScreenName = coordinator.sneakPeek.targetScreenName else { return true }
        return currentScreenName == targetScreenName
    }

    /// Whether the notch/island should hide off-screen when closed on a non-notch display.
    /// Temporarily reveals the notch when a sneakPeek HUD (volume, brightness, music, etc.) is active.
    private var shouldHideUntilHover: Bool {
        hideNonNotchUntilHover && isNonNotchScreen && vm.notchState == .closed && !isSneakPeekVisibleOnCurrentScreen
    }

    /// Whether the fallback top-edge hover detector should run.
    /// This is only needed when the notch is fully hidden off-screen and
    /// regular `.onHover` hit-testing may not trigger reliably.
    private var shouldUseHiddenEdgeHoverPolling: Bool {
        shouldHideUntilHover && !lockScreenManager.isLocked
    }
    
    /// Whether the LocalSend live activity should be shown
    private var localSendLiveActivityActive: Bool {
        localSendService.isSending || 
        localSendService.transferState == .completed ||
        isLocalSendFailedOrRejected
    }
    
    private var isLocalSendFailedOrRejected: Bool {
        if case .failed = localSendService.transferState { return true }
        if case .rejected = localSendService.transferState { return true }
        return false
    }

    /// Pill shape for Dynamic Island mode with animated corner radius transitions.
    private var currentPillShape: DynamicIslandPillShape {
        let radius: CGFloat
        if vm.notchState == .open {
            radius = enableMinimalisticUI
                ? minimalisticCornerRadiusInsets.opened.top
                : dynamicIslandPillCornerRadiusInsets.opened
        } else {
            // Use half the closed height for a true capsule shape
            radius = max(vm.closedNotchSize.height / 2, dynamicIslandPillCornerRadiusInsets.closed.standard)
        }
        return DynamicIslandPillShape(cornerRadius: radius)
    }

    private var isBatteryHUDVisibleOnCurrentScreen: Bool {
        guard coordinator.expandingView.show, coordinator.expandingView.type == .battery else { return false }
        guard showPowerStatusNotifications else { return false }
        guard batteryModel.activeTemporaryHUDKind != nil else { return false }
        if showOnAllDisplays { return true }
        guard let targetScreenName = batteryModel.activeTemporaryHUDTargetScreenName else { return true }
        return currentScreenName == targetScreenName
    }

    private var isCurrentScreenExpansionVisible: Bool {
        guard coordinator.expandingView.show else { return false }
        if coordinator.expandingView.type == .battery {
            return isBatteryHUDVisibleOnCurrentScreen
        }
        return true
    }

    private var currentScreenExpansionType: SneakContentType? {
        isCurrentScreenExpansionVisible ? coordinator.expandingView.type : nil
    }

    private var displayedBatteryHUDLevel: Int {
        let resolvedLevel = batteryModel.activeTemporaryHUDLevelOverride
            ?? Int(batteryModel.levelBattery.rounded())
        return min(max(resolvedLevel, 0), 100)
    }

    private var displayedBatteryHUDUsesLowPowerMode: Bool {
        batteryModel.activeTemporaryHUDLowPowerModeOverride ?? batteryModel.isInLowPowerMode
    }


    private var activeClosedBatterySurfaceShape: AnyShape? {
        guard vm.notchState == .closed else { return nil }
        guard isBatteryHUDVisibleOnCurrentScreen else { return nil }
        guard let kind = batteryModel.activeTemporaryHUDKind else { return nil }

        if isDynamicIslandMode {
            let radius = dynamicIslandPillCornerRadiusInsets.opened
            return AnyShape(DynamicIslandPillShape(cornerRadius: radius))
        } else {
            let topRadius = activeCornerRadiusInsets.closed.top
            let bottomRadius: CGFloat = {
                switch resolvedBatteryNotificationStyle(for: kind) {
                case .compact:
                    return activeCornerRadiusInsets.closed.bottom
                case .standard:
                    return kind == .fullBattery ? 36 : 40
                }
            }()
            return AnyShape(NotchShape(topCornerRadius: topRadius, bottomCornerRadius: bottomRadius))
        }
    }

    private func resolvedBatteryNotificationStyle(for kind: BatteryTemporaryHUDKind) -> BatteryNotificationStyle {
        switch kind {
        case .charging:
            return .compact
        case .lowBattery:
            return lowBatteryHUDStyle
        case .fullBattery:
            return fullBatteryHUDStyle
        }
    }


    /// Resolves the clip/content shape per-screen: pill on non-notch screens
    /// when dynamic island mode is active, standard notch shape otherwise.
    private var resolvedClipShape: AnyShape {
        if let activeClosedBatterySurfaceShape {
            return activeClosedBatterySurfaceShape
        }
        if isDynamicIslandMode {
            return AnyShape(currentPillShape)
        }
        return AnyShape(currentNotchShape)
    }

    var body: some View {
        installRootLifecycleHandlers(on: rootBodyView)
    }

    private var mainLayoutBase: some View {
        NotchLayout()
            .frame(alignment: .top)
            .padding(.horizontal, notchHorizontalPadding)
            .padding([.horizontal, .bottom], vm.notchState == .open ? 12 : 0)
            .padding(.top, isIslandMode ? 0 : notchTopScreenBleedAmount)
            .background(.black)
            .clipShape(resolvedClipShape)
            .compositingGroup()
            .shadow(
                color: ((vm.notchState == .open || isHovering) && Defaults[.enableShadow])
                    ? .black.opacity(0.6)
                    : .clear,
                radius: Defaults[.cornerRadiusScaling] ? 10 : 5
            )
            // Extra horizontal inset for Dynamic Island mode so the shadow
            // is not clipped by the outer frame constraint
            .padding(.horizontal, isIslandMode ? dynamicIslandShadowInset : 0)
            .padding(.bottom, isIslandMode ? dynamicIslandShadowInset : 0)
            .padding(.top, pillTopOffset)
            .accessibilityIdentifier("AtollNotch")
    }

    private var configuredMainLayout: some View {
        mainLayoutBase
            .overlay(alignment: .top) { ReactionAnimationOverlay(cameraSafeTop: physicalNotchSafeTop) }
            .conditionalModifier(!useModernCloseAnimation) { view in
                let hoverAnimation = Animation.bouncy.speed(1.2)
                let notchStateAnimation = Animation.spring(response: 0.42, dampingFraction: 1.0, blendDuration: 0)
                return view
                    .animation(hoverAnimation, value: isHovering)
                    .animation(notchStateAnimation, value: vm.notchState)
                    .animation(.smooth, value: gestureProgress)
                    .transition(.blurReplace.animation(.interactiveSpring(dampingFraction: 1.2)))
            }
            .conditionalModifier(useModernCloseAnimation) { view in
                let hoverAnimation = Animation.bouncy.speed(1.2)
                let openAnimation = Animation.spring(response: 0.42, dampingFraction: 1.0, blendDuration: 0)
                let closeAnimation = Animation.spring(response: 0.45, dampingFraction: 1.0, blendDuration: 0)
                let notchAnimation = vm.notchState == .open ? openAnimation : closeAnimation
                return view
                    .animation(hoverAnimation, value: isHovering)
                    .animation(notchAnimation, value: vm.notchState)
                    .animation(.smooth, value: gestureProgress)
            }
            .conditionalModifier(interactionsEnabled) { view in
                view
                    .contentShape(resolvedClipShape)
                    .onHover { hovering in
                        handleHover(hovering)
                    }
                    .onTapGesture {
                        if handleClosedMusicWaveformTapIfNeeded() {
                            return
                        }
                        if vm.notchState == .closed && Defaults[.enableHaptics] {
                            triggerHapticIfAllowed()
                        }
                        openNotch()
                    }
                    .conditionalModifier(Defaults[.enableGestures]) { view in
                        view
                            .panGesture(direction: .down) { translation, phase in
                                handleDownGesture(translation: translation, phase: phase)
                            }
                            .panGesture(direction: .left) { translation, phase in
                                handleSkipGesture(direction: .forward, translation: translation, phase: phase)
                            }
                            .panGesture(direction: .right) { translation, phase in
                                handleSkipGesture(direction: .backward, translation: translation, phase: phase)
                            }
                    }
            }
            .conditionalModifier((Defaults[.closeGestureEnabled] || Defaults[.reverseScrollGestures]) && Defaults[.enableGestures] && interactionsEnabled) { view in
                view
                    .panGesture(direction: .up) { translation, phase in
                        handleUpGesture(translation: translation, phase: phase)
                    }
            }
            // Shadow bottom padding and hide-until-hover offset applied AFTER
            // interaction modifiers so .contentShape / .onHover only covers
            // the actual notch content, not the shadow clearance below it.
            .padding(.bottom, notchBottomPadding)
            .offset(y: shouldHideUntilHover && !isHovering
                ? -(vm.closedNotchSize.height + pillTopOffset + currentShadowPadding + 10)
                : 0
            )
            .onAppear(perform: {
                if coordinator.firstLaunch {
                    // Single open during first launch; closeHello() handles the timed close.
                    runAfter(1) {
                        openNotch()
                    }
                }
            })
            .onChange(of: vm.notchState) { _, newState in
                // Update smart monitoring based on notch state
                if enableStatsFeature {
                    let currentViewString = coordinator.currentView == .stats ? "stats" : "other"
                    statsManager.updateMonitoringState(
                        notchIsOpen: newState == .open,
                        currentView: currentViewString
                    )
                }

                // Reset hover state when notch state changes
                if newState == .closed && isHovering {
                    withAnimation {
                        isHovering = false
                    }
                }
                if newState != .closed {
                    isHoveringClosedMusicWaveformControl = false
                }
                if newState == .closed {
                    removeStickyTerminalClickMonitor()
                } else {
                    // Install the outside-click monitor for terminal opens that don't
                    // change `currentView` (e.g. shortcut re-opening with the terminal
                    // tab already selected, where the cursor never enters the notch).
                    syncStickyTerminalOutsideClickMonitor()
                }
                #if os(macOS)
                if newState == .open {
                    TimerControlWindowManager.shared.hide()
                }
                #endif
            }
            .onChange(of: vm.isBatteryPopoverActive) { _, newPopoverState in
                runAfter(0.1) {
                    if !newPopoverState && !isHovering && vm.notchState == .open && !shouldPreventAutoClose() {
                        vm.close()
                    }
                }
            }
            .onChange(of: vm.isStatsPopoverActive) { _, newPopoverState in
                runAfter(0.1) {
                    if !newPopoverState && !isHovering && vm.notchState == .open && !shouldPreventAutoClose() {
                        vm.close()
                    }
                }
            }
            .onChange(of: vm.shouldRecheckHover) { _, _ in
                // Recheck hover state when popovers are closed
                runAfter(0.1) {
                    if vm.notchState == .open && !shouldPreventAutoClose() && !isHovering {
                        vm.close()
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .sharingDidFinish)) { _ in
                runAfter(0.1) {
                    if vm.notchState == .open && !isHovering && !shouldPreventAutoClose() {
                        vm.close()
                    }
                }
            }
            .onChange(of: coordinator.sneakPeek.show) { _, sneakPeekShowing in
                // When sneak peek finishes, check if user is still hovering and open notch if needed
                if !sneakPeekShowing {
                    runAfter(0.2) {
                        if isHovering && vm.notchState == .closed && !coordinator.isHoverOpenSuppressed {
                            openNotch()
                        }
                    }
                }
            }
            .onChange(of: coordinator.currentView) { _, newValue in
                if enableStatsFeature {
                    let currentViewString = newValue == .stats ? "stats" : "other"
                    statsManager.updateMonitoringState(
                        notchIsOpen: vm.notchState == .open,
                        currentView: currentViewString
                    )
                }
                syncStickyTerminalOutsideClickMonitor()
            }
            .sensoryFeedback(.alignment, trigger: haptics)
            .contextMenu {
                Button("Settings") {
                    SettingsWindowController.shared.showWindow()
                }
//                Button("Edit") { // Doesnt work....
//                    let dn = DynamicNotch(content: EditPanelView())
//                    dn.toggle()
//                }
//                #if DEBUG
//                .disabled(false)
//                #else
//                .disabled(true)
//                #endif
//                .keyboardShortcut("E", modifiers: .command)
            }
    }

    private var musicShouldOwnClosedNotch: Bool {
        MusicManager.shared.hasActiveSession && !MusicManager.shared.isPlayerIdle
    }

    private var compactBridgeClosedHomeActive: Bool {
        vm.notchState == .closed
        && !Defaults[.enableMinimalisticUI]
        && !musicShouldOwnClosedNotch
        && !Defaults[.showCalendar]
        && !(Defaults[.showMirror] && WebcamManager.shared.cameraAvailable)
    }

    private var rootBodyView: some View {
        configuredMainLayout
            .frame(
                maxWidth: (dynamicNotchSize.width + (vm.notchState == .open ? 24 : 0) + (isDynamicIslandMode ? dynamicIslandShadowInset * 2 : 0)).rounded(),
                maxHeight: (dynamicNotchSize.height + (compactBridgeClosedHomeActive ? 0 : (vm.notchState == .open ? 12 : 0)) + (compactBridgeClosedHomeActive ? 0 : (isIslandMode ? 0 : notchTopScreenBleedAmount)) + (compactBridgeClosedHomeActive ? 0 : (isDynamicIslandMode ? dynamicIslandTopOffset + dynamicIslandShadowInset * 2 : currentShadowPadding))).rounded(),
                alignment: .top
            )
        .animation(nil, value: vm.notchState)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .environmentObject(privacyManager)
        .background(dragDetector)
        .environmentObject(vm)
        .environmentObject(webcamManager)
    }

    private func installRootLifecycleHandlers<Content: View>(on view: Content) -> some View {
        installSecondaryRootLifecycleHandlers(
            on: installPrimaryRootLifecycleHandlers(on: view)
        )
    }

    private func installPrimaryRootLifecycleHandlers<Content: View>(on view: Content) -> some View {
        view
            .onAppear {
                isMusicControlWindowSuppressed = vm.notchState != .closed
                    || lockScreenManager.isLocked
                    || isMusicHUDDeferredAfterUnlock
                if musicManager.isPlaying || !musicManager.isPlayerIdle {
                    clearMusicControlVisibilityDeadline()
                }
                if let deadline = musicControlVisibilityDeadline, Date() > deadline {
                    clearMusicControlVisibilityDeadline()
                }
                enqueueMusicControlWindowSync(forceRefresh: true)
                startHiddenEdgeHoverPolling()
                bridgeClosedStatus = AtollBridgeStatus.load()
                // Deterministic teardown for borderless panels (`.onDisappear` is
                // unreliable); the window-cleanup path calls this before closing.
                vm.onViewTeardown = { performViewTeardown() }
            }
            .onChange(of: terminalStickyMode) { _, _ in
                syncStickyTerminalOutsideClickMonitor()
            }
            .onChange(of: vm.notchState) { _, state in
                if state == .open {
                    suppressMusicControlWindowUpdates()
                    cancelMusicControlWindowSync()
                    hideMusicControlWindow()
                } else {
                    releaseMusicControlWindowUpdates(after: musicControlResumeDelay)
                    enqueueMusicControlWindowSync(forceRefresh: true, delay: 0.05)
                }
            }
            .onChange(of: musicControlWindowEnabled) { _, enabled in
                if enabled {
                    if musicManager.isPlaying || !musicManager.isPlayerIdle {
                        clearMusicControlVisibilityDeadline()
                    }
                    enqueueMusicControlWindowSync(forceRefresh: true)
                } else {
                    cancelMusicControlWindowSync()
                    hideMusicControlWindow()
                    clearMusicControlVisibilityDeadline()
                    hasPendingMusicControlSync = false
                    pendingMusicControlForceRefresh = false
                }
            }
            .onChange(of: coordinator.musicLiveActivityEnabled) { _, enabled in
                if enabled {
                    enqueueMusicControlWindowSync(forceRefresh: true)
                } else {
                    cancelMusicControlWindowSync()
                    hideMusicControlWindow()
                    clearMusicControlVisibilityDeadline()
                    hasPendingMusicControlSync = false
                    pendingMusicControlForceRefresh = false
                }
            }
            .onChange(of: vm.hideOnClosed) { _, hidden in
                if hidden {
                    cancelMusicControlWindowSync()
                    hideMusicControlWindow()
                } else {
                    enqueueMusicControlWindowSync(forceRefresh: true, delay: 0.05)
                }
            }
            .onChange(of: lockScreenManager.isLocked) { _, locked in
                if locked {
                    suppressMusicControlWindowUpdates()
                    cancelMusicControlWindowSync()
                    hideMusicControlWindow()
                } else {
                    releaseMusicControlWindowUpdates(after: musicControlResumeDelay)
                    enqueueMusicControlWindowSync(forceRefresh: true, delay: 0.05)
                }
            }
            .onChange(of: lockScreenManager.shouldDelayPostUnlockMusicHUD) { _, deferred in
                if deferred {
                    suppressMusicControlWindowUpdates()
                    cancelMusicControlWindowSync()
                    hideMusicControlWindow()
                } else {
                    releaseMusicControlWindowUpdates(after: 0)
                    enqueueMusicControlWindowSync(forceRefresh: true, delay: 0.05)
                }
            }
    }

    private func installSecondaryRootLifecycleHandlers<Content: View>(on view: Content) -> some View {
        view
            .onChange(of: showStandardMediaControls) { _, _ in
                handleStandardMediaControlsAvailabilityChange()
            }
            .onReceive(bridgeClosedStatusRefresh) { _ in
                let next = AtollBridgeStatus.load()
                if next != bridgeClosedStatus {
                    withAnimation(.smooth(duration: 0.25)) {
                        bridgeClosedStatus = next
                    }
                }
            }
            .onChange(of: enableMinimalisticUI) { _, _ in
                handleStandardMediaControlsAvailabilityChange()
            }
            .onChange(of: gestureProgress) { _, _ in
                if shouldShowMusicControlWindow() {
                    enqueueMusicControlWindowSync(forceRefresh: true, delay: 0.05)
                }
            }
            .onChange(of: isHovering) { _, hovering in
                if shouldShowMusicControlWindow() {
                    enqueueMusicControlWindowSync(forceRefresh: true, delay: hovering ? 0.05 : 0.12)
                }
            }
            .onChange(of: musicManager.isPlaying) { _, isPlaying in
                handleMusicControlPlaybackChange(isPlaying: isPlaying)
            }
            .onChange(of: musicManager.isPlayerIdle) { _, isIdle in
                handleMusicControlIdleChange(isIdle: isIdle)
            }
            .onChange(of: vm.closedNotchSize) { _, _ in
                if shouldShowMusicControlWindow() {
                    enqueueMusicControlWindowSync(forceRefresh: true)
                }
            }
            .onChange(of: vm.effectiveClosedNotchHeight) { _, _ in
                if shouldShowMusicControlWindow() {
                    enqueueMusicControlWindowSync(forceRefresh: true)
                }
            }
            .onDisappear {
                performViewTeardown()
            }
    }

    @ViewBuilder
      func NotchLayout() -> some View {
          VStack(alignment: .leading) {
              VStack(alignment: .leading) {
                  if coordinator.firstLaunch {
                      Spacer()
                      HelloAnimation().frame(width: 200, height: 80).onAppear(perform: {
                          vm.closeHello()
                      })
                      .padding(.top, 40)
                      Spacer()
                  } else {
                        let hasMusicMetadata = !musicManager.songTitle.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty
                            || !musicManager.artistName.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty
                      let hasActiveMusicSnapshot: Bool = {
                          if musicManager.isPlaying { return true }
                          return !musicManager.isPlayerIdle && hasMusicMetadata
                      }()
                      let musicPairingEligible = closedMusicPairingEligible(hasActiveMusicSnapshot: hasActiveMusicSnapshot)
                      let musicSecondary = resolveMusicSecondaryLiveActivity(isMusicPairingEligible: musicPairingEligible)
                      let extensionSecondaryPayloadID = extensionSecondaryPayloadID(for: musicSecondary)
                      let extensionStandalonePayload = resolvedExtensionStandalonePayload(excluding: extensionSecondaryPayloadID)
                      let activeSneakPeekStyle = resolvedSneakPeekStyle()
                      let expansionMatchesSecondary: Bool = {
                          guard let musicSecondary else { return false }
                          switch musicSecondary {
                          case .timer:
                              return currentScreenExpansionType == .timer
                          case .reminder:
                              return currentScreenExpansionType == .reminder
                          case .recording:
                              return currentScreenExpansionType == .recording
                          case .focus:
                              return currentScreenExpansionType == .doNotDisturb
                          case .capsLock:
                              return false
                          case .extensionPayload:
                              return false
                          case .shelf:
                              return false
                          }
                      }()
                      let canShowMusicDuringExpansion = !isCurrentScreenExpansionVisible
                          || currentScreenExpansionType == .music
                          || expansionMatchesSecondary
                      let isAirPodsListeningModeSneak = coordinator.sneakPeek.type == .bluetoothAudio
                          && coordinator.sneakPeek.value < 0
                          && AirPodsListeningMode.fromHUDSymbol(coordinator.sneakPeek.icon) != nil

                      if currentScreenExpansionType == .battery
                            && isBatteryHUDVisibleOnCurrentScreen
                            && vm.notchState == .closed
                            && Defaults[.showPowerStatusNotifications]
                            && batteryModel.activeTemporaryHUDKind != nil {
                        BatteryTemporaryActivityView(
                            kind: batteryModel.activeTemporaryHUDKind ?? .charging,
                            batteryLevel: displayedBatteryHUDLevel,
                            isLowPowerMode: displayedBatteryHUDUsesLowPowerMode,
                            closedNotchWidth: vm.closedNotchSize.width + (isHovering ? 8 : 0),
                            baseHeight: vm.effectiveClosedNotchHeight + (isHovering ? 8 : 0),
                            isDynamicIslandMode: isDynamicIslandMode,
                            topCornerRadius: activeCornerRadiusInsets.closed.top,
                            styleOverride: batteryModel.activeTemporaryHUDKind.map { resolvedBatteryNotificationStyle(for: $0) }
                        )
                        .id(batteryModel.activeTemporaryHUDToken)
                      } else if isSneakPeekVisibleOnCurrentScreen && (Defaults[.inlineHUD] || isAirPodsListeningModeSneak) && (coordinator.sneakPeek.type != .music) && (coordinator.sneakPeek.type != .battery) && (coordinator.sneakPeek.type != .timer) && (coordinator.sneakPeek.type != .reminder) && !coordinator.sneakPeek.type.isExtensionPayload && ((coordinator.sneakPeek.type != .volume && coordinator.sneakPeek.type != .brightness && coordinator.sneakPeek.type != .backlight) || vm.notchState == .closed) {
                          InlineHUD(type: $coordinator.sneakPeek.type, value: $coordinator.sneakPeek.value, icon: $coordinator.sneakPeek.icon, hoverAnimation: $isHovering, gestureProgress: $gestureProgress)
                              .transition(
                                  coordinator.sneakPeek.type == .capsLock
                                      ? AnyTransition.move(edge: .trailing).combined(with: .opacity)
                                      : AnyTransition.opacity
                              )
                      } else if vm.notchState == .closed && capsLockManager.isCapsLockActive && Defaults[.enableCapsLockIndicator] && !vm.hideOnClosed && !lockScreenManager.isLocked {
                          InlineHUD(type: .constant(.capsLock), value: .constant(1.0), icon: .constant(""), hoverAnimation: $isHovering, gestureProgress: $gestureProgress)
                              .transition(AnyTransition.move(edge: .trailing).combined(with: .opacity))
                      } else if canShowMusicDuringExpansion && musicPairingEligible {
                          MusicLiveActivity(secondary: musicSecondary)
                              .id("closed-music-live-activity")
                              .transition(closedLiveActivitySwapTransition)
                      } else if bridgeClosedHasPriorityStatus && vm.notchState == .closed && Defaults[.showNotHumanFace] && !lockScreenManager.isLocked {
                          AtollBridgeClosedLiveActivity(status: bridgeClosedStatus, closedNotchWidth: max(vm.closedNotchSize.width, 195))
                              .transition(.opacity.animation(.smooth(duration: 0.25)))
                      } else if (!isCurrentScreenExpansionVisible || currentScreenExpansionType == .timer) && vm.notchState == .closed && timerManager.isTimerActive && coordinator.timerLiveActivityEnabled && !vm.hideOnClosed {
                          TimerLiveActivity()
                      } else if (!isCurrentScreenExpansionVisible || currentScreenExpansionType == .reminder) && vm.notchState == .closed && reminderManager.isActive && enableReminderLiveActivity && !vm.hideOnClosed {
                          ReminderLiveActivity()
                      } else if (!isCurrentScreenExpansionVisible || currentScreenExpansionType == .recording) && vm.notchState == .closed && (recordingManager.isRecording || !recordingManager.isRecorderIdle) && Defaults[.enableScreenRecordingDetection] && !vm.hideOnClosed && !musicPairingEligible {
                          RecordingLiveActivity()
                      } else if (!isCurrentScreenExpansionVisible || currentScreenExpansionType == .download) && vm.notchState == .closed && downloadManager.isDownloading && Defaults[.enableDownloadListener] && !vm.hideOnClosed {
                          DownloadLiveActivity()
                              .transition(.blurReplace.animation(.interactiveSpring(dampingFraction: 1.2)))
                      } else if !isCurrentScreenExpansionVisible && vm.notchState == .closed && localSendLiveActivityActive && !vm.hideOnClosed {
                          LocalSendLiveActivity()
                              .transition(.blurReplace.animation(.interactiveSpring(dampingFraction: 1.2)))
                      } else if (!isCurrentScreenExpansionVisible || currentScreenExpansionType == .doNotDisturb) && vm.notchState == .closed && Defaults[.enableDoNotDisturbDetection] && Defaults[.showDoNotDisturbIndicator] && (doNotDisturbManager.isDoNotDisturbActive || doNotDisturbManager.isFocusToastDismissing) && !vm.hideOnClosed && !lockScreenManager.isLocked {
                          DoNotDisturbLiveActivity()
                    } else if (!isCurrentScreenExpansionVisible || currentScreenExpansionType == .lockScreen) && vm.notchState == .closed && (lockScreenManager.isLocked || !lockScreenManager.isLockIdle) && Defaults[.enableLockScreenLiveActivity] && !vm.hideOnClosed {
                        LockScreenLiveActivity()
                            .id("lock-screen-live-activity")
                            .transition(closedLiveActivitySwapTransition)
                    } else if (!isCurrentScreenExpansionVisible || currentScreenExpansionType == .privacy) && vm.notchState == .closed && privacyManager.hasAnyIndicator && (Defaults[.enableCameraDetection] || Defaults[.enableMicrophoneDetection]) && !vm.hideOnClosed {
                        PrivacyLiveActivity()
                      } else if let extensionPayload = extensionStandalonePayload {
                          let layout = extensionStandaloneLayout(
                              for: extensionPayload,
                              notchHeight: vm.effectiveClosedNotchHeight,
                              isHovering: isHovering
                          )
                          ExtensionLiveActivityStandaloneView(
                              payload: extensionPayload,
                              layout: layout,
                              isHovering: isHovering
                          )
                      } else if !coordinator.expandingView.show && vm.notchState == .closed && !shelfState.isEmpty && !vm.hideOnClosed && !lockScreenManager.isLocked && !enableMinimalisticUI {
                          ShelfInlineLiveActivity()
                              .transition(.opacity.animation(.smooth(duration: 0.25)))
                      } else if !coordinator.expandingView.show && vm.notchState == .closed && Defaults[.showNotHumanFace] && !vm.hideOnClosed  {
                          AtollBridgeClosedLiveActivity(status: bridgeClosedStatus, closedNotchWidth: max(vm.closedNotchSize.width, 195))
                              .transition(.opacity.animation(.smooth(duration: 0.25)))
                      } else if !isCurrentScreenExpansionVisible && vm.notchState == .closed && Defaults[.showNotHumanFace] && !vm.hideOnClosed  {
                          AtollBridgeClosedLiveActivity(status: bridgeClosedStatus, closedNotchWidth: max(vm.closedNotchSize.width, 195))
                              .transition(.opacity.animation(.smooth(duration: 0.25)))
                      } else if vm.notchState == .open {
                          DynamicIslandHeader()
                              .frame(height: (Defaults[.enableMinimalisticUI] && isDynamicIslandMode) ? nil : max(24, vm.effectiveClosedNotchHeight))
                       } else {
                           Rectangle().fill(.clear).frame(width: vm.closedNotchSize.width - 20, height: vm.effectiveClosedNotchHeight)
                       }
                      
                      if isSneakPeekVisibleOnCurrentScreen {
                          if (coordinator.sneakPeek.type != .music) && (coordinator.sneakPeek.type != .battery) && (coordinator.sneakPeek.type != .timer) && (coordinator.sneakPeek.type != .reminder) && (coordinator.sneakPeek.type != .capsLock) && !coordinator.sneakPeek.type.isExtensionPayload && !Defaults[.inlineHUD] && !isAirPodsListeningModeSneak && ((coordinator.sneakPeek.type != .volume && coordinator.sneakPeek.type != .brightness && coordinator.sneakPeek.type != .backlight) || vm.notchState == .closed) {
                              SystemEventIndicatorModifier(eventType: $coordinator.sneakPeek.type, value: $coordinator.sneakPeek.value, icon: $coordinator.sneakPeek.icon, sendEventBack: { _ in
                                  //
                              })
                              .padding(.bottom, 10)
                              .padding(.leading, 4)
                              .padding(.trailing, 8)
                          }
                          // Old sneak peek music
                          else if coordinator.sneakPeek.type == .music {
                              if vm.notchState == .closed && !vm.hideOnClosed && activeSneakPeekStyle == .standard {
                                  HStack(spacing: 0) {
                                      HStack(spacing: 4) {
                                          AtollCuteIcon(
                                              symbolName: "music.note",
                                              size: 15,
                                              accent: .purple,
                                              secondary: .pink,
                                              showsPlate: false,
                                              animated: true
                                          )
                                          Text("Music")
                                              .font(.system(size: 11, weight: .semibold))
                                              .foregroundStyle(.white.opacity(0.85))
                                      }
                                      .frame(width: 90, alignment: .leading)

                                      Spacer(minLength: max(vm.closedNotchSize.width + 12, 195))

                                      GeometryReader { geo in
                                          MarqueeText(.constant(musicManager.songTitle + " - " + musicManager.artistName), textColor: .gray, minDuration: 1, frameWidth: geo.size.width)
                                      }
                                      .frame(width: 100, alignment: .trailing)
                                  }
                                  .foregroundStyle(.gray)
                                  .padding(.bottom, 10)
                              }
                          }
                          // Timer sneak peek
                          else if coordinator.sneakPeek.type == .timer {
                              if !vm.hideOnClosed && activeSneakPeekStyle == .standard {
                                  HStack(spacing: 0) {
                                      HStack(spacing: 4) {
                                          AtollCuteIcon(
                                              symbolName: "timer",
                                              size: 15,
                                              accent: timerManager.timerColor,
                                              secondary: .orange,
                                              showsPlate: false,
                                              animated: true
                                          )
                                          Text("Timer")
                                              .font(.system(size: 11, weight: .semibold))
                                              .foregroundStyle(timerManager.timerColor)
                                      }
                                      .frame(width: 90, alignment: .leading)

                                      Spacer(minLength: max(vm.closedNotchSize.width + 12, 195))

                                      GeometryReader { geo in
                                          MarqueeText(.constant(timerManager.timerName + " - " + timerManager.formattedRemainingTime()), textColor: timerManager.timerColor, minDuration: 1, frameWidth: geo.size.width)
                                      }
                                      .frame(width: 100, alignment: .trailing)
                                  }
                                  .foregroundStyle(timerManager.timerColor)
                                  .padding(.bottom, 10)
                              }
                          }
                          else if coordinator.sneakPeek.type == .reminder {
                              if !vm.hideOnClosed && activeSneakPeekStyle == .standard, let reminder = reminderManager.activeReminder {
                                  let chipColor = Color(nsColor: reminder.event.calendar.color).ensureMinimumBrightness(factor: 0.7)
                                  HStack(spacing: 0) {
                                      HStack(spacing: 4) {
                                          RoundedRectangle(cornerRadius: 2)
                                              .fill(chipColor)
                                              .frame(width: 6, height: 10)
                                          Text("提醒")
                                              .font(.system(size: 11, weight: .semibold))
                                              .foregroundStyle(chipColor)
                                      }
                                      .frame(width: 80, alignment: .leading)

                                      Spacer(minLength: max(vm.closedNotchSize.width + 12, 195))

                                      GeometryReader { geo in
                                          MarqueeText(
                                              .constant(reminderSneakPeekText(for: reminder, now: reminderManager.currentDate)),
                                              textColor: reminderColor(for: reminder, now: reminderManager.currentDate),
                                              minDuration: 1,
                                              frameWidth: geo.size.width
                                          )
                                      }
                                      .frame(width: 110, alignment: .trailing)
                                  }
                                  .padding(.bottom, 10)
                              }
                          }
                          // Extension live activity sneak peek
                          else if case let .extensionLiveActivity(bundleID, activityID) = coordinator.sneakPeek.type {
                              if !vm.hideOnClosed && activeSneakPeekStyle == .standard {
                                  let payload = extensionLiveActivityManager.payload(bundleIdentifier: bundleID, activityID: activityID)
                                  let descriptor = payload?.descriptor
                                  let accent = (descriptor?.accentColor.swiftUIColor ?? coordinator.sneakPeek.accentColor ?? .gray)
                                      .ensureMinimumBrightness(factor: 0.7)
                                  HStack(spacing: 0) {
                                      HStack(spacing: 4) {
                                          RoundedRectangle(cornerRadius: 2)
                                              .fill(accent)
                                              .frame(width: 6, height: 10)
                                          Text(descriptor?.title ?? "活动")
                                              .font(.system(size: 11, weight: .semibold))
                                              .foregroundStyle(accent)
                                      }
                                      .frame(width: 80, alignment: .leading)

                                      Spacer(minLength: max(vm.closedNotchSize.width + 12, 195))

                                      GeometryReader { geo in
                                          MarqueeText(
                                              .constant(
                                                  extensionSneakPeekText(
                                                      preferredTitle: coordinator.sneakPeek.title,
                                                      preferredSubtitle: coordinator.sneakPeek.subtitle,
                                                      descriptor: descriptor
                                                  )
                                              ),
                                              textColor: accent,
                                              minDuration: 1,
                                              frameWidth: geo.size.width
                                          )
                                      }
                                      .frame(width: 110, alignment: .trailing)
                                  }
                                  .padding(.bottom, 10)
                              }
                          }
                      }
                  }
              }
              .conditionalModifier(shouldFixSizeForSneakPeek()) { view in
                  view
                      .fixedSize()
              }
              .zIndex(2)
              
              ZStack {
                  if vm.notchState == .open {
                      Group {
                          switch coordinator.currentView {
                              case .home:
                                  NotchHomeView(albumArtNamespace: albumArtNamespace)
                              case .shelf:
                                  NotchShelfView()
                              case .timer:
                                  NotchTimerView()
                              case .stats:
                                  NotchStatsView()
                              case .llmUsage:
                                  NotchLLMUsageView()
                              case .colorPicker:
                                  NotchColorPickerView()
                            case .notes:
                                NotchNotesView()
                            case .clipboard:
                                NotchClipboardView()
                            case .terminal:
                                NotchTerminalView()
                            case .extensionExperience:
                                if let payload = currentExtensionTabPayload() {
                                    ExtensionNotchExperienceTabView(payload: payload)
                                } else {
                                    NotchHomeView(albumArtNamespace: albumArtNamespace)
                                }
                          }
                      }
                      .id(coordinator.currentView)
                      .transition(tabSwitchTransition)
                  }
              }
              .zIndex(1)
              .allowsHitTesting(vm.notchState == .open)
              .blur(radius: abs(gestureProgress) > 0.3 ? min(abs(gestureProgress), 8) : 0)
              .opacity(abs(gestureProgress) > 0.3 ? min(abs(gestureProgress * 2), 0.8) : 1)
              .animation(.smooth(duration: 0.3), value: coordinator.currentView)
          }
      }

    private func reminderColor(for reminder: ReminderLiveActivityManager.ReminderEntry, now: Date) -> Color {
        if isReminderCritical(reminder, now: now) {
            return .red
        }
        return Color(nsColor: reminder.event.calendar.color).ensureMinimumBrightness(factor: 0.7)
    }

    private func reminderSneakPeekText(for entry: ReminderLiveActivityManager.ReminderEntry, now: Date) -> String {
        let title = entry.event.title.isEmpty ? "Upcoming Reminder" : entry.event.title
        let remaining = max(entry.event.start.timeIntervalSince(now), 0)
        let window = TimeInterval(Defaults[.reminderSneakPeekDuration])

        if window > 0 && remaining <= window {
            return "\(title) • \(String(format: String(localized: "now")))"
        }

        let minutes = Int(ceil(remaining / 60))
        let timeString = reminderTimeFormatter.string(from: entry.event.start)

        if minutes <= 0 {
            return "\(title) • \(String(format: String(localized: "now"))) • \(timeString)"
        } else if minutes == 1 {
            return "\(title) • \(String(format: String(localized: "in %@"), String(localized: "1 min"))) • \(timeString)"
        } else {
            return "\(title) • \(String(format: String(localized: "in %lld"), (minutes))) \(String(format: String(localized: "min plural"))) • \(timeString)"
        }
    }

    private func extensionSneakPeekText(preferredTitle: String, preferredSubtitle: String?, descriptor: AtollLiveActivityDescriptor?) -> String {
        let trimmedPreferredTitle = preferredTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let descriptorTitle = descriptor?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Extension"
        let title = trimmedPreferredTitle.isEmpty ? descriptorTitle : trimmedPreferredTitle

        let trimmedPreferredSubtitle = preferredSubtitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let descriptorSubtitle = descriptor?.subtitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let subtitle = !trimmedPreferredSubtitle.isEmpty ? trimmedPreferredSubtitle : descriptorSubtitle

        guard !subtitle.isEmpty else { return title }
        return "\(title) • \(subtitle)"
    }

    private let reminderTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    @ViewBuilder
    func DynamicIslandFaceAnimation() -> some View {
        let sideSize = max(0, vm.effectiveClosedNotchHeight - 12)
        HStack {
            HStack {
                Rectangle()
                    .fill(.clear)
                    .frame(width: sideSize, height: sideSize)
                Rectangle()
                    .fill(.black)
                    .frame(width: vm.closedNotchSize.width - 20)
                IdleAnimationView()
                    .frame(width: sideSize, height: sideSize)
            }
        }.frame(height: vm.effectiveClosedNotchHeight + (isHovering ? 8 : 0), alignment: .top)
    }

    @ViewBuilder
    private func MusicLiveActivity(secondary preResolvedSecondary: MusicSecondaryLiveActivity? = nil) -> some View {
        let secondary = preResolvedSecondary ?? resolveMusicSecondaryLiveActivity()
        let closedHeight = vm.effectiveClosedNotchHeight
        let outerHeight = closedHeight + (isHovering ? 8 : 0)
        let notchContentHeight = isHovering ? outerHeight : max(0, closedHeight - 12)
        let wingBaseWidth = max(0, notchContentHeight + gestureProgress / 2)
        let rawCenterBaseWidth = vm.closedNotchSize.width + (isHovering ? 8 : 0)
        let centerBaseWidth = max(rawCenterBaseWidth, 96)
        let inlineSneakPeekActive = (
            coordinator.expandingView.show &&
            (coordinator.expandingView.type == .music || coordinator.expandingView.type == .timer) &&
            Defaults[.enableSneakPeek] &&
            Defaults[.sneakPeekStyles] == .inline
        )
        let rightWingWidth = resolvedRightWingWidth(
            for: secondary,
            baseWidth: wingBaseWidth,
            centerBaseWidth: centerBaseWidth,
            notchHeight: notchContentHeight
        )
        let effectiveCenterWidth = inlineSneakPeekActive ? 380 : centerBaseWidth
        let notchWidth = wingBaseWidth + effectiveCenterWidth + rightWingWidth
        let badgeBaseSize = max(13, notchContentHeight * 0.36)
        let badgeDisplaySize = badgeDisplaySize(for: secondary, baseSize: badgeBaseSize)
        let badgeOffset = badgeOverlayOffset(for: secondary, badgeSize: badgeDisplaySize)

        HStack(spacing: 0) {
            ZStack(alignment: .bottomTrailing) {
                Color.clear
                    .aspectRatio(1, contentMode: .fit)
                    .background(
                        Image(nsImage: musicManager.albumArt)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: musicManager.albumArt.size.width/musicManager.albumArt.size.height > 1.0 ? MusicPlayerImageSizes.cornerRadiusInset.closed/3.0 : MusicPlayerImageSizes.cornerRadiusInset.closed))
                    )
                    .clipped()
                    .matchedGeometryEffect(id: "albumArt", in: albumArtNamespace)
                    .albumArtFlip(angle: musicManager.flipAngle)
                albumArtBadge(for: secondary, badgeSize: badgeDisplaySize)
                    .offset(x: badgeOffset.width, y: badgeOffset.height)
                    .id(secondary?.id ?? "music-badge")
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(width: wingBaseWidth, height: notchContentHeight)

            Rectangle()
                .fill(.black)
                .frame(width: effectiveCenterWidth, height: notchContentHeight)
                .overlay(
                    HStack(alignment: .top) {
                        if(coordinator.expandingView.show && coordinator.expandingView.type == .music) {
                            MusicTitleMarqueeView(
                                text: musicManager.songTitle,
                                isExplicit: musicManager.isCurrentTrackExplicit,
                                textColor: Defaults[.coloredSpectrogram] ? Color(nsColor: musicManager.avgColor) : Color.gray,
                                minDuration: 0.4,
                                frameWidth: max(0, (effectiveCenterWidth - vm.closedNotchSize.width) / 2 - 12),
                                badgeHeight: 13
                            )
                            .padding(.leading, 8)
                            .opacity((coordinator.expandingView.show && Defaults[.enableSneakPeek] && Defaults[.sneakPeekStyles] == .inline) ? 1 : 0)
                            Spacer(minLength: vm.closedNotchSize.width)
                            Text(musicManager.artistName)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .foregroundStyle(Defaults[.coloredSpectrogram] ? Color(nsColor: musicManager.avgColor) : Color.gray)
                                .padding(.trailing, 8)
                                .opacity((coordinator.expandingView.show && coordinator.expandingView.type == .music && Defaults[.enableSneakPeek] && Defaults[.sneakPeekStyles] == .inline) ? 1 : 0)
                        } else if(coordinator.expandingView.show && coordinator.expandingView.type == .timer) {
                            MarqueeText(
                                .constant(timerManager.timerName),
                                textColor: timerManager.timerColor,
                                minDuration: 0.4,
                                frameWidth: max(0, (effectiveCenterWidth - vm.closedNotchSize.width) / 2 - 12)
                            )
                            .padding(.leading, 8)
                            .opacity((coordinator.expandingView.show && Defaults[.enableSneakPeek] && Defaults[.sneakPeekStyles] == .inline) ? 1 : 0)
                            Spacer(minLength: vm.closedNotchSize.width)
                            Text(timerManager.formattedRemainingTime())
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .foregroundStyle(timerManager.timerColor)
                                .padding(.trailing, 8)
                                .opacity((coordinator.expandingView.show && coordinator.expandingView.type == .timer && Defaults[.enableSneakPeek] && Defaults[.sneakPeekStyles] == .inline) ? 1 : 0)
                        } else if Defaults[.showSongMetadataInClosedNotch] && isNonNotchScreen && !musicManager.songTitle.isEmpty {
                            MarqueeText(
                                .constant("\(musicManager.songTitle) • \(musicManager.artistName)"),
                                textColor: Defaults[.coloredSpectrogram] ? Color(nsColor: musicManager.avgColor) : Color.gray,
                                minDuration: 3,
                                frameWidth: max(0, effectiveCenterWidth - 16)
                            )
                            .padding(.horizontal, 8)
                        }
                    }
                    .clipped()
                )

            musicRightWing(for: secondary, notchHeight: notchContentHeight, trailingWidth: rightWingWidth)
                .frame(width: rightWingWidth, height: notchContentHeight, alignment: .center)
                .contentShape(Rectangle())
                .onHover { hovering in
                    guard shouldShowClosedMusicWaveformPlayPauseOverlay(for: secondary) else {
                        if isHoveringClosedMusicWaveformControl {
                            isHoveringClosedMusicWaveformControl = false
                        }
                        return
                    }
                    withAnimation(.smooth(duration: 0.16)) {
                        isHoveringClosedMusicWaveformControl = hovering
                    }
                }
                .id(secondary?.id ?? "music-spectrum")
                .contentTransition(.symbolEffect(.replace))
        }
        .frame(width: notchWidth, height: notchContentHeight)
        .frame(height: outerHeight, alignment: .top)
        .animation(.smooth(duration: 0.25), value: secondary?.id)
    }

    private func resolveMusicSecondaryLiveActivity(isMusicPairingEligible: Bool = true) -> MusicSecondaryLiveActivity? {
        if coordinator.timerLiveActivityEnabled && timerManager.isTimerActive {
            return .timer
        }

        if enableReminderLiveActivity, reminderManager.isActive, let reminder = reminderManager.activeReminder {
            return .reminder(reminder)
        }

        if enableScreenRecordingDetection && (recordingManager.isRecording || !recordingManager.isRecorderIdle) {
            return .recording
        }

        if enableDoNotDisturbDetection && showDoNotDisturbIndicator && doNotDisturbManager.isDoNotDisturbActive {
            let mode = FocusModeType.resolve(identifier: doNotDisturbManager.currentFocusModeIdentifier, name: doNotDisturbManager.currentFocusModeName)
            return .focus(mode)
        }

        if enableCapsLockIndicator && capsLockManager.isCapsLockActive {
            return .capsLock(showLabel: showCapsLockLabel)
        }

        if isMusicPairingEligible, let extensionPayload = resolvedExtensionMusicPayload() {
            return .extensionPayload(extensionPayload)
        }

        // Shelf: show file count as lowest-priority secondary
        if !shelfState.isEmpty && !lockScreenManager.isLocked && !enableMinimalisticUI {
            return .shelf(count: shelfState.items.count)
        }

        return nil
    }

    private func resolvedRightWingWidth(for secondary: MusicSecondaryLiveActivity?, baseWidth: CGFloat, centerBaseWidth: CGFloat, notchHeight: CGFloat) -> CGFloat {
        guard let secondary else { return baseWidth }

        switch secondary {
        case .timer:
            return timerRightWingWidth(baseWidth: baseWidth, centerBaseWidth: centerBaseWidth)
        case .reminder(let entry):
            return reminderRightWingWidth(for: entry, baseWidth: baseWidth, notchHeight: notchHeight, now: reminderManager.currentDate)
        case .capsLock(let showLabel):
            return showLabel ? scaledWingWidth(baseWidth: baseWidth, centerBaseWidth: centerBaseWidth, factor: 0.4, extra: 12) : baseWidth
        case .focus:
            return focusRightWingWidth(baseWidth: baseWidth)
        case .recording:
            return recordingRightWingWidth(baseWidth: baseWidth)
        case .extensionPayload(let payload):
            let maxWidth = baseWidth + centerBaseWidth * 0.6
            return ExtensionLayoutMetrics.trailingWidth(for: payload, baseWidth: baseWidth, maxWidth: maxWidth)
        case .shelf:
            return baseWidth
        }
    }

    private func timerRightWingWidth(baseWidth: CGFloat, centerBaseWidth: CGFloat) -> CGFloat {
        if timerShowsCountdown {
            return timerCountdownWingWidth(baseWidth: baseWidth)
        }

        let showsProgress = timerShowsProgress
        let usesRingProgress = timerProgressStyle == .ring

        switch (showsProgress, usesRingProgress) {
        case (true, true):
            return scaledWingWidth(baseWidth: baseWidth, centerBaseWidth: centerBaseWidth, factor: 0.46, extra: 18)
        case (true, false):
            return scaledWingWidth(baseWidth: baseWidth, centerBaseWidth: centerBaseWidth, factor: 0.52, extra: 24)
        case (false, _):
            return scaledWingWidth(baseWidth: baseWidth, centerBaseWidth: centerBaseWidth, factor: 0.38, extra: 12)
        }
    }

    private func timerCountdownWingWidth(baseWidth: CGFloat) -> CGFloat {
        let padding: CGFloat = 18
        let ringWidth: CGFloat = (timerShowsProgress && timerProgressStyle == .ring) ? 30 : 0
        let spacing: CGFloat = (ringWidth > 0) ? 8 : 0
        let countdownText = timerManager.formattedRemainingTime()
        let countdownWidth = TimerSupplementMetrics.countdownFrameWidth(for: countdownText)
        return max(baseWidth, padding + ringWidth + spacing + countdownWidth)
    }

    private func reminderRightWingWidth(for entry: ReminderLiveActivityManager.ReminderEntry, baseWidth: CGFloat, notchHeight: CGFloat, now: Date) -> CGFloat {
        let padding: CGFloat = 16
        switch reminderPresentationStyle {
        case .ringCountdown:
            let diameter = ReminderSupplementMetrics.ringDiameter(for: notchHeight)
            return max(baseWidth, padding + diameter)
        case .digital:
            let countdownText = ReminderSupplementMetrics.digitalCountdownText(for: entry, now: now)
            let width = ReminderSupplementMetrics.digitalFrameWidth(for: countdownText)
            return max(baseWidth, padding + width)
        case .minutes:
            let minutesText = ReminderSupplementMetrics.minutesCountdownText(for: entry, now: now)
            let width = ReminderSupplementMetrics.minutesFrameWidth(for: minutesText)
            return max(baseWidth, padding + width)
        }
    }

    private func focusRightWingWidth(baseWidth: CGFloat) -> CGFloat {
        // Focus pairings now mirror the default music spectrum width to keep the notch compact.
        return baseWidth
    }

    private func recordingRightWingWidth(baseWidth: CGFloat) -> CGFloat {
        // Keep recording pairings compact by reducing the width relative to the notch height.
        let absoluteMin: CGFloat = 38
        let preferredWidth = max(baseWidth * 0.6, 0)
        let maxWidth = min(baseWidth - 6, 52)
        let clampedPreferred = min(preferredWidth, maxWidth)
        return min(baseWidth, max(absoluteMin, clampedPreferred))
    }

    private func scaledWingWidth(baseWidth: CGFloat, centerBaseWidth: CGFloat, factor: CGFloat, extra: CGFloat) -> CGFloat {
        max(baseWidth, max(centerBaseWidth * factor, baseWidth + extra))
    }

    @ViewBuilder
    private func albumArtBadge(for secondary: MusicSecondaryLiveActivity?, badgeSize: CGFloat) -> some View {
        if let secondary, badgeSize > 0 {
            ZStack {
                Circle()
                    .fill(Color.black)

                switch secondary {
                case .timer:
                    AtollCuteIcon(symbolName: "timer",
                                  size: badgeSize * 0.78,
                                  accent: timerAccentColor,
                                  secondary: .orange,
                                  showsPlate: false,
                                  animated: true)
                case .reminder(let entry):
                    let accent = reminderColor(for: entry, now: reminderManager.currentDate)
                    AtollCuteIcon(symbolName: "clock",
                                  size: badgeSize * 0.76,
                                  accent: accent,
                                  secondary: .yellow,
                                  showsPlate: false,
                                  animated: false)
                case .focus(let mode):
                    mode.resolvedActiveIcon(usePrivateSymbol: true)
                        .renderingMode(.template)
                        .font(.system(size: badgeSize * 0.5, weight: .semibold))
                        .foregroundStyle(mode.accentColor)
                case .recording:
                    Circle()
                        .fill(Color.red)
                        .frame(width: badgeSize * 0.45, height: badgeSize * 0.45)
                        .modifier(PulsingModifier())
                case .capsLock:
                    AtollCuteIcon(symbolName: "capslock.fill",
                                  size: badgeSize * 0.76,
                                  accent: capsLockTintMode.color,
                                  secondary: .white,
                                  showsPlate: false,
                                  animated: false)
                case .extensionPayload(let payload):
                    ExtensionBadgeIconView(
                        descriptor: payload.descriptor.leadingIcon,
                        accent: payload.descriptor.accentColor.swiftUIColor,
                        size: badgeSize
                    )
                case .shelf:
                    AtollCuteIcon(symbolName: "tray.and.arrow.down.fill",
                                  size: badgeSize * 0.78,
                                  accent: .white,
                                  secondary: .cyan,
                                  showsPlate: false,
                                  animated: false)
                }
            }
            .frame(width: badgeSize, height: badgeSize)
            .shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 1)
            .transition(.opacity.combined(with: .scale))
        } else {
            EmptyView()
        }
    }

    private func badgeDisplaySize(for secondary: MusicSecondaryLiveActivity?, baseSize: CGFloat) -> CGFloat {
        guard let secondary else { return baseSize }
        switch secondary {
        default:
            return baseSize
        }
    }

    private func badgeOverlayOffset(for secondary: MusicSecondaryLiveActivity?, badgeSize: CGFloat) -> CGSize {
        guard let secondary else { return CGSize(width: badgeSize * 0.2, height: badgeSize * 0.25) }
        switch secondary {
        default:
            return CGSize(width: badgeSize * 0.2, height: badgeSize * 0.25)
        }
    }

    @ViewBuilder
    private func musicRightWing(for secondary: MusicSecondaryLiveActivity?, notchHeight: CGFloat, trailingWidth: CGFloat) -> some View {
        switch secondary {
        case .timer:
            MusicTimerSupplementView(
                timerManager: timerManager,
                accentColor: timerAccentColor,
                showsCountdown: timerShowsCountdown,
                showsProgress: timerShowsProgress,
                progressStyle: timerProgressStyle,
                notchHeight: notchHeight
            )
        case .reminder(let entry):
            MusicReminderSupplementView(
                entry: entry,
                now: reminderManager.currentDate,
                style: reminderPresentationStyle,
                accent: reminderColor(for: entry, now: reminderManager.currentDate),
                notchHeight: notchHeight
            )
        case .capsLock(let showLabel):
            if showLabel {
                MusicCapsLockLabelView(color: capsLockTintMode.color)
            } else {
                spectrumView(forceSpectrum: true)
            }
        case .focus:
            spectrumView(forceSpectrum: true)
        case .recording:
            spectrumView(forceSpectrum: true, trailingInset: 6)
        case .extensionPayload(let payload):
            ExtensionMusicWingView(payload: payload, notchHeight: notchHeight, trailingWidth: trailingWidth)
        case .shelf(let count):
            // File count badge: bold white number, like a minimal pill
            Text("\(count)")
                .font(.system(.callout, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .contentTransition(.numericText(countsDown: false))
                .animation(.smooth(duration: 0.3), value: count)
                .frame(alignment: .center)
        case .none:
            spectrumView(
                forceSpectrum: false,
                enableClosedPlayPauseOverlay: shouldShowClosedMusicWaveformPlayPauseOverlay(for: secondary)
            )
        }
    }

    @ViewBuilder
    private func SpectrumVisualizer(
        useMusicVisualizer: Bool,
        forceSpectrum: Bool
    ) -> some View {
        let width = CGFloat(Defaults[.visualizerBarCount]) * 4
        if useMusicVisualizer || forceSpectrum {
            Rectangle()
                .fill((Defaults[.coloredSpectrogram] ? Color(nsColor: musicManager.avgColor) : Color.gray).spectrogramGradient())
                .frame(width: 50, alignment: .center)
                .matchedGeometryEffect(id: "spectrum", in: albumArtNamespace)
                .mask {
                    AudioVisualizerView(isPlaying: $musicManager.isPlaying)
                        .frame(width: width, height: 12)
                }
        }
    }

    @ViewBuilder
    private func spectrumView(
        forceSpectrum: Bool,
        trailingInset: CGFloat = 0,
        enableClosedPlayPauseOverlay: Bool = false
    ) -> some View {
        if useMusicVisualizer || forceSpectrum {
            SpectrumVisualizer(useMusicVisualizer: useMusicVisualizer, forceSpectrum: forceSpectrum)
                .blur(radius: (enableClosedPlayPauseOverlay && isHoveringClosedMusicWaveformControl) ? 2.4 : 0)
                .overlay {
                    if enableClosedPlayPauseOverlay {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black.opacity(isHoveringClosedMusicWaveformControl ? 0.24 : 0.02))

                            AtollCuteIcon(
                                symbolName: musicManager.isPlaying ? "pause.fill" : "play.fill",
                                size: 23,
                                accent: .white,
                                secondary: .cyan,
                                showsPlate: false,
                                animated: isHoveringClosedMusicWaveformControl
                            )
                            .opacity(isHoveringClosedMusicWaveformControl ? 0.98 : 0.0)
                            .contentTransition(.symbolEffect(.replace))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .allowsHitTesting(false)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.trailing, trailingInset)
                .animation(.smooth(duration: 0.16), value: isHoveringClosedMusicWaveformControl)
                .animation(.smooth(duration: 0.2), value: musicManager.isPlaying)
        } else {
            LottieAnimationView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var timerAccentColor: Color {
        switch timerIconColorMode {
        case .adaptive:
            if let presetId = timerManager.activePresetId,
               let preset = timerPresets.first(where: { $0.id == presetId }) {
                return preset.color
            }
            return timerManager.timerColor
        case .solid:
            return timerSolidColor
        }
    }

    private func reminderIconName(for reminder: ReminderLiveActivityManager.ReminderEntry, now: Date) -> String {
        isReminderCritical(reminder, now: now) ? ReminderLiveActivityManager.criticalIconName : ReminderLiveActivityManager.standardIconName
    }

    private func isReminderCritical(_ reminder: ReminderLiveActivityManager.ReminderEntry, now: Date) -> Bool {
        let window = TimeInterval(Defaults[.reminderSneakPeekDuration])
        guard window > 0 else { return false }
        let remaining = reminder.event.start.timeIntervalSince(now)
        return remaining > 0 && remaining <= window
    }

    private func extensionSecondaryPayloadID(for secondary: MusicSecondaryLiveActivity?) -> String? {
        guard case let .extensionPayload(payload) = secondary else { return nil }
        return payload.id
    }

    private func resolvedExtensionMusicPayload() -> ExtensionLiveActivityPayload? {
        let candidates = extensionLiveActivityManager.sortedActivities(for: true)
        guard let payload = candidates.first else {
            ExtensionRoutingDiagnostics.shared.logSuppression(
                .music,
                reason: "no eligible coexistence payloads",
                pendingCount: candidates.count
            )
            ExtensionRoutingDiagnostics.shared.reset(.music)
            return nil
        }

        guard enableExtensionLiveActivities else {
            ExtensionRoutingDiagnostics.shared.logSuppression(
                .music,
                reason: "feature toggle disabled",
                pendingCount: candidates.count
            )
            return nil
        }

        guard closedMusicContentEnabled else {
            ExtensionRoutingDiagnostics.shared.logSuppression(
                .music,
                reason: "music content disabled",
                pendingCount: candidates.count
            )
            return nil
        }

        guard vm.notchState == .closed else {
            ExtensionRoutingDiagnostics.shared.logSuppression(
                .music,
                reason: "notch is \(vm.notchState)",
                pendingCount: candidates.count
            )
            return nil
        }

        guard !vm.hideOnClosed else {
            ExtensionRoutingDiagnostics.shared.logSuppression(
                .music,
                reason: "hideOnClosed engaged (fullscreen)",
                pendingCount: candidates.count
            )
            return nil
        }

        guard !lockScreenManager.isLocked else {
            ExtensionRoutingDiagnostics.shared.logSuppression(
                .music,
                reason: "lock screen currently active",
                pendingCount: candidates.count
            )
            return nil
        }

        guard !isMusicHUDDeferredAfterUnlock else {
            ExtensionRoutingDiagnostics.shared.logSuppression(
                .music,
                reason: "waiting for lock screen unlock animation to finish",
                pendingCount: candidates.count
            )
            return nil
        }

        guard coordinator.musicLiveActivityEnabled else {
            ExtensionRoutingDiagnostics.shared.logSuppression(
                .music,
                reason: "music live activity disabled in settings",
                pendingCount: candidates.count
            )
            return nil
        }

        ExtensionRoutingDiagnostics.shared.logDisplay(.music, payload: payload)
        return payload
    }

    private func resolvedExtensionStandalonePayload(excluding musicPayloadID: String?) -> ExtensionLiveActivityPayload? {
        let baseCandidates = extensionLiveActivityManager.sortedActivities()
        guard !baseCandidates.isEmpty else {
            ExtensionRoutingDiagnostics.shared.logSuppression(
                .standalone,
                reason: "no active extension payloads",
                pendingCount: 0
            )
            ExtensionRoutingDiagnostics.shared.reset(.standalone)
            return nil
        }

        let candidates = baseCandidates.filter { $0.id != musicPayloadID }
        guard let payload = candidates.first else {
            if let musicPayloadID {
                ExtensionRoutingDiagnostics.shared.logSuppression(
                    .standalone,
                    reason: "all pending payloads are paired with music (\(musicPayloadID))",
                    pendingCount: baseCandidates.count
                )
            } else {
                ExtensionRoutingDiagnostics.shared.logSuppression(
                    .standalone,
                    reason: "no standalone payloads after filtering",
                    pendingCount: baseCandidates.count
                )
                ExtensionRoutingDiagnostics.shared.reset(.standalone)
            }
            return nil
        }

        guard enableExtensionLiveActivities else {
            ExtensionRoutingDiagnostics.shared.logSuppression(
                .standalone,
                reason: "feature toggle disabled",
                pendingCount: candidates.count
            )
            return nil
        }

        guard vm.notchState == .closed else {
            ExtensionRoutingDiagnostics.shared.logSuppression(
                .standalone,
                reason: "notch is \(vm.notchState)",
                pendingCount: candidates.count
            )
            return nil
        }

        guard !vm.hideOnClosed else {
            ExtensionRoutingDiagnostics.shared.logSuppression(
                .standalone,
                reason: "hideOnClosed engaged (fullscreen)",
                pendingCount: candidates.count
            )
            return nil
        }

        guard !lockScreenManager.isLocked else {
            ExtensionRoutingDiagnostics.shared.logSuppression(
                .standalone,
                reason: "lock screen currently active",
                pendingCount: candidates.count
            )
            return nil
        }

        guard vm.effectiveClosedNotchHeight > 0 else {
            ExtensionRoutingDiagnostics.shared.logSuppression(
                .standalone,
                reason: "effective notch height is \(vm.effectiveClosedNotchHeight)",
                pendingCount: candidates.count
            )
            return nil
        }

        guard !isCurrentScreenExpansionVisible else {
            ExtensionRoutingDiagnostics.shared.logSuppression(
                .standalone,
                reason: "expanding view \(String(describing: currentScreenExpansionType ?? coordinator.expandingView.type)) visible",
                pendingCount: candidates.count
            )
            return nil
        }

        ExtensionRoutingDiagnostics.shared.logDisplay(.standalone, payload: payload)
        return payload
    }

    private func extensionStandaloneLayout(for payload: ExtensionLiveActivityPayload, notchHeight: CGFloat, isHovering: Bool) -> ExtensionStandaloneLayout {
        let outerHeight = notchHeight
        let contentHeight = max(0, notchHeight - (isHovering ? 0 : 12))
        let leadingWidth = max(contentHeight, 44)
        let centerWidth: CGFloat = max(vm.closedNotchSize.width + (isHovering ? 8 : 0), 96)
        let trailingWidth = ExtensionLayoutMetrics.trailingWidth(
            for: payload,
            baseWidth: leadingWidth,
            maxWidth: leadingWidth + centerWidth * 0.6
        )
        let totalWidth = leadingWidth + centerWidth + trailingWidth
        return ExtensionStandaloneLayout(
            totalWidth: totalWidth,
            outerHeight: outerHeight,
            contentHeight: contentHeight,
            leadingWidth: leadingWidth,
            centerWidth: centerWidth,
            trailingWidth: trailingWidth
        )
    }

    @MainActor
    private final class ExtensionRoutingDiagnostics {
        static let shared = ExtensionRoutingDiagnostics()

        enum Channel: Hashable {
            case music
            case standalone

            var label: String {
                switch self {
                case .music:
                    return "music pairing"
                case .standalone:
                    return "standalone notch"
                }
            }
        }

        private var lastMessages: [Channel: String] = [:]

        func logSuppression(_ channel: Channel, reason: String, pendingCount: Int) {
            log("Extension \(channel.label) suppressed: \(reason) (pending: \(pendingCount))", channel: channel)
        }

        func logDisplay(_ channel: Channel, payload: ExtensionLiveActivityPayload) {
            log("Extension \(channel.label) showing \(payload.descriptor.id) from \(payload.bundleIdentifier)", channel: channel)
        }

        func reset(_ channel: Channel) {
            lastMessages.removeValue(forKey: channel)
        }

        private func log(_ message: String, channel: Channel) {
            guard Defaults[.extensionDiagnosticsLoggingEnabled] else { return }
            guard lastMessages[channel] != message else { return }
            lastMessages[channel] = message
            Logger.log(message, category: .extensions)
        }
    }
    
    @ViewBuilder
    var dragDetector: some View {
        if lockScreenManager.isLocked {
            EmptyView()
        } else if Defaults[.dynamicShelf] && !Defaults[.enableMinimalisticUI] {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onDrop(of: [.data], isTargeted: $vm.dragDetectorTargeting) { _ in true }
                .onChange(of: vm.anyDropZoneTargeting) { _, isTargeted in
                    if isTargeted, vm.notchState == .closed {
                        coordinator.currentView = .shelf
                        openNotch()
                    } else if !isTargeted {
                        if vm.dropEvent {
                            vm.dropEvent = false
                            return
                        }

                        vm.dropEvent = false
                        if !shouldPreventAutoClose() {
                            vm.close()
                        }
                    }
                }
        } else {
            EmptyView()
        }
    }

    // MARK: - Private Methods
    private func openNotch() {
        vm.open()
        recenterMainIslandAfterOpen()
    }

    private func recenterMainIslandAfterOpen() {
        for delay in [0.20, 0.80, 1.50] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                recenterVisibleMainIslandWindow()
            }
        }
    }

    private func recenterVisibleMainIslandWindow() {
        guard let appDelegate = AppDelegate.shared else { return }
        let window = Defaults[.showOnAllDisplays]
            ? appDelegate.windows.values.first(where: { $0.isVisible })
            : appDelegate.window
        guard let window, window.isVisible else { return }
        let screen = window.screen
            ?? NSScreen.screens.first(where: { $0.frame.intersects(window.frame) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let screen else { return }
        let screenFrame = screen.frame
        let topBleed = notchTopScreenBleed(for: screen.localizedName)
        let width = window.frame.width.rounded()
        let height = window.frame.height.rounded()
        let x = (screenFrame.midX - width / 2).rounded()
        let y = (screenFrame.maxY + topBleed - height).rounded()
        if abs(window.frame.origin.x - x) > 0.5 || abs(window.frame.origin.y - y) > 0.5 {
            window.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
            window.orderFrontRegardless()
        }
    }

    private func shouldShowClosedMusicWaveformPlayPauseOverlay(for secondary: MusicSecondaryLiveActivity?) -> Bool {
        guard secondary == nil else { return false }
        return isClosedMusicGestureContext && !Defaults[.openNotchOnHover]
    }

    private var isClosedMusicGestureContext: Bool {
        vm.notchState == .closed
            && coordinator.musicLiveActivityEnabled
            && closedMusicContentEnabled
            && !vm.hideOnClosed
            && !lockScreenManager.isLocked
            && !isMusicHUDDeferredAfterUnlock
            && !isCurrentScreenExpansionVisible
            && (!musicManager.isPlayerIdle || musicManager.bundleIdentifier != nil)
            && !coordinator.firstLaunch
    }

    private func handleClosedMusicWaveformTapIfNeeded() -> Bool {
        guard shouldShowClosedMusicWaveformPlayPauseOverlay(for: nil),
              isHoveringClosedMusicWaveformControl else {
            return false
        }

        if Defaults[.enableHaptics] {
            triggerHapticIfAllowed()
        }
        musicManager.playPause()
        return true
    }

    private func hiddenHoverActivationContainsMouse(_ location: NSPoint = NSEvent.mouseLocation) -> Bool {
        guard let screen = NSScreen.screens.first(where: { $0.localizedName == currentScreenName }) else {
            return false
        }

        let horizontalPadding: CGFloat = 8
        let activationWidth = vm.closedNotchSize.width + horizontalPadding * 2
        let activationHeight = max(vm.closedNotchSize.height + zeroHeightHoverPadding, 14)

        let activationRect = CGRect(
            x: screen.frame.midX - activationWidth / 2,
            y: screen.frame.maxY - activationHeight,
            width: activationWidth,
            height: activationHeight
        )

        return activationRect.contains(location)
    }

    /// Cancels every long-lived task / event monitor this view owns. Called from
    /// `.onDisappear` and from `vm.onViewTeardown` on window close. Idempotent.
    private func performViewTeardown() {
        hoverTask?.cancel()
        stopHoverClickMonitor()
        removeStickyTerminalClickMonitor()
        stopHiddenEdgeHoverPolling()
        cancelMusicControlWindowSync()
        hideMusicControlWindow()
        cancelMusicControlVisibilityTimer()
        clearMusicControlVisibilityDeadline()
        musicControlSuppressionTask?.cancel()
        isHoveringClosedMusicWaveformControl = false
    }

    private func startHiddenEdgeHoverPolling() {
        guard hiddenEdgeHoverPollingTask == nil else { return }

        hiddenEdgeHoverPollingTask = Task { @MainActor in
            while !Task.isCancelled {
                if self.shouldUseHiddenEdgeHoverPolling {
                    let hovering = self.hiddenHoverActivationContainsMouse()
                    if hovering != self.isHovering {
                        self.handleHover(hovering)
                    }
                } else if self.isHovering && self.interactionsEnabled {
                    let stillInside = self.vm.notchState == .open
                        ? self.isPointInsideNotchWindow()
                        : self.isMouseOverClosedNotchHitArea()
                    if !stillInside {
                        self.hoverTask?.cancel()
                        self.stopHoverClickMonitor()
                        self.finishHoverExit()
                    }
                }

                try? await Task.sleep(for: .milliseconds(self.hiddenEdgeHoverPollingIntervalMs()))
            }

            self.hiddenEdgeHoverPollingTask = nil
        }
    }

    private func hiddenEdgeHoverPollingIntervalMs() -> Int {
        if shouldUseHiddenEdgeHoverPolling {
            return 50
        }
        if isHovering && interactionsEnabled {
            return 100
        }
        return 1_000
    }

    private func stopHiddenEdgeHoverPolling() {
        hiddenEdgeHoverPollingTask?.cancel()
        hiddenEdgeHoverPollingTask = nil
    }

    private func startHoverClickMonitor() {
        guard Defaults[.openNotchOnHover] else { return }
        guard hoverClickMonitor == nil else { return }

        let handleClick: @Sendable () -> Void = { [weak vm, weak lockScreenManager] in
            Task { @MainActor in
                guard let vm, let lockScreenManager else { return }
                guard !lockScreenManager.isLocked else { return }
                guard vm.notchState == .closed else { return }
                guard !self.coordinator.isHoverOpenSuppressed else { return }
                guard self.isHovering else { return }
                guard !self.handleClosedMusicWaveformTapIfNeeded() else { return }
                if Defaults[.enableHaptics] {
                    self.triggerHapticIfAllowed()
                }
                self.openNotch()
            }
        }

        // Global monitor catches clicks outside the app window (e.g. when
        // the cursor is at the very top screen edge and the click goes to
        // the system rather than our panel).
        hoverClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { _ in
            handleClick()
        }

        // Local monitor catches clicks that DO hit our window — at the
        // screen edge SwiftUI's .onTapGesture may not fire reliably, but
        // the NSEvent local monitor will.
        hoverClickLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { event in
            handleClick()
            return event
        }
    }

    private func stopHoverClickMonitor() {
        if let hoverClickMonitor {
            NSEvent.removeMonitor(hoverClickMonitor)
            self.hoverClickMonitor = nil
        }
        if let hoverClickLocalMonitor {
            NSEvent.removeMonitor(hoverClickLocalMonitor)
            self.hoverClickLocalMonitor = nil
        }
    }

    /// Installs the global outside-click monitor whenever the Terminal tab is open
    /// (e.g. keyboard-opened terminal), regardless of sticky mode.
    ///
    /// Sticky mode only controls whether the terminal closes when the cursor leaves
    /// the notch (see `shouldPreventAutoClose`).  An outside click should always close
    /// the terminal — this covers the case where the terminal is opened via the
    /// shortcut and the cursor never enters the notch, so there's no hover-out event
    /// to trigger the normal auto-close.
    ///
    /// While the cursor is hovering inside the notch, hover handling owns close
    /// behavior, so the monitor is not installed; it is re-synced on hover-out.
    private func syncStickyTerminalOutsideClickMonitor() {
        guard vm.notchState == .open, coordinator.currentView == .terminal, !isHovering else {
            removeStickyTerminalClickMonitor()
            return
        }
        installStickyTerminalClickMonitor()
    }

    private func installStickyTerminalClickMonitor() {
        guard stickyTerminalClickMonitor == nil else { return }
        stickyTerminalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak vm] _ in
            Task { @MainActor in
                guard let vm, vm.notchState == .open else { return }
                let clickLocation = NSEvent.mouseLocation
                if self.isPointInsideNotchWindow(clickLocation) {
                    return
                }
                vm.close()
            }
        }
    }

    private func removeStickyTerminalClickMonitor() {
        if let stickyTerminalClickMonitor {
            NSEvent.removeMonitor(stickyTerminalClickMonitor)
            self.stickyTerminalClickMonitor = nil
        }
    }

    // MARK: - Hover Management
    
    /// Handle hover state changes with debouncing
    private func handleHover(_ hovering: Bool) {
        // Ignore false hover-exit when the cursor is parked on the screen's top pixel.
        if !hovering, shouldRetainHoverAtScreenTopEdge() {
            return
        }

        hoverTask?.cancel()

        if hovering {
            startHoverClickMonitor()
            removeStickyTerminalClickMonitor()
        } else {
            stopHoverClickMonitor()
            if isHoveringClosedMusicWaveformControl {
                withAnimation(.smooth(duration: 0.16)) {
                    isHoveringClosedMusicWaveformControl = false
                }
            }
        }

        if hovering {
            withAnimation(.bouncy.speed(1.2)) {
                isHovering = true
            }

            if vm.notchState == .closed && Defaults[.enableHaptics] {
                triggerHapticIfAllowed()
            }

            let shouldFocusTimerTab = enableTimerFeature && timerDisplayMode == .tab && timerManager.isTimerActive && !enableMinimalisticUI

            guard vm.notchState == .closed,
                !isSneakPeekVisibleOnCurrentScreen,
                (Defaults[.openNotchOnHover] || shouldFocusTimerTab) else { return }

            hoverTask = Task {
                try? await Task.sleep(for: .seconds(Defaults[.minimumHoverDuration]))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    guard self.vm.notchState == .closed,
                          self.isHovering,
                          !self.isSneakPeekVisibleOnCurrentScreen,
                          !self.coordinator.isHoverOpenSuppressed else { return }

                    if shouldFocusTimerTab {
                        withAnimation(.smooth) {
                            self.coordinator.currentView = .timer
                        }
                    }
                    self.openNotch()
                }
            }
        } else {
            hoverTask = Task {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    if self.shouldRetainHoverAtScreenTopEdge() {
                        return
                    }
                    self.finishHoverExit()
                }
            }
        }
    }

    private func finishHoverExit() {
        withAnimation(.bouncy.speed(1.2)) {
            isHovering = false
        }

        if vm.notchState == .open && !shouldPreventAutoClose() {
            vm.close()
        } else if vm.notchState == .open
                    && Defaults[.terminalStickyMode]
                    && coordinator.currentView == .terminal {
            // Re-sync monitor state through one code path to avoid
            // monitor lifecycle races between hover and state updates.
            syncStickyTerminalOutsideClickMonitor()
        }
    }

    private func shouldRetainHoverAtScreenTopEdge(_ location: NSPoint = NSEvent.mouseLocation) -> Bool {
        guard let screen = NSScreen.screens.first(where: { $0.localizedName == currentScreenName }) else {
            return false
        }
        guard isHovering || vm.notchState == .open else { return false }
        guard location.y >= screen.frame.maxY - 1.5 else { return false }

        if vm.notchState == .open {
            return isPointInsideNotchWindow(location)
        }
        return isMouseOverClosedNotchHitArea(location)
    }

    private func isMouseOverClosedNotchHitArea(_ location: NSPoint = NSEvent.mouseLocation) -> Bool {
        guard let screen = NSScreen.screens.first(where: { $0.localizedName == currentScreenName }) else {
            return false
        }

        let height = vm.effectiveClosedNotchHeight + (isHovering ? 8 : 0) + 6
        let width = max(vm.closedNotchSize.width + (isHovering ? 8 : 0), 96) + 24
        let minX = screen.frame.midX - width / 2
        let minY = screen.frame.maxY - height

        return location.x >= minX && location.x <= minX + width
            && location.y >= minY && location.y <= screen.frame.maxY
    }

    private func isPointInsideNotchWindow(_ point: CGPoint = NSEvent.mouseLocation) -> Bool {
        if let appDelegate = AppDelegate.shared {
            if Defaults[.showOnAllDisplays] {
                return appDelegate.windows.values.contains(where: { frameContainsPointIncludingTopEdge($0.frame, point) })
            }
            if let window = appDelegate.window {
                return frameContainsPointIncludingTopEdge(window.frame, point)
            }
        }

        return NSApp.windows.contains(where: { frameContainsPointIncludingTopEdge($0.frame, point) })
    }

    /// `CGRect.contains` is half-open on max edges; the top pixel needs inclusive maxY.
    private func frameContainsPointIncludingTopEdge(_ frame: CGRect, _ point: CGPoint) -> Bool {
        point.x >= frame.minX && point.x <= frame.maxX
            && point.y >= frame.minY && point.y <= frame.maxY
    }
    
    // Helper function to check if any popovers are active
    private func hasAnyActivePopovers() -> Bool {
     return vm.isBatteryPopoverActive || 
         vm.isClipboardPopoverActive || 
         vm.isColorPickerPopoverActive || 
         vm.isStatsPopoverActive ||
         vm.isTimerPopoverActive ||
         vm.isMediaOutputPopoverActive ||
         vm.isReminderPopoverActive
    }

    private func shouldPreventAutoClose() -> Bool {
        // Dragging a shelf item out necessarily takes the cursor off the notch.
        // Without this, the hover-exit timer closes the panel mid-drag, tearing
        // down the NSView that is acting as the drag source and cancelling the
        // session — an independent second cause of "drag-out doesn't work".
        coordinator.firstLaunch || hasAnyActivePopovers() || vm.isAutoCloseSuppressed || ShelfSelectionModel.shared.isDragging || ClipboardManager.shared.isDraggingItem || SharingStateManager.shared.preventNotchClose || (Defaults[.terminalStickyMode] && coordinator.currentView == .terminal)
    }
    
    // Helper to prevent rapid haptic feedback
    private func triggerHapticIfAllowed() {
        let now = Date()
        if now.timeIntervalSince(lastHapticTime) > 0.3 { // Minimum 300ms between haptics
            haptics.toggle()
            lastHapticTime = now
        }
    }
    
    // Helper to check if stats tab has 4+ graphs (needs expanded height)
    private func enabledStatsGraphCount() -> Int {
        var enabledCount = 0
        if showCpuGraph { enabledCount += 1 }
        if showMemoryGraph { enabledCount += 1 }
        if showGpuGraph { enabledCount += 1 }
        if showNetworkGraph { enabledCount += 1 }
        if showDiskGraph { enabledCount += 1 }
        return enabledCount
    }

    private func statsRowCount() -> Int {
        let count = enabledStatsGraphCount()
        if count == 0 { return 0 }
        return count <= 3 ? 1 : 2
    }

    private func currentExtensionTabPayload() -> ExtensionNotchExperiencePayload? {
        guard Defaults[.enableThirdPartyExtensions],
              Defaults[.enableExtensionNotchExperiences],
              Defaults[.enableExtensionNotchTabs] else {
            return nil
        }
        if let selectedID = coordinator.selectedExtensionExperienceID,
           let payload = extensionNotchExperienceManager.payload(experienceID: selectedID) {
            return payload
        }
        return extensionNotchExperienceManager.highestPriorityTabPayload()
    }

    private func extensionTabPreferredHeight(baseSize: CGSize) -> CGFloat? {
        guard let preferred = currentExtensionTabPayload()?.descriptor.tab?.preferredHeight else {
            return nil
        }
        let minHeight = baseSize.height
        let maxHeight = baseSize.height + statsAdditionalRowHeight
        return min(max(preferred, minHeight), maxHeight)
    }

    // Estimate the height required for minimalistic overrides (notably web content) and clamp it to the notch bounds.
    private func extensionMinimalisticPreferredHeight(baseSize: CGSize) -> CGFloat? {
        guard let configuration = extensionNotchExperienceManager.minimalisticReplacementPayload()?.descriptor.minimalistic else {
            return nil
        }

        let minHeight = baseSize.height
        let maxHeight = baseSize.height + statsAdditionalRowHeight

        var contentHeight: CGFloat = 0
        var blockCount = 0

        if configuration.headline != nil {
            contentHeight += 24
            blockCount += 1
        }

        if configuration.subtitle != nil {
            contentHeight += 20
            blockCount += 1
        }

        if !configuration.sections.isEmpty {
            let sectionEstimate: CGFloat = 98
            contentHeight += CGFloat(configuration.sections.count) * sectionEstimate
            blockCount += configuration.sections.count
        }

        if let webDescriptor = configuration.webContent {
            contentHeight += webDescriptor.preferredHeight
            blockCount += 1
        }

        guard blockCount > 0 else { return nil }

        let spacingAllowance = CGFloat(max(blockCount - 1, 0)) * 16
        let topPadding: CGFloat = 10
        let bottomPadding: CGFloat = configuration.webContent == nil ? 10 : 0
        let estimatedHeight = contentHeight + spacingAllowance + topPadding + bottomPadding

        let clampedHeight = min(max(estimatedHeight, minHeight), maxHeight)
        return clampedHeight > minHeight ? clampedHeight : nil
    }
    
    // MARK: - Gesture Handling
    
    private func handleDownGesture(translation: CGFloat, phase: NSEvent.Phase) {
        handleScrollGesture(isDownward: true, translation: translation, phase: phase)
    }
    
    private func handleUpGesture(translation: CGFloat, phase: NSEvent.Phase) {
        handleScrollGesture(isDownward: false, translation: translation, phase: phase)
    }

    private func handleScrollGesture(isDownward: Bool, translation: CGFloat, phase: NSEvent.Phase) {
        let reverse = Defaults[.reverseScrollGestures]
        let shouldOpen = isDownward ? !reverse : reverse

        if shouldOpen {
            handleOpenScrollGesture(translation: translation, phase: phase)
        } else {
            guard Defaults[.closeGestureEnabled] else { return }
            handleCloseScrollGesture(translation: translation, phase: phase)
        }
    }

    private func handleOpenScrollGesture(translation: CGFloat, phase: NSEvent.Phase) {
        guard vm.notchState == .closed else { return }

        withAnimation(.smooth) {
            gestureProgress = (translation / Defaults[.gestureSensitivity]) * 20
        }

        if phase == .ended {
            withAnimation(.smooth) {
                gestureProgress = .zero
            }
        }

        if translation > Defaults[.gestureSensitivity] {
            if Defaults[.enableHaptics] {
                triggerHapticIfAllowed()
            }
            withAnimation(.smooth) {
                gestureProgress = .zero
            }
            openNotch()
        }
    }

    private func handleCloseScrollGesture(translation: CGFloat, phase: NSEvent.Phase) {
        guard vm.notchState == .open, !vm.isHoveringCalendar, !vm.isScrollGestureActive else { return }

        withAnimation(.smooth) {
            gestureProgress = (translation / Defaults[.gestureSensitivity]) * -20
        }

        if phase == .ended {
            withAnimation(.smooth) {
                gestureProgress = .zero
            }
        }

        if translation > Defaults[.gestureSensitivity] {
            withAnimation(.smooth) {
                gestureProgress = .zero
                isHovering = false
            }
            vm.close()

            if Defaults[.enableHaptics] {
                triggerHapticIfAllowed()
            }
        }
    }

    private func handleSkipGesture(direction: MusicManager.SkipDirection, translation: CGFloat, phase: NSEvent.Phase) {
        if phase == .ended {
            skipGestureActiveDirection = nil
            return
        }

        guard canPerformSkipGesture() else {
            skipGestureActiveDirection = nil
            return
        }

        if skipGestureActiveDirection == nil && translation > Defaults[.gestureSensitivity] {
            let effectiveDirection: MusicManager.SkipDirection
            if Defaults[.reverseSwipeGestures] {
                effectiveDirection = direction == .forward ? .backward : .forward
            } else {
                effectiveDirection = direction
            }
            skipGestureActiveDirection = effectiveDirection

            if Defaults[.enableHaptics] {
                triggerHapticIfAllowed()
            }

            musicManager.handleSkipGesture(direction: effectiveDirection)
        }
    }

    private func canPerformSkipGesture() -> Bool {
        let canSkipInOpenHome = vm.notchState == .open && coordinator.currentView == .home
        let canSkipInClosedMusic = !Defaults[.openNotchOnHover] && isClosedMusicGestureContext

        return enableHorizontalMusicGestures
            && (canSkipInOpenHome || canSkipInClosedMusic)
            && (!musicManager.isPlayerIdle || musicManager.bundleIdentifier != nil)
            && !lockScreenManager.isLocked
            && !hasAnyActivePopovers()
            && !vm.isHoveringCalendar
            && !vm.isScrollGestureActive
    }

    private func handleMusicControlPlaybackChange(isPlaying: Bool) {
        guard musicControlWindowEnabled else { return }

        if isPlaying {
            clearMusicControlVisibilityDeadline()
            requestMusicControlWindowSyncIfHidden()
        } else {
            extendMusicControlVisibilityAfterPause()
        }
    }

    private func handleMusicControlIdleChange(isIdle: Bool) {
        guard musicControlWindowEnabled else { return }

        if isIdle {
            if musicControlVisibilityDeadline == nil {
                extendMusicControlVisibilityAfterPause()
            }
        } else if musicManager.isPlaying {
            clearMusicControlVisibilityDeadline()
        }
    }

    private func handleStandardMediaControlsAvailabilityChange() {
        guard musicControlWindowEnabled else {
            hideMusicControlWindow()
            return
        }

        if standardMediaControlsActive {
            if musicManager.isPlaying || !musicManager.isPlayerIdle {
                clearMusicControlVisibilityDeadline()
            }
            enqueueMusicControlWindowSync(forceRefresh: true)
        } else {
            cancelMusicControlWindowSync()
            hideMusicControlWindow()
            clearMusicControlVisibilityDeadline()
            hasPendingMusicControlSync = false
            pendingMusicControlForceRefresh = false
        }
    }

    private func extendMusicControlVisibilityAfterPause() {
        let deadline = Date().addingTimeInterval(musicControlPauseGrace)
        musicControlVisibilityDeadline = deadline
        scheduleMusicControlVisibilityCheck(deadline: deadline)
        requestMusicControlWindowSyncIfHidden()
    }

    private func clearMusicControlVisibilityDeadline() {
        musicControlVisibilityDeadline = nil
        cancelMusicControlVisibilityTimer()
    }

    private func scheduleMusicControlVisibilityCheck(deadline: Date) {
        cancelMusicControlVisibilityTimer()

        let interval = max(0, deadline.timeIntervalSinceNow)

        musicControlHideTask = Task.detached(priority: .background) { [interval] in
            if interval > 0 {
                let nanoseconds = UInt64(interval * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)
            }

            guard !Task.isCancelled else { return }

            await MainActor.run {
                if let currentDeadline = musicControlVisibilityDeadline, currentDeadline <= Date() {
                    musicControlVisibilityDeadline = nil
                }

                enqueueMusicControlWindowSync(forceRefresh: false)

                musicControlHideTask = nil
            }
        }
    }

    private func cancelMusicControlVisibilityTimer() {
        musicControlHideTask?.cancel()
        musicControlHideTask = nil
    }

    private func musicControlVisibilityIsActive() -> Bool {
        if musicManager.isPlaying {
            return true
        }

        guard let deadline = musicControlVisibilityDeadline else { return false }
        return Date() <= deadline
    }

    private func suppressMusicControlWindowUpdates() {
        isMusicControlWindowSuppressed = true
        musicControlSuppressionTask?.cancel()
        musicControlSuppressionTask = nil
    }

    private func releaseMusicControlWindowUpdates(after delay: TimeInterval) {
        musicControlSuppressionTask?.cancel()
        musicControlSuppressionTask = Task { [delay] in
            if delay > 0 {
                let nanoseconds = UInt64(delay * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)
            }

            guard !Task.isCancelled else { return }

            await MainActor.run {
                if vm.notchState == .closed && !lockScreenManager.isLocked && !isMusicHUDDeferredAfterUnlock {
                    isMusicControlWindowSuppressed = false
                    triggerPendingMusicControlSyncIfNeeded()
                } else {
                    isMusicControlWindowSuppressed = true
                }
                musicControlSuppressionTask = nil
            }
        }
    }

    private func triggerPendingMusicControlSyncIfNeeded() {
        guard hasPendingMusicControlSync else { return }

        let shouldForce = pendingMusicControlForceRefresh
        hasPendingMusicControlSync = false
        pendingMusicControlForceRefresh = false

        logMusicControlEvent("Flushing pending floating window sync (force: \(shouldForce))")
        scheduleMusicControlWindowSync(forceRefresh: shouldForce, bypassSuppression: true)
    }

    private func shouldDeferMusicControlSync() -> Bool {
        vm.notchState != .closed
            || lockScreenManager.isLocked
            || isMusicHUDDeferredAfterUnlock
            || isMusicControlWindowSuppressed
    }

    private func enqueueMusicControlWindowSync(forceRefresh: Bool, delay: TimeInterval = 0) {
        if shouldDeferMusicControlSync() {
            hasPendingMusicControlSync = true
            if forceRefresh {
                pendingMusicControlForceRefresh = true
            }
            logMusicControlEvent("Queued floating window sync (force: \(forceRefresh)) while deferred")
            return
        }

        logMusicControlEvent("Scheduling floating window sync (force: \(forceRefresh), delay: \(delay))")
        scheduleMusicControlWindowSync(forceRefresh: forceRefresh, delay: delay)
    }

    private func shouldShowMusicControlWindow() -> Bool {
        guard musicControlWindowEnabled,
              coordinator.musicLiveActivityEnabled,
              standardMediaControlsActive,
              vm.notchState == .closed,
              !vm.hideOnClosed,
              !lockScreenManager.isLocked,
              !isMusicHUDDeferredAfterUnlock,
              !isMusicControlWindowSuppressed else {
            return false
        }

        return musicControlVisibilityIsActive()
    }

    private func scheduleMusicControlWindowSync(forceRefresh: Bool, delay: TimeInterval = 0, bypassSuppression: Bool = false) {
        #if os(macOS)
        cancelMusicControlWindowSync()

        guard shouldShowMusicControlWindow() else {
            hasPendingMusicControlSync = false
            pendingMusicControlForceRefresh = false
            hideMusicControlWindow()
            return
        }

        if !bypassSuppression && (isMusicControlWindowSuppressed || lockScreenManager.isLocked || isMusicHUDDeferredAfterUnlock) {
            hasPendingMusicControlSync = true
            if forceRefresh {
                pendingMusicControlForceRefresh = true
            }
            return
        }

        hasPendingMusicControlSync = false
        pendingMusicControlForceRefresh = false

        let syncDelay = max(0, delay)

        pendingMusicControlTask = Task.detached(priority: .userInitiated) { [forceRefresh, syncDelay] in
            if syncDelay > 0 {
                let nanoseconds = UInt64(syncDelay * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)
            }

            guard !Task.isCancelled else { return }

            await MainActor.run {
                if shouldShowMusicControlWindow() {
                    logMusicControlEvent("Running floating window sync (force: \(forceRefresh))")
                    syncMusicControlWindow(forceRefresh: forceRefresh)
                } else {
                    logMusicControlEvent("Skipping floating window sync (conditions changed)")
                    hideMusicControlWindow()
                }

                pendingMusicControlTask = nil
            }
        }
        #endif
    }

    private func cancelMusicControlWindowSync() {
        pendingMusicControlTask?.cancel()
        pendingMusicControlTask = nil
    }

    #if os(macOS)
    private func currentMusicControlWindowMetrics() -> MusicControlWindowMetrics {
        MusicControlWindowMetrics(
            notchHeight: max(vm.closedNotchSize.height, vm.effectiveClosedNotchHeight),
            notchWidth: vm.closedNotchSize.width + (isHovering ? 8 : 0),
            rightWingWidth: max(0, vm.effectiveClosedNotchHeight - (isHovering ? 0 : 12) + gestureProgress / 2),
            cornerRadius: activeCornerRadiusInsets.closed.bottom,
            spacing: 36
        )
    }

    private func syncMusicControlWindow(forceRefresh: Bool = false) {
        let notchAvailable = vm.effectiveClosedNotchHeight > 0 && vm.closedNotchSize.width > 0
        let targetVisible = shouldShowMusicControlWindow() && notchAvailable

        if targetVisible {
            let metrics = currentMusicControlWindowMetrics()
            if !isMusicControlWindowVisible {
                let didPresent = MusicControlWindowManager.shared.present(using: vm, metrics: metrics)
                isMusicControlWindowVisible = didPresent
            } else if forceRefresh {
                let didRefresh = MusicControlWindowManager.shared.refresh(using: vm, metrics: metrics)
                if !didRefresh {
                    MusicControlWindowManager.shared.hide()
                    isMusicControlWindowVisible = false
                }
            }
        } else if isMusicControlWindowVisible {
            MusicControlWindowManager.shared.hide()
            isMusicControlWindowVisible = false
        }
    }

    private func hideMusicControlWindow() {
        if isMusicControlWindowVisible {
            MusicControlWindowManager.shared.hide()
            isMusicControlWindowVisible = false
        }
    }
    #else
    private func syncMusicControlWindow(forceRefresh: Bool = false) {}

    private func hideMusicControlWindow() {}
    #endif
    
    private func shouldFixSizeForSneakPeek() -> Bool {
        guard isSneakPeekVisibleOnCurrentScreen else { return false }
        let style = resolvedSneakPeekStyle()
        
        // Check for extension sneak peek
        if case .extensionLiveActivity = coordinator.sneakPeek.type {
            return vm.notchState == .closed && style == .standard
        }
        
        // Original logic for other types
        let isMusicSneak = coordinator.sneakPeek.type == .music && vm.notchState == .closed && !vm.hideOnClosed && style == .standard
        let isTimerSneak = coordinator.sneakPeek.type == .timer && !vm.hideOnClosed && style == .standard
        let isReminderSneak = coordinator.sneakPeek.type == .reminder && !vm.hideOnClosed && style == .standard
        let isOtherSneak = coordinator.sneakPeek.type != .music && coordinator.sneakPeek.type != .timer && coordinator.sneakPeek.type != .reminder && vm.notchState == .closed
        
        return isMusicSneak || isTimerSneak || isReminderSneak || isOtherSneak
    }

    private func resolvedSneakPeekStyle() -> SneakPeekStyle {
        if case .extensionLiveActivity = coordinator.sneakPeek.type {
            return .standard
        }
        return coordinator.sneakPeek.styleOverride ?? Defaults[.sneakPeekStyles]
    }
}

private enum MusicSecondaryLiveActivity: Equatable {
    case timer
    case reminder(ReminderLiveActivityManager.ReminderEntry)
    case recording
    case focus(FocusModeType)
    case capsLock(showLabel: Bool)
    case extensionPayload(ExtensionLiveActivityPayload)
    case shelf(count: Int)

    var id: String {
        switch self {
        case .timer:
            return "timer"
        case .reminder(let entry):
            return "reminder-\(entry.id)"
        case .recording:
            return "recording"
        case .focus(let mode):
            return "focus-\(mode.rawValue)"
        case .capsLock(let showLabel):
            return showLabel ? "caps-lock-label" : "caps-lock-icon"
        case .extensionPayload(let payload):
            return "extension-\(payload.id)"
        case .shelf(let count):
            return "shelf-\(count)"
        }
    }
}

private struct MusicTimerSupplementView: View {
    @ObservedObject var timerManager: TimerManager
    let accentColor: Color
    let showsCountdown: Bool
    let showsProgress: Bool
    let progressStyle: TimerProgressStyle
    let notchHeight: CGFloat

    private var clampedProgress: Double {
        min(max(timerManager.progress, 0), 1)
    }

    private var showsRingProgress: Bool {
        showsProgress && progressStyle == .ring
    }

    private var showsBarProgress: Bool {
        showsProgress && progressStyle == .bar
    }

    private var countdownText: String {
        timerManager.formattedRemainingTime()
    }

    private var countdownTextWidth: CGFloat {
        max(1, TimerSupplementMetrics.countdownTextWidth(for: countdownText))
    }

    private var countdownFrameWidth: CGFloat {
        TimerSupplementMetrics.countdownFrameWidth(for: countdownText)
    }

    private var timerNameFrameWidth: CGFloat {
        TimerSupplementMetrics.timerNameFrameWidth(for: timerManager.timerName)
    }

    private var ringDiameter: CGFloat {
        max(min(notchHeight - 4, 26), 20)
    }

    var body: some View {
        HStack(spacing: showsRingProgress && showsCountdown ? 8 : 0) {
            if showsRingProgress {
                ringView
            }

            if showsCountdown {
                countdownStack
            } else if showsBarProgress {
                standaloneBarView
            } else {
                timerNameView
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var countdownStack: some View {
        VStack(alignment: .trailing, spacing: showsBarProgress ? 4 : 0) {
            Text(countdownText)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(timerManager.isOvertime ? .red : .white)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .contentTransition(.numericText())
                .animation(.smooth(duration: 0.25), value: timerManager.remainingTime)
                .frame(width: countdownFrameWidth, alignment: .trailing)

            if showsBarProgress {
                barView(width: countdownTextWidth)
            }
        }
        .padding(.trailing, 2)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var ringView: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.18), lineWidth: 3)
            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.smooth(duration: 0.25), value: clampedProgress)
        }
        .frame(width: ringDiameter, height: ringDiameter)
        .frame(width: max(ringDiameter + 4, 30), height: notchHeight, alignment: .center)
    }

    private var standaloneBarView: some View {
        barView(width: 68)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var timerNameView: some View {
        Text(timerManager.timerName)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.white)
            .lineLimit(1)
            .frame(width: timerNameFrameWidth, alignment: .trailing)
    }

    private func barView(width: CGFloat) -> some View {
        Capsule()
            .fill(Color.white.opacity(0.15))
            .frame(width: width, height: 4)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(accentColor)
                    .frame(width: width * max(0, CGFloat(clampedProgress)), height: 4)
                    .animation(.smooth(duration: 0.25), value: clampedProgress)
            }
    }

}

private struct MusicReminderSupplementView: View {
    let entry: ReminderLiveActivityManager.ReminderEntry
    let now: Date
    let style: ReminderPresentationStyle
    let accent: Color
    let notchHeight: CGFloat

    var body: some View {
        Group {
            switch style {
            case .ringCountdown:
                ringCountdownView
            case .digital:
                digitalCountdownView
            case .minutes:
                minutesCountdownView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
    }

    private var ringCountdownView: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 3)
            Circle()
                .trim(from: 0, to: progressValue)
                .stroke(accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.smooth(duration: 0.25), value: progressValue)
        }
        .frame(width: ringDiameter, height: ringDiameter)
        .frame(width: max(ringDiameter + 4, 26), height: notchHeight, alignment: .center)
    }

    private var digitalCountdownView: some View {
        Text(digitalCountdownText)
            .font(.system(size: 15, weight: .semibold, design: .monospaced))
            .foregroundColor(accent)
            .contentTransition(.numericText())
            .animation(.smooth(duration: 0.25), value: digitalCountdownText)
            .frame(width: digitalFrameWidth, alignment: .trailing)
            .frame(height: notchHeight, alignment: .center)
    }

    private var minutesCountdownView: some View {
        Text(minutesCountdownText)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(accent)
            .frame(width: minutesFrameWidth, alignment: .trailing)
            .frame(height: notchHeight, alignment: .center)
    }

    private var progressValue: Double {
        guard entry.leadTime > 0 else { return 1 }
        let remaining = max(entry.event.start.timeIntervalSince(now), 0)
        let elapsed = entry.leadTime - remaining
        return min(max(elapsed / entry.leadTime, 0), 1)
    }

    private var digitalCountdownText: String {
        ReminderSupplementMetrics.digitalCountdownText(for: entry, now: now)
    }

    private var minutesCountdownText: String {
        ReminderSupplementMetrics.minutesCountdownText(for: entry, now: now)
    }

    private var ringDiameter: CGFloat {
        ReminderSupplementMetrics.ringDiameter(for: notchHeight)
    }

    private var digitalFrameWidth: CGFloat {
        ReminderSupplementMetrics.digitalFrameWidth(for: digitalCountdownText)
    }

    private var minutesFrameWidth: CGFloat {
        ReminderSupplementMetrics.minutesFrameWidth(for: minutesCountdownText)
    }
}

private struct MusicCapsLockLabelView: View {
    let color: Color

    var body: some View {
        Text("Caps Lock")
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(color)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .contentTransition(.opacity)
    }
}

#if canImport(AppKit)
private typealias MusicSupplementFont = NSFont
#elseif canImport(UIKit)
private typealias MusicSupplementFont = UIFont
#endif

private enum TimerSupplementMetrics {
    static func countdownTextWidth(for text: String) -> CGFloat {
        // Measure with a fully monospaced font (matching the `.monospaced` design used
        // to render) so hour-format times like 1:00:00 aren't under-measured and clipped.
        musicMeasureText(text, font: MusicSupplementFont.monospacedSystemFont(ofSize: 13, weight: .semibold))
    }

    static func countdownFrameWidth(for text: String) -> CGFloat {
        max(countdownTextWidth(for: text) + 16, 72)
    }

    static func timerNameFrameWidth(for text: String) -> CGFloat {
        guard !text.isEmpty else { return 64 }
        let width = musicMeasureText(text, font: MusicSupplementFont.systemFont(ofSize: 12, weight: .medium))
        return max(width + 14, 64)
    }
}

private enum ReminderSupplementMetrics {
    static func digitalCountdownText(for entry: ReminderLiveActivityManager.ReminderEntry, now: Date) -> String {
        let remaining = max(entry.event.start.timeIntervalSince(now), 0)
        let totalSeconds = Int(remaining.rounded(.down))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    static func minutesCountdownText(for entry: ReminderLiveActivityManager.ReminderEntry, now: Date) -> String {
        let remaining = max(entry.event.start.timeIntervalSince(now), 0)
        let minutes = max(1, Int(ceil(remaining / 60)))
        return minutes == 1 ? "in 1 min" : "in \(minutes) min"
    }

    static func digitalFrameWidth(for text: String) -> CGFloat {
        let width = musicMeasureText(text, font: MusicSupplementFont.monospacedDigitSystemFont(ofSize: 15, weight: .semibold))
        return max(width + 18, 76)
    }

    static func minutesFrameWidth(for text: String) -> CGFloat {
        let width = musicMeasureText(text, font: MusicSupplementFont.systemFont(ofSize: 13, weight: .semibold))
        return max(width + 18, 88)
    }

    static func ringDiameter(for notchHeight: CGFloat) -> CGFloat {
        max(min(notchHeight - 12, 22), 16)
    }
}

private func musicMeasureText(_ text: String, font: MusicSupplementFont) -> CGFloat {
    guard !text.isEmpty else { return 0 }
    let attributes: [NSAttributedString.Key: Any] = [.font: font]
    return CGFloat(ceil(NSAttributedString(string: text, attributes: attributes).size().width))
}

struct FullScreenDropDelegate: DropDelegate {
    @Binding var isTargeted: Bool
    let onDrop: () -> Void

    func dropEntered(info _: DropInfo) {
        isTargeted = true
    }

    func dropExited(info _: DropInfo) {
        isTargeted = false
    }

    func performDrop(info _: DropInfo) -> Bool {
        isTargeted = false
        onDrop()
        return true
    }
}
