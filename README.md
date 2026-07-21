# Wakehold

**Never closes.** A session-aware wake controller for macOS.

Your Mac stays awake exactly as long as your work is alive: a running process, a listening
port, a wrapped command, a Claude Code session, or a manual timer. When the work ends, Wakehold
lets go.

Not a coffee-cup toggle. Wakehold models the real intent: an active work *session* that holds the
machine open and releases automatically.

## Features (planned)

- Manual keep-awake with durations (1h / 2h / 3h / ∞)
- Stay awake while a **process** (PID) is alive
- Stay awake while a **port** is in use (your dev server)
- **Command wrapper:** `wakehold -- pnpm build`: awake until it exits
- **Agent sessions** (Claude Code, Codex CLI, Gemini CLI, Cursor) via hook snippets and a
  local control endpoint
- **Post-session actions:** when the last session ends, optionally sleep the display, sleep
  the Mac, shut down, or notify
- Power guardrails: auto-release on unplug, low battery, or Low Power Mode
- Menu-bar app + CLI + local control endpoint (Unix socket)

## Status

Early development. See `docs/ROADMAP.md`.

## Build

Requires macOS 14+, Xcode 16+.

```bash
git clone https://github.com/KhaledSaeed18/wakehold
cd wakehold
open Wakehold.xcodeproj                    # the menu-bar app
swift build --package-path WakeholdKit     # the wakehold CLI and WakeholdKit tests
```

## CLI

The `wakehold` CLI talks to the running app over its local control endpoint:

```bash
wakehold -- pnpm build        # hold while the command runs, release on exit
wakehold --keep 51234         # hold while process 51234 is alive
wakehold --keep :3000         # hold while something listens on :3000
wakehold status               # show what is holding the Mac awake
wakehold off                  # release sessions opened over the endpoint
```

## Agent hooks

Agent CLIs keep the Mac awake through `wakehold hook`, which reads the tool's event JSON on
stdin and opens a renewing lease keyed by the agent's session id. If the app is not running the
hook does nothing, so it never gets in the agent's way, and the lease expires on its own if the
agent crashes without a goodbye.

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

## License

MIT
