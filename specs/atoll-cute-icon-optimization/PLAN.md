# Plan

1. Add a small shared SwiftUI icon component that maps known SF Symbol names to bundled FluentAnim PNGs and falls back to a rounded colorful symbol plate.
2. Replace the most visible hard SF Symbol usage in the closed/open notch, bridge system bar, history panel, pomodoro strip, session panel, and core music/timer sneak peeks.
3. Adjust bridge entity ordering so active work wins over notices and idle tools are visually secondary.
4. Adjust bridge console output to include active state instead of only agent names.
5. Replace visibly stepped icon motion with state-driven SwiftUI easing/spring transforms so the cute assets move smoothly without per-frame busy loops.
6. Remove repeated rounded-square icon plates from the shared cute icon, weather glyph, reaction glyph, and reminder glyph layers; keep lightweight glow/shadow only for legibility.
7. Redraw the stand-up reminder as a clear stretching person glyph and keep agent/weather icons semantically distinct.
8. Build Release, install the real app, restart the bridge, and verify status JSON, process state, CPU, and a screenshot.

## Verification Matrix

- `python3 -m py_compile ~/.local/bin/atoll_bridge.py`
- `xcodebuild -project DynamicIsland.xcodeproj -scheme DynamicIsland -configuration Release ...`
- `codesign --verify --deep --strict /Applications/Atoll.app`
- `/Applications/Atoll.app` version/build check
- `/tmp/atoll_bridge_status.json` active/idle semantics check
- Atoll CPU after startup settles in low single digits while active agent animation is visible
- Real notch screenshot after restart
- Real screenshot confirms expanded status icons no longer use repeated square plates
