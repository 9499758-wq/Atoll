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

import Combine
import Darwin
import Defaults
import SwiftUI
import AppKit
import AVFoundation

private final class DynamicIslandArtworkLoopController {
    let player: AVQueuePlayer
    private var looper: AVPlayerLooper?
    private var playbackStateCancellable: AnyCancellable?

    init(url: URL) {
        let item = AVPlayerItem(url: url)
        player = AVQueuePlayer()
        player.isMuted = true
        player.actionAtItemEnd = .none
        looper = AVPlayerLooper(player: player, templateItem: item)

        if MusicManager.shared.isPlaying {
            player.play()
        }

        playbackStateCancellable = MusicManager.shared.$isPlaying
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isPlaying in
                guard let self else { return }
                if isPlaying {
                    self.player.play()
                } else {
                    self.player.pause()
                }
            }
    }

    deinit {
        player.pause()
        looper = nil
        playbackStateCancellable = nil
    }
}

private final class DynamicIslandArtworkVideoContainerView: NSView {
    let playerLayer = AVPlayerLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.backgroundColor = NSColor.clear.cgColor
        layer?.addSublayer(playerLayer)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        playerLayer.frame = bounds
    }
}

private struct DynamicIslandArtworkVideoView: NSViewRepresentable {
    let url: URL
    let videoGravity: AVLayerVideoGravity

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> DynamicIslandArtworkVideoContainerView {
        let view = DynamicIslandArtworkVideoContainerView(frame: .zero)
        context.coordinator.attach(layer: view.playerLayer, url: url, gravity: videoGravity)
        return view
    }

    func updateNSView(_ nsView: DynamicIslandArtworkVideoContainerView, context: Context) {
        context.coordinator.attach(layer: nsView.playerLayer, url: url, gravity: videoGravity)
    }

    final class Coordinator {
        private var controller: DynamicIslandArtworkLoopController?
        private var currentURL: URL?

        func attach(layer: AVPlayerLayer, url: URL, gravity: AVLayerVideoGravity) {
            layer.videoGravity = gravity

            if currentURL != url || controller == nil {
                currentURL = url
                controller = DynamicIslandArtworkLoopController(url: url)
            }

            if layer.player !== controller?.player {
                layer.player = controller?.player
            }
        }
    }
}

struct DynamicIslandArtworkSourceView: View {
    @ObservedObject private var musicManager = MusicManager.shared
    @Default(.showLiveCanvasInDynamicIsland) private var showLiveCanvasInDynamicIsland

    let cornerRadius: CGFloat
    let contentMode: ContentMode

    private var liveCanvasURL: URL? {
        guard showLiveCanvasInDynamicIsland else { return nil }
        return musicManager.videoArtworkURL
    }

    var body: some View {
        Group {
            if let liveCanvasURL {
                DynamicIslandArtworkVideoView(url: liveCanvasURL, videoGravity: .resizeAspectFill)
            } else {
                Image(nsImage: musicManager.albumArt)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

// MARK: - Music Player Components

struct MusicPlayerView: View {
    @EnvironmentObject var vm: DynamicIslandViewModel
    let albumArtNamespace: Namespace.ID

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AlbumArtView(vm: vm, albumArtNamespace: albumArtNamespace)
            MusicControlsView()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AlbumArtView: View {
    @ObservedObject var musicManager = MusicManager.shared
    @ObservedObject var vm: DynamicIslandViewModel
    @Default(.showLiveCanvasInDynamicIsland) private var showLiveCanvasInDynamicIsland
    let albumArtNamespace: Namespace.ID

    private var usesLiveCanvasArtwork: Bool {
        showLiveCanvasInDynamicIsland && musicManager.videoArtworkURL != nil
    }

    private var albumArtCornerRadius: CGFloat {
        Defaults[.cornerRadiusScaling]
            ? musicManager.albumArt.size.width / musicManager.albumArt.size.height > 1.0
                ? MusicPlayerImageSizes.cornerRadiusInset.opened / 3
                : MusicPlayerImageSizes.cornerRadiusInset.opened
            : musicManager.albumArt.size.width / musicManager.albumArt.size.height > 1.0
                ? MusicPlayerImageSizes.cornerRadiusInset.closed / 3
                : MusicPlayerImageSizes.cornerRadiusInset.closed
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if Defaults[.lightingEffect] {
                albumArtBackground
            }
            albumArtButton
        }
    }

    private var albumArtBackground: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .background(
                DynamicIslandArtworkSourceView(
                    cornerRadius: albumArtCornerRadius,
                    contentMode: .fill
                )
            )
            .clipped()
            .scaleEffect(x: 1.3, y: 1.4)
            .rotationEffect(.degrees(92))
            .blur(radius: 40)
            .opacity(
                usesLiveCanvasArtwork
                    ? (musicManager.isPlaying ? 0.62 : 0.18)
                    : (musicManager.isPlaying ? 0.5 : 0)
            )
            .shadow(
                color: Color(nsColor: musicManager.avgColor).opacity(usesLiveCanvasArtwork ? 0.24 : 0.16),
                radius: usesLiveCanvasArtwork ? 22 : 14,
                x: 0,
                y: 0
            )
    }

    private var albumArtButton: some View {
        ZStack {
            Button {
                musicManager.openMusicApp()
            } label: {
                ZStack(alignment:.bottomTrailing) {
                    albumArtImage
                    appIconOverlay
                }
                .albumArtFlip(angle: musicManager.flipAngle)
                .parallax3D()
                .padding(.bottom, -5)

            }
            .buttonStyle(PlainButtonStyle())
            .scaleEffect(musicManager.isPlaying ? 1 : 0.85)
            
            albumArtDarkOverlay
        }
    }

    private var albumArtDarkOverlay: some View {
        Rectangle()
            .aspectRatio(1, contentMode: .fit)
            .foregroundColor(Color.black)
            .opacity(musicManager.isPlaying ? 0 : 0.8)
            .blur(radius: 50)
    }

    private var albumArtImage: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                DynamicIslandArtworkSourceView(
                    cornerRadius: albumArtCornerRadius,
                    contentMode: .fit
                )
            }
            .matchedGeometryEffect(id: "albumArt", in: albumArtNamespace)
        .clipped()
    }

    @ViewBuilder
    private var appIconOverlay: some View {
        if vm.notchState == .open && !musicManager.usingAppIconForArtwork {
            AppIcon(for: musicManager.bundleIdentifier ?? "com.apple.Music")
                .resizable()
                .scaledToFill()
                .frame(width: 36, height: 36)
                .offset(x: 10, y: 10)
                .transition(.scale.combined(with: .opacity).animation(.bouncy.delay(0.3)))
                .zIndex(2)
        }
    }
}

struct MusicControlsView: View {
    @EnvironmentObject var vm: DynamicIslandViewModel
    @ObservedObject var musicManager = MusicManager.shared
    @ObservedObject var coordinator = DynamicIslandViewCoordinator.shared
    @State private var sliderValue: Double = MusicManager.shared.estimatedPlaybackPosition()
    @State private var dragging: Bool = false
    @State private var lastDragged: Date = .distantPast
    @State private var hudValue: Double = 0
    @State private var hudDragging: Bool = false
    @State private var hudLastDragged: Date = .distantPast
    @Default(.showShuffleAndRepeat) private var showCustomControls
    @Default(.musicControlSlots) private var slotConfig
    @Default(.showMediaOutputControl) private var showMediaOutputControl
    @Default(.musicSkipBehavior) private var musicSkipBehavior
    @Default(.enableLyrics) private var enableLyrics
    private let seekInterval: TimeInterval = 10
    private let skipMagnitude: CGFloat = 6

    var body: some View {
        VStack(alignment: .leading) {
            songInfoAndSlider
            if shouldShowControlHUDRow {
                controlHUDRow
            } else {
                playbackControls
            }
        }
        .buttonStyle(PlainButtonStyle())
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var songInfoAndSlider: some View {
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: 4) {
                songInfo(width: geo.size.width)
                    .zIndex(1) // Ensure it draws above the waveform scrubber
                musicSlider
                    .zIndex(0)
            }
        }
        .padding(.top, 10)
        .padding(.leading, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func songInfo(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            MusicTitleMarqueeView(
                text: musicManager.songTitle,
                isExplicit: musicManager.isCurrentTrackExplicit,
                font: .headline,
                nsFont: .headline,
                textColor: .white,
                frameWidth: width,
                badgeHeight: 14
            )
            MarqueeText(
                $musicManager.artistName,
                font: .headline,
                nsFont: .headline,
                textColor: Defaults[.playerColorTinting] ? Color(nsColor: musicManager.avgColor)
                    .ensureMinimumBrightness(factor: 0.6) : .gray,
                frameWidth: width
            )
            .fontWeight(.medium)
            // Lyrics shown under the author name (same font size as author) when enabled in settings and lyrics are present
            let rawLine = musicManager.currentLyrics.trimmingCharacters(in: .whitespacesAndNewlines)
            if enableLyrics && !rawLine.isEmpty {
                let transition = AnyTransition.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                )

                let lyricsBinding = Binding<String>(
                    get: { rawLine },
                    set: { _ in }
                )

                HStack(spacing: 5) {
                    AtollCuteIcon(symbolName: "music.note",
                                  size: 13,
                                  accent: .white.opacity(0.68),
                                  secondary: Color(red: 1.0, green: 0.56, blue: 0.78),
                                  showsPlate: false,
                                  animated: true)
                    MarqueeText(
                        lyricsBinding,
                        font: .system(size: 12, weight: .regular),
                        nsFont: .headline,
                        textColor: .white.opacity(0.76),
                        minDuration: 0.35,
                        frameWidth: max(0, width - 22)
                    )
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule(style: .continuous).fill(Color.white.opacity(0.08)))
                .padding(.top, 3)
                .id(rawLine)
                .transition(transition)
                .animation(.easeInOut(duration: 0.32), value: rawLine)
            }
        }
    }

    /// Whether the progress timeline should be paused (no ticks).
    private var isProgressTimelinePaused: Bool {
        !musicManager.isPlaying || musicManager.isLiveStream || musicManager.playbackRate <= 0
    }

    private var musicSlider: some View {
        TimelineView(.animation(paused: isProgressTimelinePaused)) { timeline in
            MusicSliderView(
                sliderValue: $sliderValue,
                duration: $musicManager.songDuration,
                lastDragged: $lastDragged,
                color: musicManager.avgColor,
                dragging: $dragging,
                currentDate: timeline.date,
                timestampDate: musicManager.timestampDate,
                elapsedTime: musicManager.elapsedTime,
                playbackRate: musicManager.playbackRate,
                isPlaying: musicManager.isPlaying,
                isLiveStream: musicManager.isLiveStream
            ) { newValue in
                guard !musicManager.isLiveStream else { return }
                MusicManager.shared.seek(to: newValue)
            }
            .padding(.top, 5)
            .frame(height: 36)
        }
    }

