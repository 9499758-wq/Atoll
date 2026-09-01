# Plan

1. Capture player lyric-like fields from the Now Playing adapter payload.
2. Store the raw player lyric payload in `PlaybackState`.
3. Make `MusicManager` parse and display player lyrics before cache and LRCLIB fallback.
4. Add parser support for Soda timed lyrics and fix millisecond LRC timing.
5. Add source checks that prevent the player-priority path from regressing.
6. Build, install, and verify the real `/Applications/Atoll.app`.
