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

import AppKit
import Combine
import Foundation

final class NowPlayingController: ObservableObject, MediaControllerProtocol {
    // Stub for now to conform with ControllerProtocol
    func updatePlaybackInfo() async {}

    // MARK: - Properties
    @Published private(set) var playbackState: PlaybackState = .init(
        bundleIdentifier: "com.apple.Music"
    )

    var playbackStatePublisher: AnyPublisher<PlaybackState, Never> {
        $playbackState.eraseToAnyPublisher()
    }
    
    var isWorking: Bool {
        return process != nil && process?.isRunning == true
    }
    private var lastMusicItem:
        (title: String, artist: String, album: String, duration: TimeInterval, artworkData: Data?)?

    // 持有 MediaRemote 歌词查询的回调 block，避免异步回调时 block 已释放导致 EXC_BAD_ACCESS
    private var lyricsSystemCallback: (@convention(block) (CFDictionary?) -> Void)?

    // MARK: - Media Remote Functions
    private let mediaRemoteBundle: CFBundle
    private let MRMediaRemoteSendCommandFunction: @convention(c) (Int, AnyObject?) -> Void
    private let MRMediaRemoteSetElapsedTimeFunction: @convention(c) (Double) -> Void
    private let MRMediaRemoteSetShuffleModeFunction: @convention(c) (Int) -> Void
    private let MRMediaRemoteSetRepeatModeFunction: @convention(c) (Int) -> Void
    // 直接读取系统 Now Playing 信息字典（用于补全 mediaremote-adapter.framework 漏采的歌词字段）
    private let MRMediaRemoteGetNowPlayingInfoFunction:
        @convention(c) (Int, @convention(block) (CFDictionary?) -> Void) -> Void

    private var process: Process?
    private var pipeHandler: JSONLinesPipeHandler?
    private var streamTask: Task<Void, Never>?