    private var playbackControls: some View {
        HStack(spacing: 8) {
            ForEach(Array(displayedSlots.enumerated()), id: \.offset) { _, slot in
                slotView(for: slot)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var shouldShowControlHUDRow: Bool {
        guard vm.notchState == .open else { return false }
        guard coordinator.sneakPeek.show else { return false }
        guard Defaults[.enableSystemHUD] else { return false }
        guard !Defaults[.enableCustomOSD] && !Defaults[.enableVerticalHUD] && !Defaults[.enableCircularHUD] else { return false }

        switch coordinator.sneakPeek.type {
        case .volume:
            return Defaults[.enableVolumeHUD]
        case .brightness:
            return Defaults[.enableBrightnessHUD]
        case .backlight:
            return Defaults[.enableKeyboardBacklightHUD]
        default:
            return false
        }
    }

    private var controlHUDRow: some View {
        HStack(alignment: .center, spacing: 10) {
            if !controlLeftIconName.isEmpty {
                AtollCuteIcon(symbolName: controlLeftIconName,
                              size: 22,
                              accent: .white.opacity(0.85),
                              secondary: Color(red: 0.58, green: 0.90, blue: 1.0),
                              showsPlate: false,
                              animated: false)
                    .frame(width: 22, height: 22, alignment: .center)
            }

            controlHUDSlider

            if !controlRightIconName.isEmpty {
                AtollCuteIcon(symbolName: controlRightIconName,
                              size: 22,
                              accent: .white.opacity(0.85),
                              secondary: Color(red: 1.0, green: 0.78, blue: 0.36),
                              showsPlate: false,
                              animated: false)
                    .frame(width: 22, height: 22, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .onAppear { syncHUDValueIfNeeded(force: true) }
        .onChange(of: coordinator.sneakPeek.value) { _, _ in
            syncHUDValueIfNeeded(force: false)
        }
    }

    private var controlHUDSlider: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            CustomSlider(
                value: Binding(
                    get: { hudValue },
                    set: { newValue in
                        hudValue = newValue
                        updateControlHUDValue(newValue)
                    }
                ),
                range: 0...1,
                color: .white,
                dragging: $hudDragging,
                lastDragged: $hudLastDragged,
                onValueChange: { newValue in
                    updateControlHUDValue(newValue)
                },
                thumbSize: 10,
                restingTrackHeight: 4,
                draggingTrackHeight: 7
            )
            .frame(height: 7)
            Spacer(minLength: 0)
        }
        .frame(height: 22)
    }

    private func syncHUDValueIfNeeded(force: Bool) {
        guard shouldShowControlHUDRow else { return }
        guard force || !hudDragging else { return }
        hudValue = Double(coordinator.sneakPeek.value)
    }

    private func updateControlHUDValue(_ newValue: Double) {
        let clamped = max(0, min(1, newValue))
        switch coordinator.sneakPeek.type {
        case .volume:
            SystemVolumeController.shared.setVolume(Float(clamped))
        case .brightness:
            SystemBrightnessController.shared.setBrightness(Float(clamped))
        case .backlight:
            SystemKeyboardBacklightController.shared.setLevel(Float(clamped))
        default:
            break
        }
    }

    private var controlLeftIconName: String {
        switch coordinator.sneakPeek.type {
        case .volume:
            return SystemVolumeController.shared.isMuted ? "speaker.slash" : "speaker.wave.1"
        case .brightness:
            return "sun.min.fill"
        case .backlight:
            return "light.min"
        default:
            return ""
        }
    }

    private var controlRightIconName: String {
        switch coordinator.sneakPeek.type {
        case .volume:
            return SystemVolumeController.shared.isMuted ? "" : "speaker.wave.3"
        case .brightness:
            return "sun.max.fill"
        case .backlight:
            return "light.max"
        default:
            return ""
        }
    }

    private var brandAccentColor: Color {
        musicManager.brandAccentColor
    }

    private var repeatIcon: String {
        switch musicManager.repeatMode {
        case .off:
            return "repeat"
        case .all:
            return "repeat"
        case .one:
            return "repeat.1"
        }
    }

    private var repeatIconColor: Color {
        switch musicManager.repeatMode {
        case .off:
            return .white
        case .all, .one:
            return brandAccentColor
        }
    }

    private var displayedSlots: [MusicControlButton] {
        if showCustomControls {
            let normalized = slotConfig.normalized(allowingMediaOutput: showMediaOutputControl, isAppleMusicActive: musicManager.isAppleMusicActive, isSpotifyActive: musicManager.isSpotifyActive)
            return normalized.contains(where: { $0 != .none }) ? normalized : MusicControlButton.defaultLayout
        }

        switch musicSkipBehavior {
        case .track:
            return MusicControlButton.minimalLayout
        case .tenSecond:
            return [.none, .seekBackward, .playPause, .seekForward, .none]
        }
    }

    @ViewBuilder
    private func slotView(for control: MusicControlButton) -> some View {
        switch control {
        case .none:
            Spacer(minLength: 0)
        case .playPause:
            HoverButton(
                icon: musicManager.isPlaying ? (musicManager.isLiveStream ? "stop.fill" : "pause.fill") : "play.fill",
                scale: .large
            ) {
                MusicManager.shared.togglePlay()
            }
        case .trackBackward:
            playbackButton(
                icon: "backward.fill",
                press: .nudge(-skipMagnitude),
                trigger: skipGestureTrigger(for: .trackBackward)
            ) {
                musicManager.previousTrack()
            }
        case .trackForward:
            playbackButton(
                icon: "forward.fill",
                press: .nudge(skipMagnitude),
                trigger: skipGestureTrigger(for: .trackForward)
            ) {
                musicManager.nextTrack()
            }
        case .seekBackward:
            playbackButton(
                icon: "gobackward.10",
                press: .wiggle(.counterClockwise),
                trigger: skipGestureTrigger(for: .seekBackward)
            ) {
                musicManager.seek(by: -seekInterval)
            }
        case .seekForward:
            playbackButton(
                icon: "goforward.10",
                press: .wiggle(.clockwise),
                trigger: skipGestureTrigger(for: .seekForward)
            ) {
                musicManager.seek(by: seekInterval)
            }
        case .shuffle:
            HoverButton(
                icon: "shuffle",
                iconColor: musicManager.isShuffled ? brandAccentColor : .white,
                scale: .medium
            ) {
                MusicManager.shared.toggleShuffle()
            }
        case .repeatMode:
            HoverButton(
                icon: repeatIcon,
                iconColor: repeatIconColor,
                scale: .medium
            ) {
                MusicManager.shared.toggleRepeat()
            }
        case .mediaOutput:
            MediaOutputPickerButton()
        case .airPlay:
            AirPlayPickerButton()
        case .lyrics:
            HoverButton(
                icon: enableLyrics ? "quote.bubble.fill" : "quote.bubble",
                iconColor: enableLyrics ? brandAccentColor : .white,
                scale: .medium
            ) {
                enableLyrics.toggle()
            }
        case .likeTrack:
            LikeTrackControl { presentation, toggle in
                HoverButton(
                    icon: presentation.iconName,
                    iconColor: presentation.isActive ? brandAccentColor : .white,
                    scale: .medium
                ) {
                    toggle()
                }
            }
        }
    }

    private struct SkipTrigger {
        let token: Int
        let pressEffect: HoverButton.PressEffect
    }

    private func playbackButton(
        icon: String,
        press: HoverButton.PressEffect?,
        trigger: SkipTrigger?,
        action: @escaping () -> Void
    ) -> some View {
        HoverButton(
            icon: icon,
            scale: .medium,
            pressEffect: press,
            externalTriggerToken: trigger?.token,
            externalTriggerEffect: trigger?.pressEffect
        ) {
            action()
        }
    }

    private func skipGestureTrigger(for control: MusicControlButton) -> SkipTrigger? {
        guard let pulse = musicManager.skipGesturePulse else { return nil }

        switch control {
        case .trackBackward where pulse.behavior == .track && pulse.direction == .backward:
            return SkipTrigger(token: pulse.token, pressEffect: .nudge(-skipMagnitude))
        case .trackForward where pulse.behavior == .track && pulse.direction == .forward:
            return SkipTrigger(token: pulse.token, pressEffect: .nudge(skipMagnitude))
        case .seekBackward where pulse.behavior == .tenSecond && pulse.direction == .backward:
            return SkipTrigger(token: pulse.token, pressEffect: .wiggle(.counterClockwise))
        case .seekForward where pulse.behavior == .tenSecond && pulse.direction == .forward:
            return SkipTrigger(token: pulse.token, pressEffect: .wiggle(.clockwise))
        default:
            return nil
        }
    }
}

// MARK: - Main View

struct AtollBridgeSystem: Decodable, Equatable {
    let cpuPercent: Double?
    let loadAvg: Double?
    let memoryUsedPercent: Double?
    let batteryPercent: Int?
    let charging: Bool?
    let batteryWatts: Double?
    let batteryDischarging: Bool?
    let batteryTimeRemaining: Double?   // minutes
    let diskFreeGB: Double?
    let diskTotalGB: Double?
    let dnd: Bool?
    let generatedAt: Double?            // daemon liveness stamp
    /// 最近 60 秒历史曲线：{"cpu":[...],"mem":[...],"net":[...],"pwr":[...]}
    let history: [String: [Double]]?
}

/// Hermes 当前会话的深度信息（bridge 从 ~/.hermes/state.db 读出）。
struct AtollSessionInfo: Decodable, Equatable {
    let id: String?
    let title: String
    let durationSeconds: Int
    let messageCount: Int?
    let toolCallCount: Int?
    let inputTokens: Int?
    let outputTokens: Int?
    let reasoningTokens: Int?
    /// 最新一轮 (input+output) / 上下文窗口，0~1；驱动进度环。
    let progress: Double?
}

/// 番茄钟状态机快照。
struct AtollPomodoroInfo: Decodable, Equatable {
    let phase: String            // focus | rest | paused
    let remainingSeconds: Int
    let totalSeconds: Int
    let round: Int
    var isIdle: Bool { phase == "idle" }
}

/// Leaf card data: one agent or the weather. Never contains nested containers,
/// so the value type stays finite (unlike the old self-recursive status).
struct AtollBridgeEntity: Decodable, Equatable {
    let title: String
    let detail: String
    let symbol: String
    let active: Bool?
    let agent: String?
    let initials: String?
    let accent: String?
    let secondary: String?
    let appIconPath: String?
    let rate: Double?
    let uptimeSeconds: Int?
    let kind: String?
    let alert: Bool?
    let alertTitle: String?
    /// Hermes 会话深度信息（仅 Hermes agent 实体携带）。
    let session: AtollSessionInfo?

    enum CodingKeys: String, CodingKey {
        case title, detail, symbol, active, agent, initials, accent, secondary, appIconPath
        case rate, uptimeSeconds, name, kind, alert, alertTitle, session
    }

    init(
        title: String,
        detail: String,
        symbol: String,
        active: Bool?,
        agent: String?,
        initials: String?,
        accent: String?,
        secondary: String?,
        appIconPath: String?,
        rate: Double? = nil,
        uptimeSeconds: Int? = nil,
        kind: String? = nil,
        alert: Bool? = nil,
        alertTitle: String? = nil,
        session: AtollSessionInfo? = nil
    ) {
        self.title = title
        self.detail = detail
        self.symbol = symbol
        self.active = active
        self.agent = agent
        self.initials = initials
        self.accent = accent
        self.secondary = secondary
        self.appIconPath = appIconPath
        self.rate = rate
        self.uptimeSeconds = uptimeSeconds
        self.kind = kind
        self.alert = alert
        self.alertTitle = alertTitle
        self.session = session
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // v2 agent objects use "name"; weather/legacy use "agent"
        let nameVal = try c.decodeIfPresent(String.self, forKey: .name)
        let agentVal = try c.decodeIfPresent(String.self, forKey: .agent)
        let resolvedAgent = nameVal ?? agentVal ?? "AI"
        let isWeather = resolvedAgent == "Weather"

        self.title = try c.decodeIfPresent(String.self, forKey: .title) ?? resolvedAgent
        self.detail = try c.decodeIfPresent(String.self, forKey: .detail) ?? ""
        self.symbol = try c.decodeIfPresent(String.self, forKey: .symbol) ?? (isWeather ? "cloud.sun" : "terminal")
        self.active = try c.decodeIfPresent(Bool.self, forKey: .active)
        self.agent = resolvedAgent
        self.initials = try c.decodeIfPresent(String.self, forKey: .initials) ?? String(resolvedAgent.prefix(1))
        self.accent = try c.decodeIfPresent(String.self, forKey: .accent) ?? (isWeather ? "#5BB6FF" : "#29D3FF")
        self.secondary = try c.decodeIfPresent(String.self, forKey: .secondary) ?? (isWeather ? "#6EE7B7" : "#28F0A8")
        self.appIconPath = try c.decodeIfPresent(String.self, forKey: .appIconPath)
        self.rate = try c.decodeIfPresent(Double.self, forKey: .rate)
        self.uptimeSeconds = try c.decodeIfPresent(Int.self, forKey: .uptimeSeconds)
        self.kind = try c.decodeIfPresent(String.self, forKey: .kind)
        self.alert = try c.decodeIfPresent(Bool.self, forKey: .alert)
        self.alertTitle = try c.decodeIfPresent(String.self, forKey: .alertTitle)
        self.session = try c.decodeIfPresent(AtollSessionInfo.self, forKey: .session)
    }

    /// True for transient notice rows (cron results / break reminders / alerts).
    var isNotice: Bool { kind != nil }

    /// Alert-styled copy of a weather entity: title carries the official alert
    /// headline (e.g. 暴雨黄色预警), detail keeps the live weather line.
    func alertPinned() -> AtollBridgeEntity {
        AtollBridgeEntity(
            title: "⚠️ \(alertTitle ?? "天气预警")",
            detail: detail,
            symbol: "exclamationmark.triangle.fill",
            active: true,
            agent: agent,
            initials: "警",
            accent: accent,          // daemon already switched these to alert colors
            secondary: secondary,
            appIconPath: nil,
            rate: rate,
            uptimeSeconds: uptimeSeconds,
            kind: kind,
            alert: alert
        )
    }
}

struct AtollBridgeStatus: Decodable, Equatable {
    // legacy flat fields (still written by the daemon; used by closed-state UI)
    let title: String
    let detail: String
    let symbol: String
    let active: Bool?
    let agent: String?
    let initials: String?
    let accent: String?
    let secondary: String?
    let appIconPath: String?
    let rate: Double?
    let uptimeSeconds: Int?

    // v2 container fields
    let agents: [AtollBridgeEntity]?
    let notices: [AtollBridgeEntity]?
    let weather: AtollBridgeEntity?
    let system: AtollBridgeSystem?
    /// 番茄钟状态机（bridge 顶层字段；空闲时为 null）。
    let pomodoro: AtollPomodoroInfo?

    enum CodingKeys: String, CodingKey {
        case title, detail, symbol, active, agent, initials, accent, secondary, appIconPath
        case rate, uptimeSeconds, agents, notices, weather, system, name, pomodoro
    }

    init(
        title: String,
        detail: String,
        symbol: String,
        active: Bool?,
        agent: String?,
        initials: String?,
        accent: String?,
        secondary: String?,
        appIconPath: String?,
        rate: Double? = nil,
        uptimeSeconds: Int? = nil
    ) {
        self.title = title
        self.detail = detail
        self.symbol = symbol
        self.active = active
        self.agent = agent
        self.initials = initials
        self.accent = accent
        self.secondary = secondary
        self.appIconPath = appIconPath
        self.rate = rate
        self.uptimeSeconds = uptimeSeconds
        self.agents = nil
        self.notices = nil
        self.weather = nil
        self.system = nil
        self.pomodoro = nil
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // v2 agent objects use "name"; weather/legacy use "agent"
        let nameVal = try c.decodeIfPresent(String.self, forKey: .name)
        let agentVal = try c.decodeIfPresent(String.self, forKey: .agent)
        let resolvedAgent = nameVal ?? agentVal ?? "AI"

        self.title = try c.decodeIfPresent(String.self, forKey: .title) ?? resolvedAgent
        self.detail = try c.decodeIfPresent(String.self, forKey: .detail) ?? ""
        self.symbol = try c.decodeIfPresent(String.self, forKey: .symbol) ?? (resolvedAgent == "Weather" ? "cloud.sun" : "terminal")
        self.active = try c.decodeIfPresent(Bool.self, forKey: .active)
        self.agent = resolvedAgent
        self.initials = try c.decodeIfPresent(String.self, forKey: .initials) ?? String(resolvedAgent.prefix(1))
        self.accent = try c.decodeIfPresent(String.self, forKey: .accent) ?? (resolvedAgent == "Weather" ? "#5BB6FF" : "#29D3FF")
        self.secondary = try c.decodeIfPresent(String.self, forKey: .secondary) ?? (resolvedAgent == "Weather" ? "#6EE7B7" : "#28F0A8")
        self.appIconPath = try c.decodeIfPresent(String.self, forKey: .appIconPath)
        self.rate = try c.decodeIfPresent(Double.self, forKey: .rate)
        self.uptimeSeconds = try c.decodeIfPresent(Int.self, forKey: .uptimeSeconds)
        self.agents = try c.decodeIfPresent([AtollBridgeEntity].self, forKey: .agents)
        self.notices = try c.decodeIfPresent([AtollBridgeEntity].self, forKey: .notices)
        self.weather = try c.decodeIfPresent(AtollBridgeEntity.self, forKey: .weather)
        self.system = try c.decodeIfPresent(AtollBridgeSystem.self, forKey: .system)
        self.pomodoro = try c.decodeIfPresent(AtollPomodoroInfo.self, forKey: .pomodoro)
    }

    static let fallback = AtollBridgeStatus(
        title: "昆明官渡 19°C",
        detail: "天气 · 等待更新",
        symbol: "cloud.sun",
        active: false,
        agent: "Weather",
        initials: "昆",
        accent: "#5BB6FF",
        secondary: "#6EE7B7",
        appIconPath: nil
    )

    /// Flat legacy fields as a single entity (daemon still writes them; also covers decode fallback).
    var legacyEntity: AtollBridgeEntity {
        AtollBridgeEntity(
            title: title,
            detail: detail,
            symbol: symbol,
            active: active,
            agent: agent,
            initials: initials,
            accent: accent,
            secondary: secondary,
            appIconPath: appIconPath,
            rate: rate,
            uptimeSeconds: uptimeSeconds
        )
    }

    /// Entities to render as separate cards: active agents first, then notices,
    /// idle agents, and weather. Work must be visually harder to miss than breaks.
    var displayEntities: [AtollBridgeEntity] {
        var result: [AtollBridgeEntity] = []
        if let agents = agents, !agents.isEmpty {
            let ordered = agents.sorted {
                ($0.active ?? false) != ($1.active ?? false)
                    ? ($0.active ?? false) : $0.title < $1.title
            }
            result.append(contentsOf: ordered.filter { $0.active ?? false })
            result.append(contentsOf: notices ?? [])
            result.append(contentsOf: ordered.filter { !($0.active ?? false) })
        } else {
            result.append(contentsOf: notices ?? [])
        }
        if var w = weather {
            if w.alert == true { w = w.alertPinned() }
            result.append(w)
        }
        if result.isEmpty {
            result.append(legacyEntity)
        }
        return result
    }

    static func load() -> AtollBridgeStatus {
        let url = URL(fileURLWithPath: "/tmp/atoll_bridge_status.json")
        guard let data = try? Data(contentsOf: url),
              let status = try? JSONDecoder().decode(AtollBridgeStatus.self, from: data) else {
            return fallback
        }
        return status
    }
}

private enum AtollBridgeLaunchAgentRepair {
    private static let label = "com.local.AtollBridge"
    private static let plistPath = "\(NSHomeDirectory())/Library/LaunchAgents/com.local.AtollBridge.plist"

    static func reviveIfPossible() {
        guard FileManager.default.fileExists(atPath: plistPath) else {
            NSLog("AtollBridgeRepair: missing LaunchAgent plist at \(plistPath)")
            return
        }

        DispatchQueue.global(qos: .utility).async {
            let domain = "gui/\(getuid())"
            let service = "\(domain)/\(label)"
            _ = runLaunchctl(["enable", service])
            _ = runLaunchctl(["bootstrap", domain, plistPath])
            _ = runLaunchctl(["kickstart", "-k", service])
        }
    }

    @discardableResult
    private static func runLaunchctl(_ arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            NSLog("AtollBridgeRepair: launchctl \(arguments.joined(separator: " ")) failed: \(error.localizedDescription)")
            return -1
        }
    }
}

private struct AtollBridgeStatusCard: View {
    @EnvironmentObject var vm: DynamicIslandViewModel
    let status: AtollBridgeEntity
    var compact: Bool = false
    var onTap: (() -> Void)? = nil

    @State private var ringPulse = false
    @State private var alertGlow = false
    @State private var flashCopy = false
    @State private var isHovered = false

    private var accent: Color { Color(atollHex: status.accent ?? "#29D3FF") }
    private var secondary: Color { Color(atollHex: status.secondary ?? "#28F0A8") }
    private var initials: String { status.initials ?? "AI" }
    private var isActive: Bool { status.active ?? false }
    private var isWeatherCard: Bool { status.agent == "Weather" }
    private var isAlert: Bool { status.alert == true }
    /// s1: 上下文占用环颜色 —— <60% 绿，<85% 黄，≥85% 红（该压缩了）
    private func ctxRingColor(_ p: Double) -> Color {
        if p >= 0.85 { return Color(red: 1.0, green: 0.42, blue: 0.38) }
        if p >= 0.60 { return Color(red: 1.0, green: 0.72, blue: 0.28) }
        return Color(red: 0.4, green: 0.92, blue: 0.6)
    }
    private var statusLabel: String {
        if status.isNotice { return "" }
        if isWeatherCard { return isAlert ? "预警生效中" : "实况" }
        return isActive ? "工作中" : "空闲"
    }
    private var compactDetail: String {
        if isActive {
            return status.detail.replacingOccurrences(of: " / ", with: " · ")
        }
        return status.detail
            .replacingOccurrences(of: "多云 · ", with: "")
            .replacingOccurrences(of: "晴 · ", with: "")
    }

    private var cardHeight: CGFloat { compact ? 32 : 42 }
    private var sectionWidth: CGFloat { compact ? 120 : 138 }
    private var spacerWidth: CGFloat { max(vm.closedNotchSize.width + 16, 200) }
    private var iconSize: CGFloat { compact ? 24 : 30 }
    private var iconRadius: CGFloat { compact ? 8 : 11 }

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: compact ? 6 : 8) {
                brandIcon
                    .overlay {
                        // s1: Hermes 会话上下文占用进度环（仅携带 session 的实体显示）
                        if let p = status.session?.progress {
                            Circle()
                                .trim(from: 0, to: CGFloat(min(1, max(0, p))))
                                .stroke(ctxRingColor(p), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                                .frame(width: iconSize + 4, height: iconSize + 4)
                                .rotationEffect(.degrees(-90))
                        }
                    }

                VStack(alignment: .leading, spacing: 1) {
                    if isActive, let task = status.session?.title, !task.isEmpty {
                        // s1: 工作中滚动字幕显示当前任务标题（长标题跑马灯，短的静止）
                        AtollMarqueeText(text: "⚙ \(task)", font: .system(size: compact ? 11 : 13, weight: .semibold))
                    } else {
                        AtollFlowingLightText(
                            text: status.title,
                            font: .system(size: compact ? 11 : 13, weight: .semibold),
                            baseColor: .white,
                            accent: accent,
                            secondary: secondary,
                            isWorking: isActive
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    }

                    HStack(spacing: 5) {
                        ZStack {
                            if isActive || isAlert {
                                Circle()
                                    .stroke(accent.opacity(ringPulse ? 0 : 0.7), lineWidth: 1.2)
                                    .frame(width: ringPulse ? 11 : 5, height: ringPulse ? 11 : 5)
                            }
                            Circle()
                                .fill(accent.opacity(isActive ? 0.95 : (isAlert ? 0.9 : 0.4)))
                                .frame(width: 5, height: 5)
                        }
                        .frame(width: 12, height: 12)

                        AtollFlowingLightText(
                            text: status.agent ?? "AI",
                            font: .system(size: 9, weight: .bold),
                            baseColor: accent,
                            accent: .white,
                            secondary: secondary,
                            isWorking: isActive
                        )
                        .lineLimit(1)

                        if !statusLabel.isEmpty {
                            Text(statusLabel)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.54))
                                .lineLimit(1)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: sectionWidth, alignment: .leading)

            Spacer(minLength: spacerWidth)
                .frame(width: spacerWidth)

            HStack(spacing: compact ? 6 : 8) {
                VStack(alignment: .trailing, spacing: 3) {
                    Text(compactDetail)
                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                    AtollBridgeActivityBars(accent: accent, secondary: secondary, active: isActive, rate: status.rate)
                        .frame(width: compact ? 88 : 112, alignment: .trailing)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(width: sectionWidth, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, minHeight: cardHeight, maxHeight: cardHeight)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(isAlert ? 0.14 : (isHovered ? 0.10 : 0.05)))
        )
        .overlay {
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(isHovered ? 0.18 : 0.04), lineWidth: 0.8)
        }
        .onHover { isHovered = $0 }
        .overlay(alignment: .topTrailing) {
            if flashCopy {
                HStack(spacing: 3) {
                    AtollCuteIcon(symbolName: "checkmark.circle.fill",
                                  size: 10,
                                  accent: .green,
                                  secondary: .white,
                                  showsPlate: false,
                                  animated: false,
                                  weight: .black)
                    Text("已复制")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.green)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.black.opacity(0.92))
                )
                .offset(x: -4, y: -8)
                .transition(.opacity.combined(with: .scale(scale: 0.85)))
            }
        }
        .animation(.easeOut(duration: 0.18), value: flashCopy)
        .contentShape(Rectangle())
        .onTapGesture {
            if status.isNotice {
                // Notices have no detail view — copy the full text so the
                // tap still does something useful (e.g. cron failure reason).
                let payload = "\(status.title) — \(status.detail)"
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(payload, forType: .string)
                flashCopy = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { flashCopy = false }
            }
            onTap?()
        }
        .task(id: "\(isActive)-\(isAlert)") {
            while true {
                guard isActive || isAlert else { return }
                try? await Task.sleep(nanoseconds: isAlert ? 1_600_000_000 : 3_200_000_000)
                ringPulse.toggle()
                if isAlert { alertGlow.toggle() }
            }
        }
    }

    @ViewBuilder
    private var brandIcon: some View {
        let agentName = (status.agent ?? "").lowercased()
        if agentName.contains("antigravity") {
            AntigravityCuteAstroMascot(accent: accent, secondary: secondary, floating: isActive)
                .frame(width: iconSize, height: iconSize)
        } else if agentName.contains("codex") {
            CodexCuteRobotMascot(accent: accent, secondary: secondary, floating: isActive)
                .frame(width: iconSize, height: iconSize)
        } else if agentName.contains("hermes") {
            HermesCuteFoxMascot(accent: accent, secondary: secondary, floating: isActive)
                .frame(width: iconSize, height: iconSize)
        } else if agentName.contains("claude") {
            ClaudeCuteSparkleMascot(accent: accent, secondary: secondary, floating: isActive)
                .frame(width: iconSize, height: iconSize)
        } else if status.isNotice {
            NoticeMiniScene(symbolName: status.symbol, accent: accent, secondary: secondary)
                .frame(width: iconSize, height: iconSize)
        } else if isWeatherCard || WeatherKind.isWeatherSymbol(status.symbol) {
            AtollDynamic3DWeatherIcon(condition: status.detail,
                                      size: iconSize,
                                      accent: accent,
                                      secondary: secondary)
                .frame(width: iconSize, height: iconSize)
        } else {
            AtollCuteIcon(symbolName: status.symbol.isEmpty ? "robot" : status.symbol,
                          size: iconSize,
                          accent: accent,
                          secondary: secondary,
                          showsPlate: false,
                          animated: isActive || isAlert)
                .frame(width: iconSize, height: iconSize)
        }
    }

    private func weatherSymbol(for detail: String) -> String {
        if detail.contains("雷") || detail.contains("暴") { return "storm" }
        if detail.contains("雪") { return "snowcloud" }
        if detail.contains("雨") { return "rain" }
        if detail.contains("雾") || detail.contains("霾") { return "fog" }
        if detail.contains("阴") { return "cloud" }
        if detail.contains("多云") { return "suncloud" }
        if detail.contains("夜") || detail.contains("月") { return "moon" }
        return "sun"
    }
}

private struct AtollSystemBar: View {
    let system: AtollBridgeSystem
    var onTap: (() -> Void)? = nil

