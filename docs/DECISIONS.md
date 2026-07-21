# Decisions (ADR log)

Append a new entry for every meaningful decision. Format: what / why / alternatives rejected.

---

## ADR-001, Session model over timer model
**Decision:** The core primitive is a `WakeSession` with a lifecycle, not a timer. The wake
assertion is derived (awake iff any session active).
**Why:** Every feature (process, port, command, Claude Code, manual) is the same shape. Makes
new features "just another session source" instead of new wake code paths.
**Rejected:** Boolean-toggle-with-timer (the KeepingYouAwake model): doesn't compose, leads to
a tangle of flags.

## ADR-002, Local control endpoint as the keystone
**Decision:** A localhost endpoint (`/session/start|end`, `/status`) is built early (Phase 2).
**Why:** It makes "one app for everything" real: CLI, Claude Code hooks, CI, and the remote
Fedora agent all become clients opening/closing named sessions. No new UI per integration.
**Rejected:** Bespoke per-integration code inside the app.

## ADR-003, Do not sandbox
**Decision:** Ship un-sandboxed, distributed outside the App Store.
**Why:** Process spawning, arbitrary port checks, and some power info are restricted under App
Sandbox: exactly the features that differentiate Lidless.
**Trade-off:** No App Store distribution. Acceptable; Homebrew tap + notarized DMG instead.

## ADR-004, Name: Lidless
**Decision:** "Lidless" over "Lids".
**Why:** "Lids" (bare word) is dominated in search by a 2,000-store hat retailer. "Lidless" is
distinctive, search-ownable, and semantically precise (eyes that never close = machine stays
awake). No collision in the macOS dev-tool / Homebrew namespace.
**Note:** No legal conflict either way (category mismatch), but discoverability favors Lidless.

## ADR-005, Reject the coffee metaphor; watchful-eye identity
**Decision:** Cool "instrument" palette (Signal Cyan accent), lidless-eye mark, no cup.
**Why:** The entire category (Caffeine, Amphetamine, KeepingYouAwake, Theine, Wakey) uses coffee/
caffeine. Differentiate hard. The eye also encodes the technical truth (it watches sessions).

## ADR-006, macOS 14+ / modern stack
**Decision:** Target macOS 14+, use `@Observable`, `MenuBarExtra`, `SMAppService`.
**Why:** Learning-project goal favors current APIs; removes NSStatusItem/ObservableObject
boilerplate. Accept the narrower OS support.
**Watch:** `MenuBarExtra`'s dynamic-title limits may force a drop to `NSStatusItem` + `NSHostingView`
for live remaining-time, treat that refactor as a deliberate learning moment, not a surprise.

## ADR-007, Conventions split out of CLAUDE.md
**Decision:** CLAUDE.md holds only hard rules + pointers; the full style/structure guide lives in
`docs/CONVENTIONS.md`.
**Why:** CLAUDE.md is read every session, so it has a per-turn token cost. Keeping it lean while
the detailed guide is referenced on demand matches the lean-context practice used in the web repos.

## ADR-008, Web conventions translated to Swift, not copied
**Decision:** Ported conventions map JS/CSS idioms to Swift equivalents: "named exports" becomes
access control + `final` by default; "no gradients/glassmorphism" becomes SwiftUI Material/shadow
rules; the directory pattern becomes an Xcode-group layout matching the service/UI seam.
**Why:** First Swift project. Copying web rules verbatim would produce dead or misleading guidance
(Swift has no export syntax, no Tailwind). Translation keeps the intent actionable.

## ADR-009, Git author hygiene
**Decision:** Commits never carry a co-author trailer or any mention of an AI/agent/tool. Messages
describe the change only, conventional-commit style. No commit or push without approval.
**Why:** Clean authorship history; the human is the author of record.

## ADR-010, Name "Lidless" is compromised (supersedes ADR-004, decision pending)
**Finding (July 2026):** github.com/nghialuong/Lidless is an actively shipped, notarized,
Sparkle-updated macOS menu-bar keep-awake app, MIT, ~127 stars, trending, marketed
"for coding agents": our exact niche and audience. ADR-004's "no collision in the macOS
dev-tool namespace" no longer holds.
**Decision:** renamed to **Wakehold**. Vetted July 2026: no GitHub repos, no App Store apps
(macOS or iOS), no Homebrew formula/cask, no web presence, GitHub username free, wakehold.app
domain unregistered. Semantically exact: the app holds a wake assertion and releases it.
**Rejected:** Vigil (taken twice, including a keep-awake app), Unblink (active VLM project),
Argus (generic-crowded), Winkless ("Wink" search contamination, GitHub username taken),
Blinkless (near the Blink Shell / blink eye-strain app cluster), Wakewarden (crypto staking
collision), Pervigil (a Node sleep-inhibitor exists), Wakekeeper (an exact-category macOS
repo exists). Historical mentions of "Lidless" in ADR-004/005 and RESEARCH.md are intentional.
**Follow-up (manual):** rename the GitHub repo and local folder, register wakehold.app if
wanted.

## ADR-011, Control endpoint on a Unix domain socket, not localhost TCP
**Decision:** the control endpoint listens on a UDS (0600, `getpeereid` peer check) under
Application Support. TCP, if ever offered, is a compatibility mode: 127.0.0.1 only, bearer
token in a 0600 file, Host-header validation, no mutating GETs.
**Why:** an unauthenticated localhost port is reachable from browsers (DNS rebinding,
form-POST CSRF, the 0.0.0.0-day class) and from any local process. A UDS is unreachable from
browsers by construction and user-scoped by the filesystem. curl's `--unix-socket` keeps hook
one-liners trivial.
**Rejected:** plain 127.0.0.1 TCP ("loopback only" is not a security boundary).

