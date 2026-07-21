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

Requires macOS 14+, Xcode 15+.

```bash
git clone https://github.com/KhaledSaeed18/wakehold
cd wakehold
open Wakehold.xcodeproj   # once the Xcode project exists
```

## License

MIT