    private var cpuColor: Color {
        guard let p = system.cpuPercent else { return .gray }
        if p > 80 { return Color(red: 1.0, green: 0.42, blue: 0.38) }
        if p > 50 { return Color(red: 1.0, green: 0.72, blue: 0.28) }
        return Color(red: 0.4, green: 0.92, blue: 0.6)
    }

    private var memColor: Color {
        guard let p = system.memoryUsedPercent else { return .gray }
        if p > 85 { return Color(red: 1.0, green: 0.42, blue: 0.38) }
        if p > 65 { return Color(red: 1.0, green: 0.72, blue: 0.28) }
        return Color(red: 0.5, green: 0.8, blue: 1.0)
    }

    var body: some View {
        HStack(spacing: 10) {
            AtollSystemBarCore(system: system)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(height: 16)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
    }
}

/// CPU / memory / load / battery / power / disk / DND readouts, split out of
/// AtollSystemBar so the type-checker doesn't choke on one giant expression.
private struct AtollSystemBarCore: View {
    let system: AtollBridgeSystem

    private var cpuColor: Color {
        guard let p = system.cpuPercent else { return .gray }
        if p > 80 { return Color(red: 1.0, green: 0.42, blue: 0.38) }
        if p > 50 { return Color(red: 1.0, green: 0.72, blue: 0.28) }
        return Color(red: 0.4, green: 0.92, blue: 0.6)
    }

