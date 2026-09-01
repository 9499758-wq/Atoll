# Atoll Cute Icon Optimization

## User Problem

Atoll currently mixes Hermes-built UI, CodeBuddy-added animation assets, and older SF Symbol fallbacks. The visible notch still feels cold or confusing: some agent states look like abstract white marks, idle CodeBuddy can look active, and many status icons are not using the cute FluentAnim assets.

## Success Criteria

- Closed notch prioritizes active agents over reminders and weather.
- Expanded bridge cards show active agents first, then reminders, idle agents, and weather.
- Visible bridge, system, timer, lyrics/music, and sneak-peek icons use the shared cute icon layer or existing cute weather/agent glyphs.
- Cute icons reuse bundled `DynamicIsland/FluentAnim` assets where available and cache image loading.
- Small notch and expanded-card icons must read as standalone stickers/glyphs, not as icons trapped inside repeated rounded-square plates.
- Reminder glyphs must be immediately recognizable; the drink-water reminder should read as a cup/bottle plus water, movement should read as a moving person with motion cues, and stand-up should look like a person stretching, not a node/tree diagram.
- Agent, laptop, thought bubble, and active status animations must feel continuous and professional: use smooth state-driven easing/spring motion instead of visibly low-frame stepped Timeline animation.
- Animation optimization must not reintroduce high idle CPU; the installed app should settle to a low single-digit CPU range after startup while Codex is active.
- Idle agents remain labeled as idle and must not be logged or displayed as if they are working.
- Release build installs to `/Applications/Atoll.app`, starts successfully, and can be verified with a real screenshot.

## Non-Goals

- Do not delete user data, permissions, preferences, music state, or bridge config.
- Do not reintroduce accessibility permission popups.
- Do not replace the app with a separate Hermes or CodeBuddy copy.
- Do not make high-frequency icon animation loops for every small icon, and do not fake smoothness with coarse low-frame jumps.
- Do not use one repeated rounded-square frame as the default visual treatment for every status icon.