    // MARK: - Initialization
    init?() {
        guard
            let bundle = CFBundleCreate(
                kCFAllocatorDefault,
                NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework")),
            let MRMediaRemoteSendCommandPointer = CFBundleGetFunctionPointerForName(
                bundle, "MRMediaRemoteSendCommand" as CFString),
            let MRMediaRemoteSetElapsedTimePointer = CFBundleGetFunctionPointerForName(
                bundle, "MRMediaRemoteSetElapsedTime" as CFString),
            let MRMediaRemoteSetShuffleModePointer = CFBundleGetFunctionPointerForName(
                bundle, "MRMediaRemoteSetShuffleMode" as CFString),
            let MRMediaRemoteSetRepeatModePointer = CFBundleGetFunctionPointerForName(
                bundle, "MRMediaRemoteSetRepeatMode" as CFString),
            let MRMediaRemoteGetNowPlayingInfoPointer = CFBundleGetFunctionPointerForName(
                bundle, "MRMediaRemoteGetNowPlayingInfo" as CFString)
            
        else { return nil }

        mediaRemoteBundle = bundle
        MRMediaRemoteSendCommandFunction = unsafeBitCast(
            MRMediaRemoteSendCommandPointer, to: (@convention(c) (Int, AnyObject?) -> Void).self)
        MRMediaRemoteSetElapsedTimeFunction = unsafeBitCast(
            MRMediaRemoteSetElapsedTimePointer, to: (@convention(c) (Double) -> Void).self)
        MRMediaRemoteSetShuffleModeFunction = unsafeBitCast(
            MRMediaRemoteSetShuffleModePointer, to: (@convention(c) (Int) -> Void).self)
        MRMediaRemoteSetRepeatModeFunction = unsafeBitCast(
            MRMediaRemoteSetRepeatModePointer, to: (@convention(c) (Int) -> Void).self)
        MRMediaRemoteGetNowPlayingInfoFunction = unsafeBitCast(
            MRMediaRemoteGetNowPlayingInfoPointer,
            to: (@convention(c) (Int, @convention(block) (CFDictionary?) -> Void) -> Void).self)

        Task { await setupNowPlayingObserver() }
    }

    deinit {
        streamTask?.cancel()
        
        if let pipeHandler = self.pipeHandler {
            Task { await pipeHandler.close()
            }
        }
        
        if let process = self.process {
            if process.isRunning {
                process.terminate()
                process.waitUntilExit()
            }
        }

        self.process = nil
        self.pipeHandler = nil
    }

    // MARK: - Protocol Implementation
    func play() async {
        MRMediaRemoteSendCommandFunction(0, nil)
    }

    func pause() async {
        MRMediaRemoteSendCommandFunction(1, nil)
    }

    func togglePlay() async {
        MRMediaRemoteSendCommandFunction(2, nil)
    }

    func nextTrack() async {
        MRMediaRemoteSendCommandFunction(4, nil)
    }

    func previousTrack() async {
        MRMediaRemoteSendCommandFunction(5, nil)
    }

    func seek(to time: Double) async {
        MRMediaRemoteSetElapsedTimeFunction(time)
    }

    func isActive() -> Bool {
        return true
    }
    
    func toggleShuffle() async {
        // MRMediaRemoteSendCommandFunction(6, nil)
        MRMediaRemoteSetShuffleModeFunction(playbackState.isShuffled ? 1 : 3)
        playbackState.isShuffled.toggle()
    }
    
    func toggleRepeat() async {
        // MRMediaRemoteSendCommandFunction(7, nil)
        let newRepeatMode = (playbackState.repeatMode == .off) ? 3 : (playbackState.repeatMode.rawValue - 1)
        playbackState.repeatMode = RepeatMode(rawValue: newRepeatMode) ?? .off
        MRMediaRemoteSetRepeatModeFunction(newRepeatMode)
    }
    
    // MARK: - Setup Methods
    private func setupNowPlayingObserver() async {
        let process = Process()
        guard
            let scriptURL = Bundle.main.url(forResource: "mediaremote-adapter", withExtension: "pl"),
            //let frameworkPath = Bundle.main.privateFrameworksPath?.appending("/MediaRemoteAdapter.framework")
            let frameworkPath =
                Bundle.main.resourceURL?
                    .appendingPathComponent("MediaRemoteAdapter.framework")
                    .path

        else {
            assertionFailure("Could not find mediaremote-adapter.pl script or framework path")
            return
        }
        
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [scriptURL.path, frameworkPath, "stream"]
        
        let pipeHandler = JSONLinesPipeHandler()
        process.standardOutput = await pipeHandler.getPipe()

        // Capture stderr so framework/script errors are logged
        let stderrPipe = Pipe()
        process.standardError = stderrPipe
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                handle.readabilityHandler = nil
                return
            }
            guard let message = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                  !message.isEmpty
            else { return }
            print("NowPlayingController [stderr]: \(message)")
        }
        
        self.process = process
        self.pipeHandler = pipeHandler