    private var memColor: Color {
        guard let p = system.memoryUsedPercent else { return .gray }
        if p > 85 { return Color(red: 1.0, green: 0.42, blue: 0.38) }
        if p > 65 { return Color(red: 1.0, green: 0.72, blue: 0.28) }
        return Color(red: 0.5, green: 0.8, blue: 1.0)
    }

    var body: some View {
        HStack(spacing: 10) {
            if let cpu = system.cpuPercent {
                HStack(spacing: 4) {
                    AtollCuteIcon(symbolName: "cpu",
                                  size: 12,
                                  accent: cpuColor,
                                  secondary: Color(red: 0.55, green: 0.95, blue: 0.85),
                                  showsPlate: false,
                                  animated: cpu > 80)
                    // s2: 60 秒迷你火花线
                    AtollSparkline(values: system.history?["cpu"] ?? [], color: cpuColor)
                    Text(String(format: "%.0f%%", cpu))
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(cpuColor)
                }
            }

            if let mem = system.memoryUsedPercent {
                HStack(spacing: 4) {
                    AtollCuteIcon(symbolName: "memorychip",
                                  size: 12,
                                  accent: memColor,
                                  secondary: Color(red: 0.70, green: 0.92, blue: 1.0),
                                  showsPlate: false,
                                  animated: mem > 85)
                    // s2: 内存火花线
                    AtollSparkline(values: system.history?["mem"] ?? [], color: memColor)
                    Text(String(format: "%.0f%%", mem))
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(memColor)
                }
            }

            if let load = system.loadAvg {
                HStack(spacing: 4) {
                    AtollCuteIcon(symbolName: "chart.bar",
                                  size: 12,
                                  accent: .white.opacity(0.7),
                                  secondary: Color(red: 0.55, green: 0.72, blue: 1.0),
                                  showsPlate: false,
                                  animated: false)
                    Text(String(format: "%.1f", load))
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            if let bat = system.batteryPercent {
                HStack(spacing: 4) {
                    AtollCuteIcon(symbolName: system.charging == true ? "battery.100.bolt" : "battery.100",
                                  size: 12,
                                  accent: bat <= 20 ? Color(red: 1.0, green: 0.42, blue: 0.38) : .green,
                                  secondary: system.charging == true ? Color(red: 1.0, green: 0.84, blue: 0.24) : Color(red: 0.52, green: 0.95, blue: 0.62),
                                  showsPlate: false,
                                  animated: system.charging == true)
                    Text("\(bat)%")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(bat <= 20 ? Color(red: 1.0, green: 0.42, blue: 0.38) : .green)
                }
            }

            if let w = system.batteryWatts, w >= 1 {
                Text(String(format: "%.0fW", w))
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(system.batteryDischarging == false
                                     ? Color(red: 0.4, green: 0.92, blue: 0.6)
                                     : (w > 40 ? Color(red: 1.0, green: 0.72, blue: 0.28) : .white.opacity(0.7)))
            }

            if let mins = system.batteryTimeRemaining, mins > 0, mins < 3000 {
                let h = Int(mins) / 60, m = Int(mins) % 60
                Text(h > 0 ? "\(h):\(String(format: "%02d", m))" : "\(m)分")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
            }

            if let free = system.diskFreeGB, let total = system.diskTotalGB, total > 0 {
                let ratio = free / total
                Text(String(format: "磁盘 %.0fG", free))
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(ratio < 0.10 ? Color(red: 1.0, green: 0.42, blue: 0.38)
                                     : (ratio < 0.20 ? Color(red: 1.0, green: 0.72, blue: 0.28)
                                        : .white.opacity(0.7)))
            }

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Bridge expanded detail views (click interactions)

struct AtollForecastDay: Decodable, Equatable {
    let date: String
    let desc: String
    let symbol: String
    let tmax: Int
    let tmin: Int
    let pop: Int
}

/// Loads daemon-written extras for the expanded cards and tracks which card is open.
final class AtollBridgeUIState: ObservableObject {
    static let shared = AtollBridgeUIState()
    @Published var expandedCardID: String?
    @Published var details = AtollBridgeDetailModel()

    struct ForecastFile: Decodable { let label: String; let days: [AtollForecastDay] }
    struct TopProc: Decodable, Equatable { let name: String; let pid: Int; let cpu: Double }
    struct TopFile: Decodable { let procs: [TopProc] }

    struct AtollBridgeDetailModel: Equatable {
        var forecastDays: [AtollForecastDay] = []
        var forecastLabel: String = ""
        var topProcs: [TopProc] = []
    }

    func toggle(_ id: String?) {
        if id != nil, expandedCardID == id {
            withAnimation(.smooth(duration: 0.22)) { expandedCardID = nil }
        } else {
            withAnimation(.smooth(duration: 0.22)) { expandedCardID = id }
            reloadDetails()
        }
    }

    func reloadDetails() {
        var m = AtollBridgeDetailModel()
        if let data = try? Data(contentsOf: URL(fileURLWithPath: "/tmp/atoll_bridge_forecast.json")),
           let f = try? JSONDecoder().decode(ForecastFile.self, from: data) {
            m.forecastDays = f.days
            m.forecastLabel = f.label
        }
        if let data = try? Data(contentsOf: URL(fileURLWithPath: "/tmp/atoll_bridge_top.json")),
           let t = try? JSONDecoder().decode(TopFile.self, from: data) {
            m.topProcs = t.procs
        }
        details = m
    }

    /// Stable per-card identity used for expansion tracking.
    static func cardID(_ e: AtollBridgeEntity) -> String {
        if e.agent == "Weather" { return "weather" }
        if e.isNotice, let k = e.kind { return "notice-\(k)" }
        return "agent-\(e.agent ?? e.title)"
    }
}

private struct AtollWeatherDetailView: View {
    let days: [AtollForecastDay]
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(label) · 未来 7 天")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color(atollHex: "#5BB6FF"))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(days.indices, id: \.self) { i in
                        let d = days[i]
                        VStack(spacing: 2) {
                            Text(Self.dayLabel(d.date, today: i == 0))
                                .font(.system(size: 8.5, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.6))
                            WeatherCuteIcon(symbolName: d.symbol, size: 13)
                            Text("\(d.tmin)° \(d.tmax)°")
                                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.white)
                            if d.pop > 0 {
                                Text("降水\(d.pop)%")
                                    .font(.system(size: 7.5, weight: .medium))
                                    .foregroundStyle(Color(atollHex: "#7DD3FC"))
                            }
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 5)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.black.opacity(0.55))
                                .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(i == 0 ? 0.22 : 0.08), lineWidth: 1))
                        )
                    }
                }
            }
        }
    }

    private static func dayLabel(_ iso: String, today: Bool) -> String {
        if today { return "今天" }
        let names = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        guard let date = df.date(from: iso) else { return String(iso.suffix(5)) }
        return names[Calendar.current.component(.weekday, from: date) - 1]
    }
}

