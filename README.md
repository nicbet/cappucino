# Cappucino

A macOS menu bar app that keeps your Mac awake while AI agents work, and still lets your displays sleep so OLED panels don't burn in.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)
![License: MIT](https://img.shields.io/badge/License-MIT-green)

## Features

- **System awake, displays asleep.** Holds a `PreventUserIdleSystemSleep` power assertion (the same thing `caffeinate -i` uses). The Mac won't idle-sleep, but your normal display-sleep timer still applies.
- **Auto mode.** Detects running agent CLIs (`claude`, `codex`, `gemini`, `aider`, `opencode`, `amp`, `goose`, `cursor-agent`, `crush`, `qwen`, `droid`) and keeps the Mac awake only while they run. You can edit the list in Settings.
- **Grace period.** Stays awake for a few minutes after the last agent exits, in case you queue up the next task (none/5/10/15/30 min).
- **Clear status.** The popover says whether the Mac is being kept awake and why (which agents are running), or when it will sleep if not.
- **Timer.** Keep awake for 1h, 2h, 4h, 8h, or indefinitely, whether or not agents are running. A countdown appears in the menu bar.
- **Let displays sleep** (on by default). Turn it off to also keep the displays on while the Mac is kept awake.
- **Sleep Displays Now.** Turns displays off immediately while agents keep working.
- **Burn-in warnings.** Shows your display-sleep setting, warns if it's set to never, and lists any other app (a video player, a browser tab, another keep-awake tool) that is keeping the displays on.
- **Launch at login.**
- **Nothing to configure.** No accounts, no network access, no root.

## Prerequisites

- macOS 14.0+
- Xcode 26+ (for `swift` and `actool`, which compiles the Icon Composer app icon)

## Build & Install

```bash
make bundle    # builds release binary + .app bundle
make install   # copies to /Applications
make run       # builds and launches
```

## How It Works

### Keeping awake

macOS has separate assertions for system sleep and display sleep. Cappucino only takes the system one:

| Assertion                     | Cappucino | Effect                                    |
| ----------------------------- | --------- | ----------------------------------------- |
| `PreventUserIdleSystemSleep`  | ✅ held    | Mac stays awake, agents keep running      |
| `PreventUserIdleDisplaySleep` | only if "Let displays sleep" is off | Displays stay on too |

You can see what Cappucino is doing and why with:

```bash
pmset -g assertions | grep Cappucino
```

### Agent detection

Every 5 seconds Cappucino scans the process table for the configured names. Agents that run through an interpreter (for example `node /opt/homebrew/bin/gemini`) are matched by their script name. Version-named binaries launched through a symlink (like Claude Code's native installer) are matched by `argv[0]`. Names are case-sensitive, so `claude` matches the CLI but not the Claude desktop app.

### Limitations

- **Closing a MacBook lid still sleeps it**, unless it's in clamshell mode with external power and a display. Power assertions can't override lid-close sleep without root (`pmset disablesleep`).
- The display-sleep timeout is a system setting (System Settings → Lock Screen / Displays). Cappucino reads it but doesn't change it.

## License

MIT. Menu bar icons are from [Phosphor Icons](https://phosphoricons.com) (MIT), see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
