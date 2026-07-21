# Architecture, Wakehold

For code style, naming, file layout, and design rules, see `docs/CONVENTIONS.md`. This document
covers the technical model only.

## Layer boundary (do not violate)
Two layers, clean seam between them:

1. **Session Service**: owns the session registry, the IOKit power assertion, and the local
   control endpoint. Zero UIKit/SwiftUI. Could later become an XPC service or login-item helper.
2. **Menu-bar UI**: pure observer/controller of the service. Touches no IOKit.

Keep the boundary from day one even while both live in-process, so the service *can* split later.

## Core types

```swift
enum SessionKind {
    case manual(until: Date?)      // nil = indefinite
    case process(pid: pid_t)
    case port(UInt16)
    case command(pid: pid_t, label: String)
    case agent(label: String)      // Claude Code / remote via control endpoint
    case calendar(eventID: String)
}

protocol WakeSession: Identifiable {
    var id: UUID { get }
    var label: String { get }
    var kind: SessionKind { get }
    var isActive: Bool { get }     // event-driven where possible, polled otherwise
}
```

## WakeController (the only thing touching IOKit)

```swift
@Observable
final class WakeController {
    private(set) var sessions: [any WakeSession] = []
    private var assertionID: IOPMAssertionID = 0

    var isAwake: Bool { sessions.contains { $0.isActive } }

    func add(_ s: any WakeSession) { sessions.append(s); reconcile() }
    func remove(_ id: UUID)        { sessions.removeAll { $0.id == id }; reconcile() }

    // Single choke point: derive assertion from session state.
    private func reconcile() {
        if isAwake && assertionID == 0 { acquire() }
        else if !isAwake && assertionID != 0 { release() }
    }
    // acquire()/release() wrap IOPMAssertionCreateWithName / IOPMAssertionRelease
}
```

- Assertion type: `kIOPMAssertionTypePreventUserIdleDisplaySleep` (display) by default, so the
  screen stays lit (ADR-019). A "Keep the display on" preference set to false swaps in
  `PreventUserIdleSystemSleep`, which lets the display sleep while the system stays awake, for
  unattended work. The type is fixed at creation, so the controller re-acquires when the
  preference changes. Never use `PreventSystemSleep`: it is AC-only and fights user intent.
- Set `kIOPMAssertionNameKey` and `HumanReadableReason` (e.g. "holding 2 sessions: node :3000,
  claude-code") so `pmset -g assertions` is self-explanatory.
- No assertion survives a lid close; clamshell mode with an external display works because
  powerd holds its own assertion. Lid-closed-without-display is out of scope (ADR-012).
- **Never** call acquire/release from views. Views call `add`/`remove`; `reconcile()` decides.
- `reconcile()` also fires the post-session action when the session set transitions from
  some-active to none-active and an action is armed (see below).

## Session liveness, prefer events over polling
- Process: `DispatchSource.makeProcessSource(identifier: pid, eventMask: .exit)` → fires on death,
  call `remove(id)`. No polling loop. Verify the PID still exists after arming (creation race)
  and capture the process start time via `proc_pidinfo` to guard against PID reuse. Cancel the
  source when the session is removed (classic retain-cycle leak otherwise).
- Command: spawn via `Process`; on `terminationHandler`, remove the session.
- Port: no clean event API. Poll with a connect-attempt to 127.0.0.1:port (or a libproc fd
  walk when we need to know who owns it) on a coarse interval (5-15s). Suspend the poll
  entirely when no port sessions exist. Document as best-effort; root-owned listeners are
  invisible to the libproc walk without root.
- Agent: sessions opened via the endpoint are **leases**. The client renews on activity
  (Claude Code `Stop`/`PostToolUse` hooks); the registry expires the session after a TTL of
  silence (default ~10 min). End hooks are best-effort (they don't fire on SIGKILL or crash),
  so the lease, not the goodbye, is the source of truth.
- App (later): `NSWorkspace.shared.notificationCenter` launch/terminate notifications.
- Power guardrails: register a run-loop source on `IOPSNotificationCreateRunLoopSource`; on
  unplug, low battery threshold, or Low Power Mode, release guarded sessions.

## Post-session actions
When `reconcile()` observes the last active session end and an action is armed, run it once
and disarm. Actions and mechanisms (all user-space or one-time TCC, see RESEARCH.md):
- Display sleep (default suggestion, safest): the `pmset displaysleepnow` equivalent.
- System sleep: `IOPMSleepSystem`, unprivileged.
- Shut down / restart / log out: AppleScript to System Events via `NSAppleScript`, graceful,
  requires `NSAppleEventsUsageDescription` and a one-time Automation consent prompt.
- Notify: `UserNotifications`.
Armed actions are per-occasion, visible in the menu bar, and cancelable. A grace countdown
(e.g. 60s with a notification) precedes destructive actions. Nothing here needs root;
scheduled wake (`pmset schedule`) would, and is deferred.

## Local control endpoint (Phase 2, the keystone)
Transport: a **Unix domain socket** at `~/Library/Application Support/Wakehold/wakehold.sock`,
mode 0600, peer checked via `getpeereid`. Not TCP: an unauthenticated localhost port is
reachable from the browser (DNS rebinding, form-POST CSRF) and from any local process; a UDS
is unreachable from browsers by construction and scoped to the user by the filesystem
(ADR-011). curl speaks `--unix-socket`, so hook one-liners stay trivial. If a TCP
compatibility mode is ever added: 127.0.0.1 only, random bearer token in a 0600 file,
validate the Host header, JSON content type required, no mutating GETs.

Minimal API:

```
POST /session/start   { "label": "claude-code", "kind": "agent", "ttl": 600 } -> { "id": "..." }
POST /session/renew   { "id": "..." }                                         -> { "ok": true }
POST /session/end     { "id": "..." }                                         -> { "ok": true }
GET  /status                            -> { "awake": true, "sessions": [...] }
```

This single endpoint is what makes "gather everything into one app" true: the CLI, agent
hooks, CI scripts, and remote clients are all just *clients* opening/closing named sessions.
`renew` exists because agent sessions are leases (see above).

## CLI (Phase 3)
Thin client over the endpoint (or direct if run in-process):
- `wakehold -- pnpm build`    → command session, auto-release on exit
- `wakehold --keep <pid|:port>`→ process/port session
- `wakehold status` / `wakehold off`

## Agent hook integration (Phase 4)
Claude Code first: a `SessionStart` hook POSTs `/session/start` (using the `session_id` and
`cwd` from the hook's stdin JSON as key and label), `Stop`/`PostToolUse` renews the lease,
`SessionEnd` POSTs `/session/end`. Codex CLI, Gemini CLI (0.26+), and Cursor (1.7+) have
compatible hook systems; the same start/renew/end contract covers all of them. Ship
copy-paste hook snippets per tool.

## Distribution
- Menu-bar only: `LSUIElement = true`. macOS 14+.
- **Do not sandbox** (process spawning + power info + arbitrary port checks need it off).
- Sign + notarize with Developer ID ($99/yr Apple Developer Program). Non-negotiable:
  Sequoia removed the right-click-open bypass, and Homebrew removes unsigned casks from the
  core tap by September 2026. Staple the ticket.
- Ship via GitHub Releases + a personal Homebrew tap; core tap later once notable.
- Updates: `brew upgrade` is enough for v1; Sparkle 2 later (mind the signing interplay).
- Assertion dies with the process: correct; do not persist "was awake" state.