// MARK: - s2/s3/s4 火花线 · 历史面板 · 番茄钟

/// s2: 火花线 —— 最近 ≤60 点折线，无轴；小图（系统条）与大图（面板）共用。
private struct AtollSparkline: View {
    let values: [Double]
    var color: Color
    var width: CGFloat = 34
    var height: CGFloat = 12

    var body: some View {
        Canvas { ctx, size in
            let v = values.suffix(60)
            guard v.count > 1 else { return }
            let mx = max(v.max() ?? 1, 0.0001)
            var path = Path()
            for (i, x) in v.enumerated() {
                let pt = CGPoint(x: size.width * CGFloat(i) / CGFloat(v.count - 1),
                                 y: size.height - CGFloat(x / mx) * (size.height - 2) - 1)
                if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
            }
            ctx.stroke(path, with: .color(color),
                       style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
        }
        .frame(width: width, height: height)
    }
}

/// s2/s3: 展开的 60 秒历史面板 —— CPU/内存/网速/功率四行曲线，充电中挂角标。
private struct AtollHistoryPanel: View {
    let system: AtollBridgeSystem

    private var rows: [(String, String, [Double], Color, String)] {
        let h = system.history ?? [:]
        func pct(_ v: Double) -> String { String(format: "%.0f%%", v) }
        var out: [(String, String, [Double], Color, String)] = []
        if let v = system.cpuPercent { out.append(("CPU", "cpu", h["cpu"] ?? [], Color(red: 0.4, green: 0.92, blue: 0.6), pct(v))) }
        if let v = system.memoryUsedPercent { out.append(("内存", "mem", h["mem"] ?? [], Color(red: 0.5, green: 0.8, blue: 1.0), pct(v))) }
        if let arr = h["net"], !arr.isEmpty {
            out.append(("网速", "wifi", arr, Color(red: 0.75, green: 0.68, blue: 1.0), String(format: "%.1f", arr.last ?? 0)))
        }
        if let arr = h["pwr"], !arr.isEmpty {
            out.append(("功率", "bolt.fill", arr, Color(red: 0.98, green: 0.80, blue: 0.28), String(format: "%.0fW", arr.last ?? 0)))
        }
        return out
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Text("最近 60 秒")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.55))
                if system.charging == true {
                    // s3: 充电角标
                    HStack(spacing: 2) {
                        AtollCuteIcon(symbolName: "bolt.fill",
                                      size: 9,
                                      accent: Color(red: 0.4, green: 0.92, blue: 0.6),
                                      secondary: Color(red: 1.0, green: 0.84, blue: 0.24),
                                      showsPlate: false,
                                      animated: true,
                                      weight: .black)
                        Text("充电中").font(.system(size: 8, weight: .bold))
                    }
                    .padding(.horizontal, 5).padding(.vertical, 1.5)
                    .background(Capsule().fill(Color.green.opacity(0.22)))
                    .foregroundStyle(Color(red: 0.4, green: 0.92, blue: 0.6))
                }
                Spacer(minLength: 0)
            }
            ForEach(rows, id: \.0) { row in
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        AtollCuteIcon(symbolName: row.1,
                                      size: 13,
                                      accent: row.3,
                                      secondary: row.3.opacity(0.70),
                                      showsPlate: false,
                                      animated: false)
                        Text(row.0)
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundStyle(row.3)
                    .frame(width: 46, alignment: .leading)
                    AtollSparkline(values: row.2, color: row.3, width: 180, height: 24)
                    Text(row.4)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(row.3.opacity(0.95))
                        .frame(width: 44, alignment: .trailing)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.55))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1))
        )
    }
}

/// s4: 番茄钟刘海条 —— 倒计时胶囊 + 控制按钮（写 ~/.config/atoll_bridge/pomodoro.cmd，
/// bridge 每拍读取并删除）。空闲态给「开始」，运行态给 暂停/继续+停止。
private struct AtollPomodoroBar: View {
    let info: AtollPomodoroInfo

    private var accent: Color {
        switch info.phase {
        case "focus": return Color(red: 0.98, green: 0.45, blue: 0.09)   // #F97316
        case "rest": return Color(red: 0.22, green: 0.74, blue: 0.98)    // #38BDF8
        default: return .white.opacity(0.6)
        }
    }
    private var phaseLabel: String {
        switch info.phase {
        case "focus": return "计时"
        case "rest": return "休息"
        case "paused": return "已暂停"
        default: return "番茄钟"
        }
    }
    /// ponytail: 显示的是上次轮询快照的剩余秒（bridge 数秒一拍），逐秒本地递减等接 endsAt 再做
    private var clock: String {
        let s = max(0, info.remainingSeconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    var body: some View {
        HStack(spacing: 8) {
            if info.isIdle {
                PomodoroTomato3DMascot(size: 14)
                Text("番茄钟待命")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                pomoButton("开始", "play.fill") { send("start") }
            } else {
                PomodoroTomato3DMascot(size: 14)
                Text("\(phaseLabel) R\(info.round)")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(accent)
                Text(clock)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                if info.phase == "paused" {
                    pomoButton("继续", "play.fill") { send("resume") }
                } else {
                    pomoButton("暂停", "pause.fill") { send("pause") }
                }
                pomoButton("停止", "stop.fill") { send("stop") }
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 18)
        .background(
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.7))
                .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
        )
    }

    private func pomoButton(_ label: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 2) {
                AtollCuteIcon(symbolName: icon,
                              size: 9,
                              accent: .white,
                              secondary: accent,
                              showsPlate: false,
                              animated: false,
                              weight: .bold)
                Text(label).font(.system(size: 8, weight: .semibold))
            }
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Capsule().fill(Color.white.opacity(0.10)))
            .foregroundStyle(.white.opacity(0.85))
        }
        .buttonStyle(.plain)
    }

    private func send(_ cmd: String) {
        let path = NSString(string: "~/.config/atoll_bridge/pomodoro.cmd").expandingTildeInPath
        // ponytail: 覆盖写即可 —— bridge 每拍读一次就删
        try? Data(cmd.utf8).write(to: URL(fileURLWithPath: path), options: .atomic)
    }
}

