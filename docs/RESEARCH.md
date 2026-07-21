# Research, market and technical (July 2026)

Findings that ground the product and architecture docs. Sources linked inline. Re-verify
anything load-bearing before building on it; the landscape moved fast in 2025-2026.

## Market landscape

### Established tools

- **KeepingYouAwake** (github.com/newmarcel/KeepingYouAwake): ~6.8k stars, MIT, Obj-C wrapper
  around `caffeinate`. Manual toggle, timed durations, a `keepingyouawake:///activate` URL
  scheme, battery-percentage auto-deactivate, Low Power Mode respect, and one trigger:
  activate when an external display connects. No process/app awareness, no schedule, no
  session-end actions, no AppleScript. Actively maintained (v1.6.8, Sept 2025). Distributed
  via GitHub Releases and Homebrew cask. Deliberately minimal.
- **Amphetamine** (Mac App Store, free): the feature ceiling of the category. Sessions:
  indefinite, timed, until a clock time, while-app-running, while-file-downloading, and
  Trigger-based. Triggers cover app running, external display, Wi-Fi SSID, IP, DNS, USB and
  Bluetooth devices, battery/power source, CPU threshold, idle time, drive mounted, schedule.
  Deep AppleScript dictionary and Shortcuts support. Because it is sandboxed for the App
  Store, it needs a separate non-store companion, **Amphetamine Enhancer**, just to see all
  running processes and to make Closed-Display Mode safe. Common complaint: preference
  sprawl. In Dec 2020 Apple threatened removal over the drug-reference name and pill icon;
  after public pushback Apple reversed in Jan 2021. Lesson: App Store distribution carries
  review risk and its sandbox forces a two-app split for exactly the features we care about.
- Smaller players: Caffeine (the 2006 original, maintained again), Lungo, Theine, Coca
  (added closed-lid support in 2.0), Caffeinated, Owly. All are toggles or timers, some with
  one or two triggers.
- **`caffeinate`** ships with macOS: `caffeinate -i <cmd>` and `-w <pid>` already give exact
  process-scoped wake with no UI, no status, no registry. It is the canonical dev answer on
  HN and Reddit, and the baseline we must beat on ergonomics, not on mechanism.

### The 2025-2026 agent-aware wave (direct validation, and direct competition)

- **SleepSleuth** ($1.99, MAS, macOS 14+): built explicitly because of Claude Code sessions.
  Shows every process holding a power assertion; pin a process and wake auto-releases when
  it exits. Closest existing thing to our process sessions.
- **Agents Sleep Preventer** (github.com/CharlonTank/claude-code-sleep-preventer, MIT,
  Rust + Swift): auto-detects Claude Code / Codex activity, holds wake while agents work,
  releases after idle. Small, unpolished, scope-creeping (voice dictation).
- **Macchiato** (github.com/ObservedObserver/Macchiato, Apache-2.0): keep-awake with lid
  closed via a privileged LaunchDaemon helper. Manual toggle, not session-aware.
- **Lidless** (github.com/nghialuong/Lidless, MIT, ~127 stars, trending, v0.1.1 June 2026):
  a menu-bar keep-awake app marketed "for coding agents". Closed-lid via privileged helper,
  watchdog, thermal and battery guardrails, Sparkle updates, notarized DMG. Not
  session-aware, no CLI, no endpoint. It owns our name in our niche. See ADR-010.
- Multiple 2025-2026 blog posts hand-wire `caffeinate` into Claude Code hooks, meaning
  people are manually assembling our hook feature from shell scripts.

### Gap analysis

Recurring user asks across the category: process/app-conditioned wake in the simple tools,
closed-lid without an adapter dance, real scriptability, and visibility into why the machine
is or is not awake. Nobody ships: port-based sessions, a local control endpoint any tool can
open sessions against, a unified registry across manual/process/port/command/agent sources,
or **post-session actions** (sleep, display off, shut down, notify when the last session
ends). Amphetamine can start on triggers but has no "then do X when it ends". The session
model plus end actions is the unclaimed ground.

## Technical findings

### Power assertions

- Default assertion: `kIOPMAssertionTypePreventUserIdleSystemSleep`. It blocks idle system
  sleep only; the display still sleeps. `PreventUserIdleDisplaySleep` keeps the screen on
  (implies system awake), costs real power, opt-in per session. `PreventSystemSleep` blocks
  even scheduled sleep but is honored on AC only and is the wrong tool; never default to it.
