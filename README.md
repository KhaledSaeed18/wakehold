<div align="center">

<img src="https://shieldcn.dev/header/graph.svg?title=Wakehold&subtitle=Session-aware%20wake%20control%20for%20macOS&theme=cyan&logo=lu:Eye&size=lg&align=center" width="820" alt="Wakehold" />

<p>
  <img src="https://shieldcn.dev/badge/platform-macOS%2014%2B-cyan.svg?variant=secondary&logo=apple&logoColor=ffffff" alt="Platform: macOS 14+" />
  <img src="https://shieldcn.dev/badge/Swift-5.10-orange.svg?variant=secondary&logo=swift&logoColor=ffffff" alt="Swift 5.10" />
  <img src="https://shieldcn.dev/badge/interface-menu%20bar%20%2B%20CLI-cyan.svg?variant=secondary" alt="Interface: menu bar + CLI" />
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
- **It is legible.** Every hold shows up in `pmset -g assertions` with a human-readable reason. No
  mystery wakeups.
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
- **Custom durations**: define your own quick-pick durations and a default.
- Global toggle shortcut, a live countdown in the menu bar, and launch at login.

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
open Wakehold.xcodeproj                    # build and run the menu-bar app
swift build --package-path WakeholdKit     # build the CLI and run the kit tests
```

Wakehold is a menu-bar app with no Dock icon. Look for the eye mark in the menu bar after launch.

## Usage

### Menu bar

Click the eye to open the menu: pick a duration, keep awake while an app runs, arm a post-session
action, or open Settings. The mark carries a diagonal slash when nothing is holding the Mac awake.

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

Settings has four tabs:

- **General**: keep the display on (default on), launch at login, and a shortcut to the macOS
  notification settings.
- **Durations**: add and remove quick-pick durations, and set the default.
- **Battery**: release on battery, release below a battery percentage, and release in Low Power Mode.
- **About**: version and links.

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
xcodebuild -project Wakehold.xcodeproj -scheme Wakehold build         # the app
```

If Xcode is installed but is not the active command-line toolchain, prefix these with
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

## Requirements

- macOS 14 (Sonoma) or later
- Apple Silicon or Intel

## License

MIT. See [LICENSE](LICENSE).