private struct AtollTopProcessView: View {
    let procs: [AtollBridgeUIState.TopProc]

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("CPU 占用 Top 5")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color(atollHex: "#29D3FF"))
            ForEach(Array(procs.prefix(5).enumerated()), id: \.offset) { _, p in
                HStack(spacing: 6) {
                    Text(p.name)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 8)
                    Text(String(format: "%.1f%%", p.cpu))
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(cpuTint(p.cpu))
                }
            }
        }
    }

    private func cpuTint(_ v: Double) -> Color {
        if v > 50 { return Color(red: 1.0, green: 0.42, blue: 0.38) }
        if v > 20 { return Color(red: 1.0, green: 0.72, blue: 0.28) }
        return Color(red: 0.4, green: 0.92, blue: 0.6)
    }
}

/// Opens the live session surface for a clicked agent card.
private func atollOpenAgentSession(for agent: String?) {
    guard let agent = agent else { return }
    let lower = agent.lowercased()
    if lower.contains("antigravity") {
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.google.antigravity").first {
            app.activate(options: .activateIgnoringOtherApps)
        } else if let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Terminal").first {
            app.activate(options: .activateIgnoringOtherApps)
        }
    } else if lower.contains("hermes") {
        if let url = URL(string: "http://localhost:8648") { NSWorkspace.shared.open(url) }
    } else if lower.contains("codex") {
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.openai.chat").first {
            app.activate(options: .activateIgnoringOtherApps)
        } else if let url = URL(string: "https://chatgpt.com/codex") {
            NSWorkspace.shared.open(url)
        }
    } else if lower.contains("claude") {
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.anthropic.claudefordesktop").first {
            app.activate(options: .activateIgnoringOtherApps)
        } else if let url = URL(string: "https://claude.ai/code") {
            NSWorkspace.shared.open(url)
        }
    }
}

/// s1: 跑马灯 —— 文本超宽时匀速往返滚动，放得下就静止；任务标题变化自动重算。
private struct AtollMarqueeWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

private struct AtollMarqueeText: View {
    let text: String
    var font: Font
    var color: Color = .white

    @State private var shift: CGFloat = 0
    @State private var animatedText: String?

    var body: some View {
        GeometryReader { geo in
            Text(text)
                .font(font)
                .foregroundStyle(color)
                .lineLimit(1)
                .fixedSize()
                .background(
                    GeometryReader { tg in
                        Color.clear.preference(key: AtollMarqueeWidthKey.self, value: tg.size.width)
                    }
                )
                .onPreferenceChange(AtollMarqueeWidthKey.self) { natural in
                    guard animatedText != text else { return }
                    animatedText = text
                    let overflow = natural - geo.size.width + 8
                    guard overflow > 10 else { shift = 0; return }
                    withAnimation(.linear(duration: max(4, Double(overflow) / 26))
                        .repeatForever(autoreverses: true)) { shift = -overflow }
                }
                .offset(x: shift)
        }
        .frame(height: 16)
    }
}

/// token 数缩写：596024 -> "596k"，1234567 -> "1.2M"
private func atollTokenShort(_ n: Int?) -> String {
    guard let n else { return "—" }
    if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
    if n >= 1_000 { return String(format: "%.0fk", Double(n) / 1_000) }
    return "\(n)"
}

/// s1: Hermes 会话消耗面板 —— 点击 Hermes 卡展开：上下文进度条 + token/消息/工具/时长。
private struct AtollHermesSessionPanel: View {
    let session: AtollSessionInfo
    let accent: Color

    private var progress: Double { min(1, max(0, session.progress ?? 0)) }
    private var progColor: Color {
        if progress >= 0.85 { return Color(red: 1.0, green: 0.42, blue: 0.38) }
        if progress >= 0.60 { return Color(red: 1.0, green: 0.72, blue: 0.28) }
        return Color(red: 0.4, green: 0.92, blue: 0.6)
    }

    private var durationText: String {
        let d = max(0, session.durationSeconds)
        return d >= 3600 ? "\(d / 3600)h\((d % 3600) / 60)m" : "\(d / 60)m\(d % 60)s"
    }

    var body: some View {
            VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                AtollCuteIcon(symbolName: "gauge.with.needle",
                              size: 12,
                              accent: progColor,
                              secondary: accent,
                              showsPlate: false,
                              animated: progress >= 0.60,
                              weight: .bold)
                Text("上下文占用")
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
                Spacer()
                Text(String(format: "%.0f%%", progress * 100))
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(progColor)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.09))
                    Capsule().fill(progColor).frame(width: max(3, geo.size.width * progress))
                }
            }
            .frame(height: 4)

            HStack(spacing: 0) {
                stat("输入", atollTokenShort(session.inputTokens))
                stat("输出", atollTokenShort(session.outputTokens))
                stat("推理", atollTokenShort(session.reasoningTokens))
                stat("消息", session.messageCount.map { "\($0)" } ?? "—")
                stat("工具", session.toolCallCount.map { "\($0)" } ?? "—")
                stat("时长", durationText)
            }
            Text(session.title)
                .font(.system(size: 8.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.88))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(accent.opacity(0.28), lineWidth: 1))
        )
    }

    @ViewBuilder
    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
    }
}

struct AtollBridgeActivityBars: View {
    let accent: Color
    let secondary: Color
    let active: Bool
    /// Real agent CPU rate (%/s from the bridge daemon). When nil (notices,
    /// weather) bars fall back to decorative motion.
    var rate: Double? = nil

    private let factors: [CGFloat] = [0.36, 0.74, 0.48, 0.9, 0.42, 0.66]

    // Map live CPU rate onto bar energy: 0 → calm, ≥8 %/s → full dance.
    private var energy: CGFloat {
        guard active, let r = rate else { return 1 }
        return CGFloat(min(1.0, max(0.18, r / 8.0)))
    }

    private var heights: [CGFloat] {
        (0..<factors.count).map { i in
            if !active { return [3, 6, 4][i % 3] }
            if rate != nil {
                return 3 + 11 * energy * factors[i]
            }
            return 3 + 11 * factors[i]
        }
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 5) {
            ForEach(factors.indices, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(colors: [accent, secondary], startPoint: .top, endPoint: .bottom)
                    )
                    .frame(width: active ? 3.5 : 3,
                           height: heights[index])
                    .opacity(active ? 0.92 : 0.35)
                    .animation(AtollMotion.activityBarsPulse, value: heights[index])
            }
        }
        .frame(height: 14, alignment: .bottom)
    }
}

extension Color {
    init(atollHex hex: String) {
        var value = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        if value.count == 3 {
            value = value.map { "\($0)\($0)" }.joined()
        }
        var int: UInt64 = 0
        Scanner(string: value).scanHexInt64(&int)
        let red = Double((int >> 16) & 0xff) / 255.0
        let green = Double((int >> 8) & 0xff) / 255.0
        let blue = Double(int & 0xff) / 255.0
        self.init(red: red, green: green, blue: blue)
    }
}

struct NotchHomeView: View {
    @EnvironmentObject var vm: DynamicIslandViewModel
    @ObservedObject var webcamManager = WebcamManager.shared
    @ObservedObject var batteryModel = BatteryStatusViewModel.shared
    @ObservedObject var coordinator = DynamicIslandViewCoordinator.shared
    @ObservedObject private var extensionNotchExperienceManager = ExtensionNotchExperienceManager.shared
    @ObservedObject private var musicManager = MusicManager.shared
    @ObservedObject private var bridgeUI = AtollBridgeUIState.shared
    @Default(.showStandardMediaControls) private var showStandardMediaControls
    @Default(.autoHideInactiveNotchMediaPlayer) private var autoHideInactiveNotchMediaPlayer
    @State private var bridgeStatus = AtollBridgeStatus.load()
    @State private var lastBridgeRepairAttempt = Date.distantPast
    private let bridgeStatusRefresh = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    let albumArtNamespace: Namespace.ID

    /// Whether the music player should actively display (enabled AND has real content).
    private var shouldShowMusicPlayer: Bool {
        showStandardMediaControls
        && musicManager.hasActiveSession
        && !musicManager.isPlayerIdle
        && (!autoHideInactiveNotchMediaPlayer || musicManager.hasActiveSession)
    }

    private var shouldShowBridgeStatus: Bool {
        !Defaults[.enableMinimalisticUI]
        && !shouldShowMusicPlayer
        && !Defaults[.showCalendar]
        && !(Defaults[.showMirror] && webcamManager.cameraAvailable && vm.notchState == .open)
    }

    /// Daemon liveness: status JSON carries generatedAt; if it stops advancing
    /// for >90s the daemon is dead and the cards would be frozen lies.
    private var bridgeIsStale: Bool {
        isBridgeStale(bridgeStatus)
    }

    private func isBridgeStale(_ status: AtollBridgeStatus) -> Bool {
        guard let gen = status.system?.generatedAt else { return false }
        return Date().timeIntervalSince1970 - gen > 90
    }

    private func repairBridgeIfNeeded(for status: AtollBridgeStatus) {
        guard isBridgeStale(status) else { return }
        let now = Date()
        guard now.timeIntervalSince(lastBridgeRepairAttempt) > 60 else { return }
        lastBridgeRepairAttempt = now
        AtollBridgeLaunchAgentRepair.reviveIfPossible()
    }
    
    var body: some View {
        Group {
            if !coordinator.firstLaunch {
                mainContent
            }
        }
        .onAppear {
            let nextStatus = AtollBridgeStatus.load()
            bridgeStatus = nextStatus
            repairBridgeIfNeeded(for: nextStatus)
        }
        .onReceive(bridgeStatusRefresh) { _ in
            let nextStatus = AtollBridgeStatus.load()
            if nextStatus != bridgeStatus {
                withAnimation(.smooth(duration: 0.25)) {
                    bridgeStatus = nextStatus
                }
            }
            repairBridgeIfNeeded(for: nextStatus)
        }
        .transition(.opacity.combined(with: .blurReplace))
    }