## ADR-012, Assertion defaults; lid-closed is out of scope
**Decision:** default assertion is `PreventUserIdleSystemSleep`; keep-display-on is a
per-session opt-in (`PreventUserIdleDisplaySleep`); `PreventSystemSleep` is never used.
Keep-awake with the lid closed and no external display is a non-goal.
**Why:** no user-space assertion survives a lid close; the workaround genre (Macchiato,
Amphetamine Enhancer) needs a privileged root helper that fights the OS. Clamshell mode with
an external display already works. Staying unprivileged keeps the app small, safe, and
trustworthy.
**Trade-off:** we cede the closed-lid niche to Lidless-the-other-one and Macchiato.
**Amendment (July 2026):** product goal widened to full category coverage. Closed-lid moves
from "never" to "deferred": a strictly optional privileged helper (SMAppService daemon, one
admin approval, watchdog that restores normal sleep if the app dies), Phase 6 at the
earliest. The unprivileged core must never depend on it.

## ADR-013, Remote sessions are leases
**Decision:** sessions opened via the endpoint carry a TTL and must be renewed; the registry
expires silent sessions. Agent hooks renew on activity (Stop/PostToolUse).
**Why:** end hooks are best-effort: Claude Code's SessionEnd does not fire on SIGKILL or
crash. Trusting the goodbye leaks assertions forever; the lease bounds the damage.
**Rejected:** trusting /session/end alone; polling client PIDs (not always known or local).

## ADR-014, Post-session actions, user-space only
**Decision:** when the last session ends, an optionally armed action runs: notify, display
sleep, system sleep, shut down, restart. Armed per occasion, visible, cancelable, grace
countdown before destructive ones. Nothing requiring root (scheduled wake) ships.
**Why:** "run the agent overnight, shut down when done" is the headline gap no competitor
covers. All chosen actions are unprivileged or one-time-TCC (System Events AppleScript).
**Rejected:** sticky global end actions (surprise shutdowns destroy trust); root helpers.

## ADR-015, Micro-commit workflow (supersedes ADR-009's approval clause)
**Decision:** every small, self-contained unit of work (one type, one file group, one behavior,
one doc update) is committed immediately without prior approval. Push to origin main when a
feature or roadmap checkbox is complete; one push may carry several micro-commits. Everything
goes straight to main: no branches, no PRs for now. Never force-push, never rewrite pushed
history. Commit-message hygiene from ADR-009 stays in force (conventional-commit style, no
AI/agent/tool attribution, the human is the sole author of record).
**Why:** planning is done and build work produces many small, reviewable diffs. Gating each on
manual approval stalls throughput without adding review value when the diffs are already small
enough to read at a glance. Pushing per completed checkbox keeps origin current at natural
boundaries.
**Rejected:** approval before every commit (ADR-009's original stance, too slow for build work);
batching a session's work into one large commit (unreviewable, mixes concerns); feature branches
and PRs (needless overhead for a solo project at this stage).

## ADR-016, Manual session orchestration in a coordinator, not the controller
**Decision:** the single manual/duration session and its expiry timer live in a small
`ManualSessionController` (@MainActor) that drives `WakeController` through add/remove.
WakeController stays generic: it never learns that manual timers exist.
**Why:** keeps the controller a pure session-to-assertion engine (ADR-001, CONVENTIONS §4/§10)
and foreshadows the Phase 2 SessionRegistry, which will own session creation for every source the
same way. Manual is just the first source to get a coordinator. Expiry is anchored to the
absolute target Date (isActive reads the wall clock); the timer only nudges release, so a late
fire or a sleep/wake cannot hold the Mac past the target.
**Rejected:** manual state and expiry stored on WakeController (couples the generic core to one
session type); a self-scheduling class ManualSession (sessions stay value types; expiry is
orchestration, not session data).

## ADR-017, Extract WakeholdKit as a local Swift package
**Decision:** the non-UI layers (Core, Sessions, and later Service) live in a local Swift package
`WakeholdKit` that the app links statically. Its app-facing API is public; internals
(PowerAssertion, Log, WakeholdError) stay internal. Unit tests live in the package and run
headlessly with `swift test`.
**Why:** CONVENTIONS §9 requires the Core and Service to be "unit-tested without the UI." A
separate module makes that literal: the logic builds and tests with no app host and no SwiftUI,
so the reconcile invariant and session behavior are validated in isolation and in CI. It also
realizes the load-bearing service/UI seam (ARCHITECTURE) and gives the future CLI target the same
dependency. Widening the boundary API to public is the intended use of access control
(CONVENTIONS §3), not a workaround.
**Rejected:** an app-hosted test target (needs the GUI app as host, does not run headlessly, and
does not realize the no-UI seam); a dynamic framework target in the xcodeproj (more project
surface and needs embedding, while a static package library links with none).

## ADR-018, Control endpoint on POSIX AF_UNIX sockets, not NWListener
**Decision:** the control server is POSIX `AF_UNIX` sockets with a `DispatchSource` accepting
connections, a minimal HTTP/1.1 parser, and a getpeereid uid check. It is not Network.framework.
**Why:** ADR-011 fixed the transport as a Unix domain socket. `NWListener` cannot bind or listen
on a UDS; it is built around IP endpoints and ports. POSIX sockets are the only way to listen on
a filesystem socket, and a `DispatchSource` keeps the accept loop event-driven with no polling
thread. curl's `--unix-socket` speaks HTTP/1.1 over the socket, so a small parser keeps hook
one-liners trivial. CONVENTIONS §4's earlier "NWListener" note predated this and is corrected.
**Rejected:** NWListener (cannot bind a UDS); a localhost TCP NWListener (reopens the browser and
local-process attack surface that ADR-011 closed).
