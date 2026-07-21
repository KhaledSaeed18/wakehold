# Product, Wakehold

## One-liner
A session-aware wake controller for developers. Your Mac stays awake exactly as long as
your work is alive, a process, a port, a command, a Claude Code session, or a manual timer.

## Why it exists
KeepingYouAwake, Amphetamine, Caffeine et al. are binary toggles wrapped in a coffee metaphor.
They can't answer "stay awake while *this specific thing* is running." This app models the real
intent: **an active work session that should hold the machine open, and release automatically
when it ends.** The category is warm/coffee; we are cool/watchful: an instrument, not a mug.

A 2025-2026 wave of agent-aware tools (SleepSleuth, Agents Sleep Preventer, Macchiato, plus
blog posts hand-wiring `caffeinate` into Claude Code hooks) proves the demand, but each covers
one slice. Nobody ships the unified session registry, port sessions, a control endpoint any
tool can talk to, or post-session actions. See `docs/RESEARCH.md` for the full landscape.

## Target user
A developer on a Mac laptop who runs long unattended work: agent sessions, builds, test
suites, dev servers, downloads. They know `caffeinate` exists and find it clumsy. They install
via Homebrew, read `pmset -g assertions` when suspicious, and value small, legible tools.

## Core mental model
Everything is a **Session** with a lifecycle: start → running → end. The wake assertion is a
*derived* value: the Mac is awake iff any session is active. The menu bar is just one client
that visualizes sessions and offers manual override. The real product is the **session registry +
local control endpoint** that anything can open/close a session against.

## Session types
- **Manual / duration**: classic timer (1h/2h/3h/∞), the KeepingYouAwake baseline.
- **Process**: awake while PID X (or a named process) is alive.
- **Port**: awake while something listens on :PORT (e.g. your dev server).
- **Command**: `wakehold -- pnpm build`; hold until the wrapped command exits, then release.
- **Agent**: opened/closed by agent-CLI hooks hitting the local control endpoint. Claude Code
  first; Codex CLI, Gemini CLI, and Cursor ship compatible hook systems, so one generic
  start/heartbeat/end contract covers all of them. Agent sessions are leases with a TTL,
  renewed on activity, because end hooks don't fire on a crash or SIGKILL.
- **App** (later): awake while a GUI app (bundle id) is running, via NSWorkspace
  notifications. The Amphetamine feature people actually use, cheap for us to add.
- **Calendar** (stretch): awake during EventKit events / focus blocks.

## Session modifiers (policy, orthogonal to session type)
- **Display**: keep the display on (default), or let it sleep while the system stays awake, for
  unattended work. See ADR-019.
- **Power guardrails**: auto-release when unplugged, below a battery percentage, or when Low
  Power Mode is on. KeepingYouAwake made these table stakes; battery drain is the category's
  top complaint. Later additions from the competitor set: pause on thermal pressure,
  charging-only mode.

## Post-session actions (the differentiator nobody has)
When the *last* session ends, optionally do something: nothing (default), sleep the display,
sleep the Mac, shut down, restart, or notify. "Run the agent overnight, shut down when it
finishes" is the headline use case. All actions are user-space or one-time-TCC feasible
(see RESEARCH.md); anything needing root (scheduled wake) is deferred. Arm per occasion, not
as a sticky global: an armed shutdown must be visible in the menu bar and cancelable.

## Feature phases
Phase 0: manual/duration + IOKit assertion + MenuBarExtra open/closed states.
Phase 1: persistence (@AppStorage), launch-at-login (SMAppService), Settings scene.
Phase 2: process + port watchers; **local control endpoint** (unlocks CLI + hooks + remote).
Phase 3: command wrapper CLI, power guardrails, global hotkey, live remaining-time in menu title.
Phase 4: agent hook integrations (Claude Code first), post-session actions.
Phase 5: app sessions, calendar (stretch), Sparkle updates.
Phase 6: category parity, all optional: thermal/charging guardrails, closed-lid helper,
environment triggers, AppleScript/Shortcuts.

## Scope guardrails (this WILL try to balloon)
- Ship the control endpoint fast; everything developer-oriented hangs off it.
- Resist a settings-screen swamp. Every feature is *just another session source*, never a new
  wake code path.
- No sandbox. No App Store constraints driving design.
- Learning project first (Swift/macOS platform), useful tool second: both, but in that order.

## Success criteria
- Idle footprint under 50 MB RSS, zero timer wakeups with no active sessions.
- A Claude Code session holds the Mac awake and releases within the lease TTL of ending.
- `pmset -g assertions` shows a named, human-readable assertion while awake.
- Install to working hook integration in under five minutes via Homebrew plus one snippet.

## Non-goals
- Not a Pomodoro/focus timer. Not a mouse-jiggler / fake-activity or presence-keeping tool
  (Slack/Teams idle status). Not cross-platform (macOS only).
- No keep-awake with the lid closed and no external display in v1. It requires a privileged
  root helper (the Macchiato / Amphetamine Enhancer genre) and is deferred to a late phase as
  a strictly optional install; the unprivileged core never depends on it. Clamshell mode with
  an external display works with no help from us. See ADR-012.
- No App Store distribution (sandbox kills the differentiating features; see ADR-003 and the
  Amphetamine Enhancer story in RESEARCH.md).