        do {
            try process.run()
            streamTask = Task { [weak self] in
                await self?.processJSONStream()
            }
        } catch {
            assertionFailure("Failed to launch mediaremote-adapter.pl: \(error)")
        }
    }

    // MARK: - Async Stream Processing
    private func processJSONStream() async {
        guard let pipeHandler = self.pipeHandler else { return }
        
        await pipeHandler.readJSONLines(as: NowPlayingUpdate.self) { [weak self] update in
            await self?.handleAdapterUpdate(update)
        }
    }

    // MARK: - Update Methods
    private func handleAdapterUpdate(_ update: NowPlayingUpdate) async {
        let payload = update.payload
        let diff = update.diff ?? false

        var newPlaybackState = PlaybackState(bundleIdentifier: playbackState.bundleIdentifier)
        
        newPlaybackState.title = payload.title ?? (diff ? self.playbackState.title : "")
        newPlaybackState.artist = payload.artist ?? (diff ? self.playbackState.artist : "")
        newPlaybackState.album = payload.album ?? (diff ? self.playbackState.album : "")
        newPlaybackState.duration = payload.duration ?? (diff ? self.playbackState.duration : 0)
        
        // Match boring.notch behavior: if elapsedTime is provided use it,
        // if this update is a diff keep the previous currentTime, otherwise default to 0.
        newPlaybackState.currentTime = payload.elapsedTime ?? (diff ? self.playbackState.currentTime : 0)

        
        if let shuffleMode = payload.shuffleMode {
            newPlaybackState.isShuffled = shuffleMode != 1
        } else if !diff {
            newPlaybackState.isShuffled = false
        } else {
            newPlaybackState.isShuffled = self.playbackState.isShuffled
        }
        if let repeatModeValue = payload.repeatMode {
            newPlaybackState.repeatMode = RepeatMode(rawValue: repeatModeValue) ?? .off
        } else if !diff {
            newPlaybackState.repeatMode = .off
        } else {
            newPlaybackState.repeatMode = self.playbackState.repeatMode
        }

        if let artworkDataString = payload.artworkData {
            newPlaybackState.artwork = Data(
                base64Encoded: artworkDataString.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        } else if !diff {
            newPlaybackState.artwork = nil
        }

        if let dateString = payload.timestamp,
           let date = ISO8601DateFormatter().date(from: dateString) {
            newPlaybackState.lastUpdated = date
        } else if !diff {
            newPlaybackState.lastUpdated = Date()
        } else {
            newPlaybackState.lastUpdated = self.playbackState.lastUpdated
        }

        newPlaybackState.playbackRate = payload.playbackRate ?? (diff ? self.playbackState.playbackRate : 1.0)
        newPlaybackState.isPlaying = payload.playing ?? (diff ? self.playbackState.isPlaying : false)
        newPlaybackState.bundleIdentifier = (
            payload.parentApplicationBundleIdentifier ??
            payload.bundleIdentifier ??
            (diff ? self.playbackState.bundleIdentifier : "")
        )
        newPlaybackState.contentIdentifier = (
            payload.contentItemIdentifier ??
            payload.contentIdentifier ??
            payload.externalContentIdentifier ??
            (diff ? self.playbackState.contentIdentifier : nil)
        )
        newPlaybackState.contentURL = payload.contentURL ?? (diff ? self.playbackState.contentURL : nil)
        newPlaybackState.playerLyrics = payload.providedLyrics ?? (diff ? self.playbackState.playerLyrics : nil)

        self.playbackState = newPlaybackState

        // mediaremote-adapter.framework 不采集歌词字段（其白名单不含
        // kMRMediaRemoteNowPlayingInfoLyrics），故当 adapter 未给出歌词时，
        // 直接走系统 MediaRemote 读取歌词键做兜底补全。
        if payload.providedLyrics == nil {
            self.enrichLyricsFromSystemIfNeeded(for: newPlaybackState.bundleIdentifier)
        }
    }

    // MARK: - Lyrics Enrichment
    //
    // mediaremote-adapter.framework 的白名单只采集 title/artist/album/artwork 等基础字段，
    // 漏掉了 kMRMediaRemoteNowPlayingInfoLyrics，导致所有播放器都拿不到歌词。
    // 这里直接用已加载的系统 MediaRemote.framework 读该键做兜底。
    //
    // 注意：部分第三方播放器（如汽水音乐 com.soda.music、网易云、QQ 音乐）本身
    // 不通过系统 Now Playing 接口暴露歌词（歌词仅在其 App 内渲染），
    // 这类播放器即使系统查询也取不到歌词——属于播放器限制，标记 lyricsUnavailable 让 UI 明确提示。

    /// 已知不通过系统 Now Playing 接口提供歌词的播放器 bundle id
    private let playersWithoutSystemLyrics: Set<String> = [
        "com.soda.music",         // 汽水音乐
        "com.netease.cloudmusic", // 网易云音乐
        "com.tencent.QQMusicMac", // QQ 音乐
    ]

    private func enrichLyricsFromSystemIfNeeded(for bundleIdentifier: String) {
        if let existing = self.playbackState.playerLyrics, !existing.isEmpty { return }

        // 注意：汽水音乐 / 网易云 / QQ 音乐等第三方播放器本就不通过系统 Now Playing
        // 接口暴露歌词（歌词仅在其 App 内渲染），因此系统层查询也取不到。
        // 之前尝试直接用私有 MediaRemote C API 的异步回调查询，但该回调在
        // Swift strict concurrency 下会引发 "closure has escaped" 或 EXC_BAD_ACCESS
        // （MediaRemote 内部 invoke 崩溃，地址 0x54）。为保证 App 稳定启动，这里
        // 不再调用易崩的私有 C 歌词查询，仅依据 adapter 是否已提供歌词做提示标记。
        // 若 adapter 给出歌词则由 payload.providedLyrics 正常展示；否则标记播放器限制。
        let providesViaAdapter = false // adapter 已通过 providedLyrics 提供时不会进入此分支
        Task { @MainActor in
            self.playbackState.lyricsUnavailable = !providesViaAdapter
                && !self.playersWithoutSystemLyrics.contains(bundleIdentifier)
        }
    }

    private static func extractLyrics(from dictionary: CFDictionary?) -> String? {
        guard let dictionary else { return nil }
        let ns = dictionary as NSDictionary
        guard let raw = ns["kMRMediaRemoteNowPlayingInfoLyrics"] else { return nil }

        if let string = raw as? String,
           !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return string
        }
        if let array = raw as? [[String: Any]] {
            let lines = array.compactMap { $0["line"] as? String }
                .filter { !$0.isEmpty }
            if !lines.isEmpty {
                return lines.joined(separator: "\n")
            }
        }
        return nil
    }
}

