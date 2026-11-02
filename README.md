<div align="center">

<img src="https://shieldcn.dev/header/graph.svg?title=Wakehold&subtitle=Session-aware%20wake%20control%20for%20macOS&theme=cyan&logo=https%3A%2F%2Fraw.githubusercontent.com%2FKhaledSaeed18%2Fwakehold%2Fmain%2FWakehold%2FResources%2FAssets.xcassets%2FAppIcon.appiconset%2Ficon_256.png&size=lg&align=center" width="820" alt="Wakehold" />

<p>
  <img src="https://shieldcn.dev/badge/platform-macOS%2014%2B-cyan.svg?variant=secondary&logo=apple&logoColor=ffffff" alt="Platform: macOS 14+" />
  <img src="https://shieldcn.dev/badge/Swift-5.10-orange.svg?variant=secondary&logo=swift&logoColor=ffffff" alt="Swift 5.10" />
  <img src="https://shieldcn.dev/badge/interface-menu%20bar%20%2B%20CLI-cyan.svg?variant=secondary" alt="Interface: menu bar + CLI" />
  <a href="https://github.com/KhaledSaeed18/wakehold/actions/workflows/ci.yml"><img src="https://shieldcn.dev/github/ci/KhaledSaeed18/wakehold.svg?workflow=ci.yml&branch=main&variant=secondary" alt="CI status" /></a>
  <a href="LICENSE"><img src="https://shieldcn.dev/badge/license-MIT-green.svg?variant=secondary" alt="License: MIT" /></a>
  <a href="https://github.com/KhaledSaeed18/wakehold/stargazers"><img src="https://shieldcn.dev/github/stars/KhaledSaeed18/wakehold.svg" alt="GitHub stars" /></a>
</p>

<strong>Holds. Then lets go.</strong>

</div>

Wakehold keeps your Mac awake for exactly as long as your work is alive, then lets it sleep. A
running process, a listening port, a wrapped command, an agent session, or a plain timer: each is a
*session* that holds the machine open. When the last one ends, the hold releases on its own.

Most keep-awake tools are a coffee-cup switch you flip on and forget to flip off. Wakehold models
the actual intent. You do not tell it "stay awake"; you tell it what to watch, and it stays awake
while that thing runs.

## Why Wakehold

- **It follows your work, not a timer.** Keep the Mac awake while `pnpm build` runs, while your dev
  server holds `:3000`, while a Claude Code session is active, or while a chosen app is open. The
  moment the work ends, the hold ends.
- **The screen stays on.** By default Wakehold keeps the display lit, not just the system. Turn that
  off for unattended work and the system stays awake while the screen sleeps.
- **It cleans up after itself.** When the last session ends it can sleep the display, sleep the Mac,
  shut down, restart, or notify. "Run the agent overnight, shut down when it finishes" is one switch.
- **It is legible.** The menu shows every reason your Mac is awake, Wakehold's own holds and any
  other app's (a call, audio playing, a stray `caffeinate`), each named with the process that set it.
  Every hold also lands in `pmset -g assertions`. No mystery wakeups.
- **One tool, many clients.** A menu-bar app, a `wakehold` CLI, and a local control endpoint that any
  script or agent can open a session against.

## Features

| Session source | Stays awake while ... |
|----------------|-----------------------|
| Manual         | a timer runs, or indefinitely |
| Process        | a PID is alive |
| Port           | something listens on a port (your dev server) |
| Command        | a wrapped command runs: `wakehold -- pnpm build` |
| Agent          | an agent session is active (Claude Code, Codex, Gemini, Cursor) |
| App            | a chosen app is running |

On top of the sources:

- **Post-session actions**: notify, sleep the display, sleep the Mac, shut down, or restart when the
  last session ends. Armed per occasion, shown in the menu, cancelable.
- **Power guardrails**: release on battery, below a battery percentage, or in Low Power Mode.
- **Keep the display on** by default, with a one-switch opt-out.
- **Stay awake with the lid closed**: opt in and Wakehold turns system sleep off while a session
  holds, so a build, agent, or remote session keeps running in a closed laptop with no external
  display. Sleep comes back the moment the last session ends.
- **See what's keeping it awake**: the menu lists every other process holding the Mac open, not just
  Wakehold's own sessions, so you can tell why it will not sleep.
- **Custom durations**: define your own quick-pick durations and a default.
- **English and Arabic**: the menu and settings are localized, with the layout mirrored for
  right-to-left.
- Global toggle shortcut, a live countdown in the menu bar, launch at login, and activate on launch.

## How it works

Everything is a **session** with a lifecycle. The wake assertion is a derived value: the Mac is
awake if and only if some session is active and no guardrail is suppressing. Nothing flips the
assertion directly; a single controller reconciles one IOKit power assertion to match the session
set.

Liveness is event-driven where the platform allows it. A process session watches the PID with a
`DispatchSource` and releases the instant it exits, with no polling loop. Agent sessions are leases
with a TTL, renewed on activity, so a crash without a goodbye still releases within the TTL.

The keystone is a **local control endpoint**: a Unix domain socket under Application Support, mode
0600, peer-checked. It is not a TCP port, so it is unreachable from the browser and scoped to your
user by the filesystem. The CLI and every agent hook are just clients that open, renew, and close
sessions over it. `curl --unix-socket` speaks to it directly, which keeps hook one-liners trivial.

## Install