    private var mainContent: some View {
        HStack(alignment: .top, spacing: 20) {
            if Defaults[.enableMinimalisticUI] {
                if let overridePayload = minimalisticOverridePayload {
                    ExtensionMinimalisticExperienceView(
                        payload: overridePayload,
                        albumArtNamespace: albumArtNamespace
                    )
                } else {
                    MinimalisticMusicPlayerView(albumArtNamespace: albumArtNamespace)
                }
            } else {
                if shouldShowBridgeStatus {
                    VStack(spacing: 5) {
                        ForEach(Array(bridgeStatus.displayEntities.enumerated()), id: \.offset) { _, entity in
                            let cardID = AtollBridgeUIState.cardID(entity)
                            AtollBridgeStatusCard(
                                status: entity,
                                compact: bridgeStatus.displayEntities.count > 1,
                                onTap: {
                                    switch entity.kind {
                                    case "cron", "break":
                                        break  // notices are informational; tap = dismiss expansion only
                                    default:
                                        bridgeUI.toggle(cardID)
                                    }
                                    if entity.isNotice, entity.kind == "alert" { bridgeUI.toggle("weather") }
                                    // s1: Hermes 首次点击展开消耗面板，再次点击才打开会话页
                                    let wasExpanded = bridgeUI.expandedCardID == cardID
                                    if !entity.isNotice, entity.agent == "Hermes" {
                                        if wasExpanded { atollOpenAgentSession(for: entity.agent) }
                                    } else if !entity.isNotice, entity.agent != "Weather" {
                                        atollOpenAgentSession(for: entity.agent)
                                    }
                                }
                            )
                            .opacity(bridgeUI.expandedCardID == cardID || bridgeUI.expandedCardID == nil ? 1 : 0.55)
                        }
                        if let sys = bridgeStatus.system {
                            AtollSystemBar(system: sys) { bridgeUI.toggle("system") }
                        }
                        // s4: 番茄钟刘海条（空闲待命/计时倒计时/暂停/休息）
                        if let pomo = bridgeStatus.pomodoro, bridgeUI.expandedCardID != "system" {
                            AtollPomodoroBar(info: pomo)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                        if bridgeUI.expandedCardID == "weather",
                           bridgeStatus.weather != nil || bridgeStatus.agents?.contains(where: { $0.agent == "Weather" }) == true {
                            AtollWeatherDetailView(
                                days: bridgeUI.details.forecastDays,
                                label: bridgeUI.details.forecastLabel.isEmpty ? "昆明官渡" : bridgeUI.details.forecastLabel
                            )
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                        if bridgeUI.expandedCardID == "system" {
                            // s2/s3: 60 秒历史曲线面板（含充电角标）+ 热点进程
                            VStack(spacing: 6) {
                                AtollHistoryPanel(system: bridgeStatus.system ?? AtollBridgeSystem(cpuPercent: nil, loadAvg: nil, memoryUsedPercent: nil, batteryPercent: nil, charging: nil, batteryWatts: nil, batteryDischarging: nil, batteryTimeRemaining: nil, diskFreeGB: nil, diskTotalGB: nil, dnd: nil, generatedAt: nil, history: nil))
                                AtollTopProcessView(procs: bridgeUI.details.topProcs)
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                        // s1: Hermes 卡展开 —— 会话 token/时长消耗面板
                        if bridgeUI.expandedCardID?.hasPrefix("agent-") == true,
                           let hermes = bridgeStatus.displayEntities.first(where: { $0.agent == "Hermes" && $0.session != nil }),
                           bridgeUI.expandedCardID == AtollBridgeUIState.cardID(hermes),
                           let sess = hermes.session {
                            AtollHermesSessionPanel(session: sess, accent: Color(atollHex: hermes.accent ?? "#29D3FF"))
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                        if bridgeIsStale {
                            HStack(spacing: 6) {
                                AtollCuteIcon(symbolName: "wifi.slash",
                                              size: 12,
                                              accent: Color(red: 1.0, green: 0.42, blue: 0.38),
                                              secondary: Color(red: 1.0, green: 0.82, blue: 0.32),
                                              showsPlate: false,
                                              animated: true,
                                              weight: .bold)
                                Text("桥接离线 · 正在自动恢复")
                                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                Spacer()
                                Text("enable + bootstrap")
                                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.55))
                            }
                            .foregroundStyle(Color(red: 1.0, green: 0.42, blue: 0.38))
                            .padding(.horizontal, 8)
                            .frame(height: 20)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.black.opacity(0.75))
                                    .overlay(Capsule(style: .continuous)
                                        .stroke(Color(red: 1.0, green: 0.42, blue: 0.38).opacity(0.65), lineWidth: 1))
                            )
                            .transition(.opacity)
                        }
                    }
                    // Fill the opened notch instead of hard-capping at 460pt.
                    // The global screen-width clamp prevents runaway growth;
                    // a fixed bridge width clips the hover-open dashboard and
                    // makes the status bar/recovery command look deformed.
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Normal mode: Show full music player with optional calendar and webcam
                if shouldShowMusicPlayer {
                    MusicPlayerView(albumArtNamespace: albumArtNamespace)
                        .frame(width: 460, alignment: .leading)
                        .frame(maxWidth: 460, alignment: .leading)
                        .clipped()
                }
                
                if Defaults[.showCalendar] {
                    Group {
                        if shouldShowMusicPlayer {
                            CalendarView()
                        } else {
                            StandaloneCalendarView()
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onHover { isHovering in
                        vm.isHoveringCalendar = isHovering
                    }
                    .environmentObject(vm)
                }
                
                if Defaults[.showMirror],
                   webcamManager.cameraAvailable,
                   vm.notchState == .open {
                    CameraPreviewView(webcamManager: webcamManager)
                        .scaledToFit()
                        .opacity(vm.notchState == .closed ? 0 : 1)
                        .blur(radius: vm.notchState == .closed ? 20 : 0)
                }
            }
        }
        .transition(.opacity.animation(.smooth.speed(0.9))
            .combined(with: .blurReplace.animation(.smooth.speed(0.9)))
            .combined(with: .move(edge: .top)))
        .blur(radius: vm.notchState == .closed ? 30 : 0)
        .padding(Defaults[.enableMinimalisticUI] ? 0 : 8) //Putting the main padding for home view here for consistency
    }

    private var minimalisticOverridePayload: ExtensionNotchExperiencePayload? {
        extensionNotchExperienceManager.minimalisticReplacementPayload()
    }
}

struct MusicSliderView: View {
    @Binding var sliderValue: Double
    @Binding var duration: Double
    @Binding var lastDragged: Date
    var color: NSColor
    @Binding var dragging: Bool
    let currentDate: Date
    let timestampDate: Date
    let elapsedTime: Double
    let playbackRate: Double
    let isPlaying: Bool
    let isLiveStream: Bool
    var onValueChange: (Double) -> Void
    var labelLayout: TimeLabelLayout = .stacked
    var trailingLabel: TrailingLabel = .duration
    var restingTrackHeight: CGFloat = 8
    var draggingTrackHeight: CGFloat = 14
    /// When set, bypasses Defaults[.sliderColor] (used by lock screen appearance).
    var tintOverride: Color? = nil

    enum TimeLabelLayout {
        case stacked
        case inline
    }

    enum TrailingLabel {
        case duration
        case remaining
    }

    var body: some View {
        Group {
            if isLiveStream {
                liveStreamView
            } else {
                switch labelLayout {
                case .stacked:
                    stackedContent
                case .inline:
                    inlineContent
                }
            }
        }
        .onAppear {
            guard !isLiveStream else { return }
            guard !dragging else { return }
            setSliderValueWithoutAnimation(MusicManager.shared.estimatedPlaybackPosition())
        }
        .onChange(of: currentDate) { newDate in
            guard !isLiveStream else { return }
            guard !dragging, timestampDate.timeIntervalSince(lastDragged) > -1 else { return }
            setSliderValueWithoutAnimation(MusicManager.shared.estimatedPlaybackPosition(at: newDate))
        }
        .onChange(of: isPlaying) { _, playing in
            // Snap slider to the exact position when music pauses so
            // the in-flight animation doesn't coast past the true value.
            if !playing {
                sliderValue = MusicManager.shared.estimatedPlaybackPosition()
            }
        }
        .onChange(of: isLiveStream) { isLive in
            if isLive {
                sliderValue = 0
            }
        }
    }

    private func setSliderValueWithoutAnimation(_ value: Double) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            sliderValue = value
        }
    }

    private var stackedContent: some View {
        VStack(spacing: 6) {
            sliderCore
                .frame(height: sliderFrameHeight)

            HStack {
                Text(timeString(from: sliderValue))
                Spacer()
                Text(trailingTimeText)
            }
            .fontWeight(.medium)
            .foregroundColor(timeLabelColor)
            .font(.system(size: 11, weight: .medium, design: .default).monospacedDigit())
        }
    }

    private var inlineContent: some View {
        HStack(spacing: 6) {
            Text(timeString(from: sliderValue))
                .font(inlineLabelFont)
                .foregroundColor(timeLabelColor)
                .frame(width: 36, alignment: .leading)

            sliderCore
                .frame(height: sliderFrameHeight)
                .frame(maxWidth: .infinity)

            Text(trailingTimeText)
                .font(inlineLabelFont)
                .foregroundColor(timeLabelColor)
                .frame(width: 42, alignment: .trailing)
        }
    }

    @ViewBuilder
    private var liveStreamView: some View {
        switch labelLayout {
        case .stacked:
            LiveStreamProgressIndicator(tint: sliderTint)
                .frame(maxWidth: .infinity)
                .frame(height: sliderFrameHeight)
                
        case .inline:
            HStack(spacing: 6) {
                Spacer()
                    .frame(width: 36)
                LiveStreamProgressIndicator(tint: sliderTint)
                    .frame(maxWidth: .infinity)
                    .frame(height: sliderFrameHeight)

                Spacer()
                    .frame(width: 42)
            }
        }
    }

    private var sliderCore: some View {
        CustomSlider(
            value: $sliderValue,
            range: 0 ... duration,
            color: sliderTint,
            dragging: $dragging,
            lastDragged: $lastDragged,
            onValueChange: onValueChange,
            restingTrackHeight: restingTrackHeight,
            draggingTrackHeight: draggingTrackHeight
        )
    }

    private var sliderTint: Color {
        if let tintOverride {
            return tintOverride
        }
        switch Defaults[.sliderColor] {
        case .albumArt:
            return Color(nsColor: color).ensureMinimumBrightness(factor: 0.6)
        case .accent:
            return .accentColor
        case .white:
            return .white
        }
    }

    private var timeLabelColor: Color {
        if let tintOverride {
            return tintOverride
        }
        return Defaults[.playerColorTinting]
            ? Color(nsColor: color).ensureMinimumBrightness(factor: 0.6)
            : .gray
    }

    private var trailingTimeText: String {
        switch trailingLabel {
        case .duration:
            return timeString(from: duration)
        case .remaining:
            let remaining = max(duration - sliderValue, 0)
            return "-" + timeString(from: remaining)
        }
    }

    private var inlineLabelFont: Font {
        .system(size: 11, weight: .medium, design: .default).monospacedDigit()
    }

    private var sliderFrameHeight: CGFloat {
        max(restingTrackHeight, draggingTrackHeight)
    }

    func timeString(from seconds: Double) -> String {
        let totalMinutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        } else {
            return String(format: "%d:%02d", minutes, remainingSeconds)
        }
    }

}


struct CustomSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double>
    var color: Color = .white
    @Binding var dragging: Bool
    @Binding var lastDragged: Date
    var onValueChange: ((Double) -> Void)?
    var thumbSize: CGFloat = 12
    var restingTrackHeight: CGFloat = 8
    var draggingTrackHeight: CGFloat = 14
    
    @State private var isHovering: Bool = false
    @Default(.enableRealTimeWaveform) var enableRealTimeWaveform
    @Default(.enableWaveformScrubber) var enableWaveformScrubber

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let trackHeight = CGFloat(dragging ? draggingTrackHeight : restingTrackHeight)
            let rangeSpan = range.upperBound - range.lowerBound

            let progress = rangeSpan == .zero ? 0 : (value - range.lowerBound) / rangeSpan
            let filledTrackWidth = min(max(progress, 0), 1) * width
            