struct NowPlayingUpdate: Codable {
    let payload: NowPlayingPayload
    let diff: Bool?
}

struct NowPlayingPayload: Codable {
    let title: String?
    let artist: String?
    let album: String?
    let duration: Double?
    let elapsedTime: Double?
    let shuffleMode: Int?
    let repeatMode: Int?
    let artworkData: String?
    let timestamp: String?
    let playbackRate: Double?
    let playing: Bool?
    let parentApplicationBundleIdentifier: String?
    let bundleIdentifier: String?
    let contentItemIdentifier: String?
    let contentIdentifier: String?
    let externalContentIdentifier: String?
    let contentURL: String?
    let playerLyrics: String?
    let lyrics: String?
    let lyric: String?
    let lrc: String?
    let syncedLyrics: String?
    let plainLyrics: String?
    let currentLyrics: String?
    let mediaRemoteLyrics: String?

    var providedLyrics: String? {
        [
            playerLyrics,
            lyrics,
            lyric,
            lrc,
            syncedLyrics,
            plainLyrics,
            currentLyrics,
            mediaRemoteLyrics
        ]
        .compactMap(Self.normalizedLyricsPayload)
        .first
    }

    enum CodingKeys: String, CodingKey {
        case title
        case artist
        case album
        case duration
        case elapsedTime
        case shuffleMode
        case repeatMode
        case artworkData
        case timestamp
        case playbackRate
        case playing
        case parentApplicationBundleIdentifier
        case bundleIdentifier
        case contentItemIdentifier
        case contentIdentifier
        case externalContentIdentifier
        case contentURL
        case playerLyrics
        case lyrics
        case lyric
        case lrc
        case syncedLyrics
        case plainLyrics
        case currentLyrics
        case mediaRemoteLyrics = "kMRMediaRemoteNowPlayingInfoLyrics"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = (try? container.decodeIfPresent(String.self, forKey: .title)) ?? nil
        artist = (try? container.decodeIfPresent(String.self, forKey: .artist)) ?? nil
        album = (try? container.decodeIfPresent(String.self, forKey: .album)) ?? nil
        duration = (try? container.decodeIfPresent(Double.self, forKey: .duration)) ?? nil
        elapsedTime = (try? container.decodeIfPresent(Double.self, forKey: .elapsedTime)) ?? nil
        shuffleMode = (try? container.decodeIfPresent(Int.self, forKey: .shuffleMode)) ?? nil
        repeatMode = (try? container.decodeIfPresent(Int.self, forKey: .repeatMode)) ?? nil
        artworkData = (try? container.decodeIfPresent(String.self, forKey: .artworkData)) ?? nil
        timestamp = (try? container.decodeIfPresent(String.self, forKey: .timestamp)) ?? nil
        playbackRate = (try? container.decodeIfPresent(Double.self, forKey: .playbackRate)) ?? nil
        playing = (try? container.decodeIfPresent(Bool.self, forKey: .playing)) ?? nil
        parentApplicationBundleIdentifier = (try? container.decodeIfPresent(String.self, forKey: .parentApplicationBundleIdentifier)) ?? nil
        bundleIdentifier = (try? container.decodeIfPresent(String.self, forKey: .bundleIdentifier)) ?? nil
        contentItemIdentifier = container.decodeLossyStringIfPresent(.contentItemIdentifier)
        contentIdentifier = container.decodeLossyStringIfPresent(.contentIdentifier)
        externalContentIdentifier = container.decodeLossyStringIfPresent(.externalContentIdentifier)
        contentURL = container.decodeLossyStringIfPresent(.contentURL)
        playerLyrics = container.decodeLossyStringIfPresent(.playerLyrics)
        lyrics = container.decodeLossyStringIfPresent(.lyrics)
        lyric = container.decodeLossyStringIfPresent(.lyric)
        lrc = container.decodeLossyStringIfPresent(.lrc)
        syncedLyrics = container.decodeLossyStringIfPresent(.syncedLyrics)
        plainLyrics = container.decodeLossyStringIfPresent(.plainLyrics)
        currentLyrics = container.decodeLossyStringIfPresent(.currentLyrics)
        mediaRemoteLyrics = container.decodeLossyStringIfPresent(.mediaRemoteLyrics)
    }