Requires macOS 14 or later and Xcode 16 or later.

```bash
git clone https://github.com/KhaledSaeed18/wakehold
cd wakehold
open Wakehold.xcodeproj                                               # build and run the menu-bar app
swift build --package-path WakeholdKit -c release --product wakehold  # build the CLI
ln -sf "$PWD/WakeholdKit/.build/release/wakehold" /usr/local/bin/wakehold  # put wakehold on your PATH
```

Wakehold is a menu-bar app with no Dock icon. Look for the eye mark in the menu bar after launch.
The CLI and the agent hooks talk to that running app, so keep it running for them to work.

## Usage

### Menu bar

Click the eye to start the default duration, or to turn off the running one. Right-click (or
Option-click) the eye to open the menu: see and end what is holding, pick a duration, keep awake
while an app runs, arm a post-session action, or open Settings. The mark carries a diagonal slash when nothing is holding the
Mac awake.

### CLI

The `wakehold` CLI talks to the running app over the local endpoint:

```bash
wakehold -- pnpm build     # hold while the command runs, release on exit
wakehold --keep 51234      # hold while process 51234 is alive
wakehold --keep :3000      # hold while something listens on :3000
wakehold status            # show what is holding the Mac awake
wakehold off               # release sessions opened over the endpoint
```

### Agent hooks

Agent CLIs keep the Mac awake through `wakehold hook`, which reads the tool's event JSON on stdin
and opens a renewing lease keyed by the agent's session id. If the app is not running the hook does
nothing, so it never blocks the agent, and the lease expires on its own if the agent crashes without
a goodbye.

**Claude Code** (`~/.claude/settings.json`, or a project `.claude/settings.json`):

```json
{
  "hooks": {
    "SessionStart": [{ "hooks": [{ "type": "command", "command": "wakehold hook start" }] }],
    "PostToolUse":  [{ "hooks": [{ "type": "command", "command": "wakehold hook renew" }] }],
    "Stop":         [{ "hooks": [{ "type": "command", "command": "wakehold hook renew" }] }],
    "SessionEnd":   [{ "hooks": [{ "type": "command", "command": "wakehold hook end" }] }]
  }
}
```

**Codex CLI, Gemini CLI, and Cursor** use the same contract. Point each tool's hooks at the same
three commands so their event JSON reaches `wakehold hook` on stdin:

| When | Command |
|------|---------|
| a session starts | `wakehold hook start` |
| the agent acts, or a turn ends | `wakehold hook renew` |
| a session ends | `wakehold hook end` |

`wakehold hook` finds the session id under `session_id`, `sessionId`, or `id`, and labels the
session with the working directory, so the same commands work across tools.

## Configuration

Settings has five panes in a sidebar:

- **General**: launch at login, activate on launch (open the default hold when Wakehold starts), the
  global toggle shortcut, keep the display on (default on), and a shortcut to the macOS notification
  settings.
- **Durations**: the default duration, the quick picks shown in the menu, adding a custom one, and
  restoring the defaults.
- **Power**: the live power state (source, battery, Low Power Mode, whether the hold is active or
  paused, and whether a closed lid stays awake), the battery rules (release on battery, below a
  battery percentage, or in Low Power Mode), and the lid-closed setup.
- **Integrations**: whether the `wakehold` CLI is installed, whether Claude Code's hooks are
  connected, copyable commands and hooks config, and the control socket path.
- **About**: what Wakehold is, the version, and links.

### Lid closed

macOS sleeps on lid close no matter what any app asks, unless an external display is attached. The
only switch past that is the root-only `pmset -a disablesleep 1`. **Set up…** in Settings asks for
an admin password once and installs `/etc/sudoers.d/wakehold`, a rule that lets your user run
exactly `pmset -a disablesleep 0` and `pmset -a disablesleep 1` and nothing else. **Remove setup**
turns sleep back on and deletes the rule.

The lid hold extends your sessions and never replaces them: sleep stays off only while a session
holds. A 2-hour timer keeps a closed Mac awake for those 2 hours; a command or process, until it
exits. When the last session ends, normal sleep returns and a closed Mac sleeps right away.

Unlike Wakehold's own hold, this setting survives the app, so Wakehold clears it on quit and on the
next launch. If the app is gone and the Mac will not sleep, run `sudo pmset -a disablesleep 0`.
A closed laptop in a bag can run hot; the battery rules still apply.

## Architecture

Two layers with a clean seam:

- **`WakeholdKit`**, a local Swift package: the session registry, the IOKit assertion, and the
  control endpoint. No SwiftUI. Builds and is tested headless with `swift test`.
- **The app**, a SwiftUI menu-bar target: it observes the controller and sends intent, and never
  touches IOKit.

IOKit lives in one file (`PowerAssertion`); the controller is the only decider. A new session type
is one file conforming to `WakeSession`, wired through the registry, with the controller untouched.
See [CLAUDE.md](CLAUDE.md) for the full map and the design rules.

## Development

```bash
swift test --package-path WakeholdKit                                 # kit + CLI tests
swift build --package-path WakeholdKit -c release --product wakehold  # the CLI
xcodebuild -project Wakehold.xcodeproj -scheme Wakehold test          # the app + its unit tests
```

If Xcode is installed but is not the active command-line toolchain, prefix these with
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

## Requirements

- macOS 14 (Sonoma) or later
- Apple Silicon or Intel

## License

MIT. See [LICENSE](LICENSE).