            let showScrubber = isHovering && enableRealTimeWaveform && enableWaveformScrubber

            ZStack(alignment: .bottomLeading) {
                // Background track
                if showScrubber {
                    RealTimeWaveformScrubberView(
                        color: color,
                        secondaryColor: Defaults[.coloredSpectrogram] ? Color(nsColor: MusicManager.shared.secondaryColor) : nil,
                        progress: progress,
                        minHeight: trackHeight
                    )
                    .frame(height: trackHeight * 3.5)
                    .offset(y: trackHeight * 0.2)
                } else {
                    Rectangle()
                        .fill(.gray.opacity(0.3))
                        .frame(height: trackHeight)
                        .cornerRadius(trackHeight / 2)
                }

                // Filled track
                if !showScrubber {
                    Rectangle()
                        .fill(color)
                        .frame(width: filledTrackWidth, height: trackHeight)
                        .cornerRadius(trackHeight / 2)
                }
            }
            .frame(height: max(restingTrackHeight, draggingTrackHeight), alignment: .bottom)
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        withAnimation {
                            dragging = true
                        }
                        let newValue = range.lowerBound + Double(gesture.location.x / width) * rangeSpan
                        value = min(max(newValue, range.lowerBound), range.upperBound)
                    }
                    .onEnded { _ in
                        onValueChange?(value)
                        dragging = false
                        lastDragged = Date()
                    }
            )
            .animation(.bouncy.speed(1.4), value: dragging)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovering = hovering
                }
            }
        }
    }
}

private struct MediaOutputPickerButton: View {
    @ObservedObject private var routeManager = AudioRouteManager.shared
    @StateObject private var volumeModel = MediaOutputVolumeViewModel()
    @State private var isPopoverPresented = false
    @State private var isHoveringPopover = false
    @EnvironmentObject private var vm: DynamicIslandViewModel

    var body: some View {
        HoverButton(icon: buttonIcon, iconColor: .white, scale: .medium) {
            isPopoverPresented.toggle()
            if isPopoverPresented {
                routeManager.refreshDevices()
            }
        }
        .accessibilityLabel("Media output")
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            MediaOutputSelectorPopover(
                routeManager: routeManager,
                volumeModel: volumeModel,
                onHoverChanged: { hovering in
                    isHoveringPopover = hovering
                    updatePopoverActivity()
                }
            ) {
                isPopoverPresented = false
                isHoveringPopover = false
                updatePopoverActivity()
            }
        }
        .onAppear {
            routeManager.refreshDevices()
        }
        .onChange(of: isPopoverPresented) { _, presented in
            if !presented {
                isHoveringPopover = false
            }
            updatePopoverActivity()
        }
        .onDisappear {
            vm.isMediaOutputPopoverActive = false
        }
    }

    private var buttonIcon: String {
        routeManager.activeDevice?.iconName ?? "speaker.wave.2"
    }

    private func updatePopoverActivity() {
        vm.isMediaOutputPopoverActive = isPopoverPresented && isHoveringPopover
    }
}

private struct AirPlayPickerButton: View {
    @ObservedObject private var musicManager = MusicManager.shared
    @ObservedObject private var airPlayManager = AppleMusicAirPlayManager.shared
    @State private var isPopoverPresented = false
    @State private var isHoveringPopover = false
    @EnvironmentObject private var vm: DynamicIslandViewModel

    private var isAppleMusicActive: Bool {
        musicManager.bundleIdentifier == "com.apple.Music"
    }

    var body: some View {
        HoverButton(icon: "airplayaudio", iconColor: .white, scale: .medium) {
            isPopoverPresented.toggle()
            if isPopoverPresented {
                Task { await airPlayManager.refreshDevices() }
            }
        }
        .accessibilityLabel("AirPlay")
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            AirPlaySelectorPopover(
                airPlayManager: airPlayManager,
                onHoverChanged: { hovering in
                    isHoveringPopover = hovering
                    updatePopoverActivity()
                }
            ) {
                isPopoverPresented = false
                isHoveringPopover = false
                updatePopoverActivity()
            }
        }
        .onAppear {
            if isAppleMusicActive {
                Task { await airPlayManager.refreshDevices() }
            }
        }
        .onChange(of: isPopoverPresented) { _, presented in
            if !presented { isHoveringPopover = false }
            updatePopoverActivity()
        }
        .onChange(of: musicManager.bundleIdentifier) { _, newBundle in
            if newBundle == "com.apple.Music" {
                Task { await airPlayManager.refreshDevices() }
            }
        }
        .onDisappear {
            vm.isMediaOutputPopoverActive = false
        }
    }

    private func updatePopoverActivity() {
        vm.isMediaOutputPopoverActive = isPopoverPresented && isHoveringPopover
    }
}

struct MediaOutputSelectorPopover: View {
    @ObservedObject var routeManager: AudioRouteManager
    @ObservedObject var volumeModel: MediaOutputVolumeViewModel
    var onHoverChanged: (Bool) -> Void
    var dismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            volumeSection
            Divider()
            devicesSection
        }
        .frame(width: 240)
        .padding(16)
        .onHover { hovering in
            onHoverChanged(hovering)
        }
        .onDisappear {
            onHoverChanged(false)
        }
    }

    private var volumeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Button {
                    volumeModel.toggleMute()
                } label: {
                    AtollCuteIcon(symbolName: volumeIconName,
                                  size: 28,
                                  accent: .primary,
                                  secondary: .accentColor,
                                  showsPlate: false,
                                  animated: !volumeModel.isMuted && volumeModel.level > 0.001)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)

                Slider(
                    value: Binding(
                        get: { Double(volumeModel.level) },
                        set: { newValue in
                            volumeModel.setVolume(Float(newValue))
                        }
                    ),
                    in: 0 ... 1
                )
                .tint(.accentColor)
            }

            HStack {
                Text("Output volume")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(volumePercentage)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var devicesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Output devices")
                .font(.caption)
                .foregroundColor(.secondary)

            if routeManager.devices.isEmpty {
                Text("No audio outputs available")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(routeManager.devices) { device in
                            Button {
                                routeManager.select(device: device)
                                dismiss()
                                } label: {
                                    HStack(spacing: 8) {
                                    AtollCuteIcon(symbolName: device.iconName,
                                                  size: 16,
                                                  accent: .primary,
                                                  secondary: .accentColor,
                                                  showsPlate: false,
                                                  animated: false)
                                    Text(device.name)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    Spacer()
                                    if device.id == routeManager.activeDeviceID {
                                        AtollCuteIcon(symbolName: "checkmark",
                                                      size: 14,
                                                      accent: .green,
                                                      secondary: .white,
                                                      showsPlate: false,
                                                      animated: false,
                                                      weight: .bold)
                                    }
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(device.id == routeManager.activeDeviceID ? Color.primary.opacity(0.12) : .clear)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 240)
            }
        }
    }

    private var volumeIconName: String {
        if volumeModel.isMuted || volumeModel.level <= 0.001 {
            return "speaker.slash.fill"
        } else if volumeModel.level < 0.33 {
            return "speaker.wave.1.fill"
        } else if volumeModel.level < 0.66 {
            return "speaker.wave.2.fill"
        }
        return "speaker.wave.3.fill"
    }

    private var volumePercentage: String {
        "\(Int(round(volumeModel.level * 100)))%"
    }
}

struct AirPlaySelectorPopover: View {
    @ObservedObject var airPlayManager: AppleMusicAirPlayManager
    var onHoverChanged: (Bool) -> Void
    var dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AirPlay")
                .font(.caption)
                .foregroundColor(.secondary)

            if airPlayManager.devices.isEmpty {
                Text("No AirPlay devices found")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(airPlayManager.devices) { device in
                            VStack(spacing: 4) {
                                Button {
                                    Task { await airPlayManager.toggleDevice(device) }
                                } label: {
                                    HStack(spacing: 8) {
                                        AtollCuteIcon(symbolName: device.iconName,
                                                      size: 16,
                                                      accent: .primary,
                                                      secondary: .accentColor,
                                                      showsPlate: false,
                                                      animated: false)
                                        Text(device.name)
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                        Spacer()
                                        if device.isSelected {
                                            AtollCuteIcon(symbolName: "checkmark",
                                                          size: 14,
                                                          accent: .green,
                                                          secondary: .white,
                                                          showsPlate: false,
                                                          animated: false,
                                                          weight: .bold)
                                        }
                                    }
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(device.isSelected ? Color.primary.opacity(0.12) : .clear)
                                    )
                                }
                                .buttonStyle(.plain)

                                if device.isSelected {
                                    AirPlayVolumeSlider(
                                        airPlayManager: airPlayManager,
                                        deviceID: device.id
                                    )
                                    .padding(.horizontal, 8)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 300)
            }
        }
        .frame(width: 240)
        .padding(16)
        .onHover { hovering in
            onHoverChanged(hovering)
        }
        .onDisappear {
            onHoverChanged(false)
        }
    }
}

/// Local @State slider decoupled from the manager's @Published state.
/// This prevents SwiftUI from resetting the slider position when other
/// published properties on the manager change during a drag.
struct AirPlayVolumeSlider: View {
    @ObservedObject var airPlayManager: AppleMusicAirPlayManager
    let deviceID: String

    @State private var sliderValue: Double = 0
    @State private var isSyncing = false

    var body: some View {
        Slider(value: $sliderValue, in: 0...100)
            .tint(.accentColor)
            .onAppear {
                isSyncing = true
                sliderValue = Double(airPlayManager.currentVolume(for: deviceID))
                isSyncing = false
            }
            .onChange(of: sliderValue) { _, newValue in
                guard !isSyncing else { return }
                airPlayManager.setVolume(Int(newValue), for: deviceID)
            }
    }
}

final class MediaOutputVolumeViewModel: ObservableObject {
    @Published var level: Float
    @Published var isMuted: Bool

    private let controller: SystemVolumeController
    private var cancellables: Set<AnyCancellable> = []

    init(controller: SystemVolumeController = .shared) {
        self.controller = controller
        controller.start()
        level = controller.currentVolume
        isMuted = controller.isMuted

        NotificationCenter.default.publisher(for: .systemVolumeDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                guard let self,
                      let value = notification.userInfo?["value"] as? Float,
                      let muted = notification.userInfo?["muted"] as? Bool else { return }
                self.level = value
                self.isMuted = muted
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .systemAudioRouteDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.syncFromController()
            }
            .store(in: &cancellables)
    }

    func setVolume(_ value: Float) {
        level = value
        if value > 0 {
            isMuted = false
        }
        controller.setVolume(value)
    }

    func toggleMute() {
        isMuted.toggle()
        controller.toggleMute()
    }

    private func syncFromController() {
        level = controller.currentVolume
        isMuted = controller.isMuted
    }
}

#Preview {
    NotchHomeView(
        albumArtNamespace: Namespace().wrappedValue
    )
    .environmentObject(DynamicIslandViewModel())
}
