#!/usr/bin/env ruby

manager_file = "DynamicIsland/managers/MusicManager.swift"
controller_file = "DynamicIsland/MediaControllers/NowPlayingController.swift"
playback_file = "DynamicIsland/models/PlaybackState.swift"

manager = File.read(manager_file, encoding: "UTF-8")
controller = File.read(controller_file, encoding: "UTF-8")
playback = File.read(playback_file, encoding: "UTF-8")

abort("PlaybackState is missing playerLyrics") unless playback.include?("var playerLyrics: String?")
abort("NowPlayingController does not propagate player-provided lyrics") unless controller.include?("newPlaybackState.playerLyrics = payload.providedLyrics")
abort("NowPlayingPayload does not decode MediaRemote lyrics") unless controller.include?('case mediaRemoteLyrics = "kMRMediaRemoteNowPlayingInfoLyrics"')

method_start = manager.index("private func prepareLyricsForCurrentTrack(")
method_end = manager.index("\n    private func fetchLyricsFromAPI", method_start)
abort("could not locate prepareLyricsForCurrentTrack") unless method_start && method_end

method = manager[method_start...method_end]
player_idx = method.index("lyricsFromPlayerPayload(playerLyrics)")
api_idx = method.index("fetchLyricsFromAPI(")
abort("missing player/API lyrics snippets") unless player_idx && api_idx

if player_idx > api_idx
  abort("FAIL: external lyrics search runs before player-provided lyrics.")
end

abort("Soda timed lyrics parser missing") unless manager.include?("private func parseSodaTimedLyrics")
abort("Soda [start,duration] pattern missing") unless manager.include?('let pattern = "^\\\\[(\\\\d+),(\\\\d+)\\\\](.*)$"')
abort("loading text still says search") if manager.include?('lyricsLoadingText = "正在找歌词..."')

puts "PASS: player-provided lyrics are preferred before external lyric search."