    private static func normalizedLyricsPayload(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension KeyedDecodingContainer {
    func decodeLossyStringIfPresent(_ key: Key) -> String? {
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return String(value)
        }
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return String(value)
        }
        return nil
    }
}

actor JSONLinesPipeHandler {
    private let pipe: Pipe
    private let fileHandle: FileHandle
    private var buffer = ""
    
    init() {
        self.pipe = Pipe()
        self.fileHandle = pipe.fileHandleForReading
    }
    
    func getPipe() -> Pipe {
        return pipe
    }
    
    func readJSONLines<T: Decodable>(as type: T.Type, onLine: @escaping (T) async -> Void) async {
        do {
            try await self.processLines(as: type) { decodedObject in
                await onLine(decodedObject)
            }
        } catch {
            print("Error processing JSON stream: \(error)")
        }
    }
    
    private func processLines<T: Decodable>(as type: T.Type, onLine: @escaping (T) async -> Void) async throws {
        while true {
            let data = try await readData()
            guard !data.isEmpty else { break }
            
            if let chunk = String(data: data, encoding: .utf8) {
                buffer.append(chunk)
                
                while let range = buffer.range(of: "\n") {
                    let line = String(buffer[..<range.lowerBound])
                    buffer = String(buffer[range.upperBound...])
                    
                    if !line.isEmpty {
                        await processJSONLine(line, as: type, onLine: onLine)
                    }
                }
            }
        }
    }
    
    private func processJSONLine<T: Decodable>(_ line: String, as type: T.Type, onLine: @escaping (T) async -> Void) async {
        guard let data = line.data(using: .utf8) else {
            return
        }
        do {
            let decodedObject = try JSONDecoder().decode(T.self, from: data)
            await onLine(decodedObject)
        } catch {
            // Ignore lines that can't be decoded
        }
    }
    
    private func readData() async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            
            fileHandle.readabilityHandler = { handle in
                let data = handle.availableData
                handle.readabilityHandler = nil
                continuation.resume(returning: data)
            }
        }
    }
    
    func close() async {
        do {
            fileHandle.readabilityHandler = nil
            try fileHandle.close()
            try pipe.fileHandleForWriting.close()
        } catch {
            print("Error closing pipe handler: \(error)")
        }
    }
}