- **No user-space assertion survives a lid close.** Clamshell mode (external display,
  keyboard, power) works because powerd holds its own assertion for the display; inside
  clamshell our assertions behave normally. Lid-closed-without-display requires a privileged
  helper that fights the OS (Macchiato, Amphetamine Enhancer). Out of scope; see ADR-012.
- Assertions die with the creating process (kernel-enforced), which matches our no-persisted-
  state rule. Set `kIOPMAssertionNameKey` and `HumanReadableReason` so `pmset -g assertions`
  explains us; power users will look.
- Battery: silently draining a battery is the top complaint in the category. KYA-style
  guardrails (auto-release below a battery threshold, respect Low Power Mode) are table
  stakes.

### Post-session actions (privilege map)

- Display sleep: `pmset displaysleepnow` equivalent, no privileges. Safest default action.
- System sleep: `IOPMSleepSystem`, callable unprivileged. Feasible.
- Shutdown / restart / log out: AppleScript to System Events via `NSAppleScript`; graceful
  (apps can cancel), needs one-time Automation (TCC) consent and an
  `NSAppleEventsUsageDescription`. Feasible with consent.
- Scheduled wake (`pmset schedule`): root, needs a privileged helper. Deferred.
- Idle detection for arming actions: `CGEventSourceSecondsSinceLastEventType`, no permission
  needed.

### Session detection

- Process exit: `DispatchSource.makeProcessSource(.exit)` (kqueue). Verify the PID exists
  after arming (creation race), capture process start time via `proc_pidinfo` to guard PID
  reuse, cancel sources on removal (retain-cycle classic).
- Port: inherently polled. Options: libproc fd walk (what lsof does, unprivileged for
  same-user processes, root-owned listeners invisible), bind-attempt, or connect-attempt.
  Coarse interval (5-15s), suspend the poll when no port sessions exist.
- GUI app by bundle id: `NSWorkspace` launch/terminate notifications, event-driven, free.
- Later-phase trigger primitives exist for display connect (`CGDisplayRegisterReconfigurationCallback`),
  camera in use (CoreMediaIO `DeviceIsRunningSomewhere`), audio playing (CoreAudio
  equivalent).

### Control endpoint security

An unauthenticated localhost TCP port is attackable from the browser (DNS rebinding, simple
form-POST CSRF, the 0.0.0.0-day class) and from any local process. Decision (ADR-011):

- Primary transport: **Unix domain socket**, `~/Library/Application Support/<app>/<app>.sock`,
  mode 0600, peer credentials via `getpeereid`. Browsers cannot reach it at all. curl
  supports `--unix-socket`, so hook one-liners stay trivial.
- Optional TCP compatibility mode: 127.0.0.1 only, random bearer token in a 0600 file (the
  Jupyter pattern), validate the Host header, JSON content type required, no mutating GETs.

### Agent hooks

- Claude Code: `SessionStart` and `SessionEnd` events, JSON on stdin with `session_id` and
  `cwd` (our session key and label). Hooks can be `command` (curl) or native `http` POST.
- `SessionEnd` does not fire on SIGKILL or crash, so hook sessions must be **leases**: renew
  on activity (`Stop`, `PostToolUse`), expire after a TTL of silence. Never trust a remote
  client to always say goodbye.
- Codex CLI, Gemini CLI (v0.26+), and Cursor (1.7+) all ship compatible hook systems. One
  generic start/heartbeat/end contract covers all four; ship copy-paste snippets per tool.

### Distribution

- Homebrew 5.0: casks must be signed and notarized; unsigned casks are removed from the core
  tap by September 2026. Start with a personal tap; core tap wants notability.
- Notarization: Developer ID cert, hardened runtime, `notarytool`, staple the ticket.
  Sequoia removed the right-click-open bypass, so un-notarized builds effectively hard-fail.
- Sparkle 2 works unsandboxed; the signing interplay is the main pitfall. Acceptable v1
  alternative: no updater, rely on `brew upgrade`.
- Login item: `SMAppService.mainApp`; if the service splits later, `SMAppService.agent`.

### Footprint

Comparable menu-bar utilities idle at 20-50 MB RSS and ~0% CPU. Goals: under 50 MB, zero
timer wakeups when no sessions are active, let App Nap apply when idle (an app holding an
IOPM assertion is exempt while holding it, which is correct during sessions). Update the
remaining-time text only while the menu is open.
