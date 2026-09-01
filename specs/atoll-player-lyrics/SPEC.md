# Atoll Player Lyrics Priority

## User Problem

The music panel shows "no lyrics found" while a music app is playing. The user expects Atoll to read lyrics from the active player first instead of always searching an external lyric service.

## Findings

- Atoll's existing generic Now Playing path decoded title, artist, album, timing, artwork, and app identity, but not lyrics.
- The installed Soda Music app has an internal desktop lyrics bundle that reads `player.mediaDetail.lyrics`.
- The current macOS MediaRemote payload for Soda Music exposes the playing track metadata and artwork, but no lyrics field.
- Soda Music exposes no obvious local HTTP endpoint or accessibility lyric text that can be safely read without modifying Soda Music state.

## Success Criteria

- Player-provided lyrics fields are captured into `PlaybackState` when a controller exposes them.
- Player-provided lyrics are parsed before cached or external lyrics.
- LRCLIB remains only a fallback when the player payload does not provide usable lyrics.
- Soda-style `[startMs,durationMs]...<charStart,charDuration>` lyric payloads can be parsed.
- LRC timestamps with 1, 2, or 3 fractional digits stay correctly timed.
- The UI no longer describes lyric loading as "searching" when the primary action is reading from the player.

## Non-Goals

- Do not modify Soda Music, its login data, or its internal cache.
- Do not claim generic MediaRemote can expose Soda lyrics until a real payload proves it.
- Do not delete existing lyric fallback behavior.
