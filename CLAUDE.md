# Wakehold, Claude Code Context

Wakehold is a session-aware wake controller for macOS, written in Swift and SwiftUI. It is a
menu-bar app plus a CLI plus a local control endpoint. The machine stays awake exactly as long as
a work session is alive: a running process, a listening port, a wrapped command, an agent session,
or a manual timer. When the last session ends, Wakehold releases and the Mac sleeps normally.

This file is the always-loaded context and the full guide. It is self-contained: there is no
`docs/` directory. It holds the idea, the codebase map, the architecture rules, the code and
writing conventions, the design and brand rules, and the git workflow. Read it before writing code.

## The idea

Every wake source is a **Session** with a lifecycle: start, running, end. The wake assertion is a
*derived* value: the Mac is awake if and only if any session is active and no power guardrail is
suppressing. Nothing toggles the assertion directly. Code mutates the session set and a single
controller reconciles the IOKit assertion to match.

The menu bar is one client that visualizes sessions and offers a manual override. The real product
is the **session registry plus the local control endpoint** that any tool can open and close a
session against. The CLI, agent hooks, CI scripts, and remote clients are all just clients of that
endpoint.

Positioning: the keep-awake category uses a coffee metaphor and ships binary toggles. Wakehold
rejects that. The metaphor is vigilance: a watchful instrument that holds the machine open while
work is alive. Cool and technical, not warm and skeuomorphic.

## Codebase map

Two layers with a clean seam. The non-UI layer is a local Swift package, `WakeholdKit`, that the
app and the CLI link. The package builds and is tested without the UI, so the service could later
split into an XPC or login-item helper.

```
WakeholdKit/                         local Swift package; builds and tests headless
  Package.swift                      library + wakehold CLI executable + test targets
  Sources/WakeholdKit/
    Core/
      WakeController.swift           @MainActor, owns the assertion, reconcile(); the only decider
      WakeSession.swift              WakeSession protocol + SessionKind enum
      PowerAssertion.swift           IOKit wrapper; the ONLY file importing IOKit
      PowerMonitor.swift             power source / battery / Low Power Mode state, event-driven
      PowerGuardrail.swift           pure policy: does the current power state suppress the hold
      PostSessionAction.swift        the end-of-session action enum (notify, sleep, shut down, ...)
      SystemActions.swift            user-space mechanisms for those actions (IOPMSleepSystem, ...)
      EndActionController.swift      arms, counts down, and fires the post-session action once
      WakeholdError.swift            typed errors, one enum for the subsystem
      Log.swift                      shared os.Logger factory
    Sessions/                        one file per source; each conforms to WakeSession
      ManualSession.swift            timer or indefinite hold
      ManualSessionController.swift  orchestrates the single manual session and its expiry
      ProcessSession.swift           alive while a PID is alive (DispatchSource, not polling)
      PortSession.swift              alive while something listens on a port (coarse poll)
      AgentSession.swift             a renewing lease opened over the endpoint
      AppSession.swift               alive while a bundle id is running
    Service/
      ControlServer.swift            POSIX AF_UNIX listener + accept loop
      ControlRouter.swift            maps requests to registry calls
      ControlMessages.swift          request / response payloads
      ControlClient.swift            client side of the endpoint (used by the CLI)
      SessionRegistry.swift          registry glue: start / renew / end, leases, poll timer
      UnixSocket.swift               raw socket bind / listen / accept helpers
      HTTP.swift                     minimal HTTP/1.1 parse so curl --unix-socket works
      WakeholdPaths.swift            the socket path under Application Support
  Sources/wakehold/
    WakeholdCLI.swift                @main; status / off / --keep / -- <cmd> / hook subcommands
  Tests/WakeholdKitTests/            Swift Testing suites; run with `swift test`

Wakehold/                            app target: SwiftUI, menu bar only (LSUIElement)
  App/
    WakeholdApp.swift                @main, scene wiring, startup()
    WakeDuration.swift               a duration value (seconds or indefinite) with a label
    DurationStore.swift              the user's editable durations + the default, persisted
    GuardrailController.swift        bridges power preferences to the controller (suppress, display)
    AppSessionController.swift       NSWorkspace watcher for app sessions
    Hotkey.swift                     global toggle shortcut (KeyboardShortcuts package)
    LaunchAtLogin.swift              SMAppService wrapper
  UI/
    MenuBarView.swift                the dropdown; pure observer, sends intent only
    MenuBarLabel.swift               the menu-bar icon + optional countdown title
    MenuBarClock.swift               1s tick that drives the live countdown title
    EyeIcon.swift                    maps awake / idle to the eye asset names
    SettingsView.swift               tabbed settings (General, Durations, Battery, About)
  Resources/Assets.xcassets         AppIcon, AccentColor, EyeOpen / EyeClosed template marks
  Supporting/Info.plist             LSUIElement=true, usage strings

Wakehold.xcodeproj                  app target; links WakeholdKit
Design/                             render-icon.swift, render-menubar.swift (icon generators)
```

The `.xcodeproj` uses file-system-synchronized groups: a new `.swift` file under `Wakehold/`
compiles with no project edit. New files under `WakeholdKit/Sources/` are picked up by SwiftPM.

## Building and testing

Full Xcode is installed but is not the active command-line toolchain, so prefix build commands with
`DEVELOPER_DIR`:

```bash
# Kit + CLI tests, headless, the fast inner loop:
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path WakeholdKit

# The wakehold CLI binary:
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  swift build --package-path WakeholdKit -c release --product wakehold

# The app (open in Xcode, or from the command line):
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project Wakehold.xcodeproj -scheme Wakehold -configuration Debug \
  CODE_SIGNING_ALLOWED=NO build
```

The `KeyboardShortcuts` remote package needs network on first resolve; pin a clone dir with
`-clonedSourcePackagesDirPath` when building the app offline. Verify the kit with `swift test`
before pushing; verify the app with a clean `xcodebuild ... build`.

## Architecture rules (hard)

- Two layers, one seam: the session service (`WakeholdKit`) and the menu-bar UI. Keep the seam even
  while both live in-process. The service must build and test without the UI.
- IOKit assertion logic lives only in `PowerAssertion`, driven only by `WakeController`. Views never
  import IOKit and never call acquire or release.
- The assertion is derived: awake iff any session `isActive` and not suppressed. Never toggle the
  assertion from the UI. Mutate the session set and let `reconcile()` settle it. `reconcile()` is
  the single choke point; it also fires the post-session action on the last active-to-idle edge.
- Prefer event-driven over polling: `DispatchSource.makeProcessSource(.exit)` over `kill(pid,0)`
  loops. Suspend any coarse poll (ports) when no session of that kind exists.
- The assertion dies with the process, and that is correct. Do not persist a "was awake" flag.
  Reconstruct intent from live session sources on launch.
- Keeping the display on is the default. A preference can let the display sleep while the system
  stays awake. `PreventSystemSleep` is never used.

## Key decisions

The durable design choices and the why behind them. History is in git.

- **One wake code path.** A new session type is a new `SessionKind` case plus one file in
  `Sessions/`, never a new branch through the controller.
- **Unix-socket endpoint.** The control endpoint is a Unix domain socket, not a TCP port. A
  localhost port is reachable from the browser (DNS rebinding, form-POST CSRF) and from any local
  process; a UDS is not, and the filesystem scopes it to the user (mode 0600, `getpeereid` check).
- **No PreventSystemSleep.** It is AC-only and fights user intent. Keep-awake with the lid closed
  and no external display is out of scope; it needs a privileged root helper and is deferred.
- **Leased agent sessions.** Agent and remote sessions are leases with a TTL, renewed on activity.
  End hooks do not fire on a crash or SIGKILL, so the lease, not the goodbye, is the source of truth.
- **User-space end actions.** Post-session actions are user-space or one-time-TCC only; nothing
  needs root.
- **Manual session in its own coordinator.** The single manual session's lifecycle and expiry live
  in `ManualSessionController`, not in `WakeController`, so the controller stays a pure reconcile
  engine.
- **WakeholdKit package.** The non-UI layers are a local Swift package, so they build and test
  without the app and could split into a helper later.
- **POSIX sockets, not NWListener.** The endpoint uses `AF_UNIX` sockets with a `DispatchSource`
  accept loop and a minimal HTTP/1.1 parser. `NWListener` cannot bind a UDS; curl's `--unix-socket`
  keeps hooks trivial.
- **Display on by default.** The hold takes `PreventUserIdleDisplaySleep`; letting the display sleep
  is the opt-out. An assertion's type is fixed at creation, so changing the preference re-acquires.

When you make an architectural decision, record the why in the commit body and update the relevant
rule here if it changes one.

## Platform rules (hard)

- Swift and SwiftUI, macOS 14+. Use `@Observable`, `MenuBarExtra`, `SMAppService`.
- Do NOT enable App Sandbox: the process, port, and command features need access it forbids.
- `LSUIElement = true`: menu bar only, no Dock icon.

## Code conventions

- **Access control and finality.** Every type is `final` unless designed for subclassing. Default to
  `private`; widen only when a real caller needs it. Never expose stored mutable state as `public
  var`; expose `private(set)` and mutate through methods so the reconcile invariant cannot be
  bypassed.
- **Safety.** No force-unwrap or force-try in shipping code; use `guard let`, `if let`, or typed
  errors. Force-unwrap is allowed only in tests and in `@main` bootstrap. Prefer `struct` over
  `class`; a `class` only for identity or reference semantics (`WakeController` owns the assertion;
  sessions are structs behind `WakeSession`).
- **Model with enums, not flags.** `SessionKind` is an enum with associated values, not a set of
  `isProcess` / `isPort` booleans. Typed error enums, one per subsystem, not string errors.
- **Functions.** One job each; if the name needs "and", split it. Roughly 25 to 40 lines. Early
  return with `guard` at the top, happy path unindented below. Isolate side effects (IOKit,
  `Process`, sockets) in named methods, never in a computed property or a view body.
- **Concurrency.** `async`/`await` and structured concurrency for new code. Anything touching the
  assertion or the session set runs on the main actor; `WakeController` is `@MainActor`.
  `DispatchSource` and C callbacks hop to the main actor before mutating shared state
  (`MainActor.assumeIsolated` when the callback is known to fire on the main queue).
- **SwiftUI.** Views are dumb: read from an `@Observable` model, send intent. No IOKit, no
  `Process`, no networking, no business logic in `body`. Extract a subview when `body` grows past a
  screen or nests more than two levels.
- **DRY, threshold two.** Extract on the second occurrence, not the first. Do not pre-abstract.
- **Naming.** UpperCamelCase types, lowerCamelCase members. Booleans read as assertions (`isActive`,
  `hasAssertion`). Files are named after their primary type; one type per file by default.
  Protocols name a capability (`WakeSession`), never `IWakeSession` or `WakeSessionProtocol`.
- **Testing.** Unit-test Core and Service without the UI; that is the point of the seam. Test the
  reconcile invariant directly (active session acquires, last removal releases, inactive never
  acquires). Drive liveness through the mockable `WakeSession.isActive`.

## Writing rules (hard, apply everywhere: UI, comments, commits, docs, README)

- No em dashes. Use a comma, a colon, parentheses, or rewrite. This applies to every character.
- No emojis anywhere.
- No exclamation marks in UI text or copy.
- No filler adjectives: seamless, robust, comprehensive, powerful, cutting-edge, intuitive,
  innovative, next-level, world-class.
- No AI-flavored verbs: leverage, utilize, delve, explore, unlock, elevate. Use plain verbs: use,
  run, hold, release, watch, add, remove.
- UI copy is short and direct. Prefer nouns over adjectives where space is tight. The voice is
  terse, technical, faintly deadpan.

## Comment rules (hard)

- Plain comments only. No decorative dividers, rules, ASCII art, or box borders. `// MARK:` is fine
  (Xcode reads it); do not pad it into a banner.
- Comment only when the WHY is non-obvious: a hidden constraint, a subtle invariant, a workaround
  for a known bug, a non-obvious ordering. Never restate what the code does; well-named identifiers
  do that. If removing a comment would not confuse a future reader, do not write it.

## Design rules (SwiftUI)

The app is almost all system chrome: a menu-bar dropdown and a small settings pane. Keep it native
and plain.

- No gradient fills or gradient text as decoration; flat fills only. A gradient is allowed only
  inside the eye mark's active state, never in UI chrome.
- No glass or blur added for effect, no fake depth or neumorphism, no glow, neon, bloom, or text
  shadows. At most one subtle `.shadow(radius:)` for a real elevation cue.
- No shimmer, confetti, particle systems, or ambient animation.
- Respect system light and dark automatically. The menu-bar mark is a monochrome template image;
  macOS tints it. Never hard-code the menu-bar icon color.
- One signature motion: the blink on toggle (about 180ms, ease-out). Everything else is still.
  Never idle-animate in the menu bar. Respect Reduce Motion by skipping the blink.
- Prefer SF Symbols and system controls unless the brand mark requires a custom shape.

## Brand

- **Name.** Wakehold: it holds the wake and lets go when the work ends. Hold and release are the
  product's own verbs (assertions, sessions, leases).
- **Positioning.** Reject the coffee metaphor. The metaphor is vigilance: a watchful instrument.
  Personality: precise, quiet, watchful, faintly uncanny. Not playful, warm, or skeuomorphic.
- **The mark.** A lidless eye as pure geometry, never a rendered eyeball: one continuous almond
  outline plus a circular iris. It must read at 18px as a monochrome template. Open / active shows
  the full eye with a visible iris; idle / inactive is the open eye with a diagonal slash (an "off"
  read, chosen over a resting arc that read as an eyebrow at small sizes).
- **Color.** The category is warm; Wakehold is cool. One signal accent.

  | Role           | Name        | Hex     |
  |----------------|-------------|---------|
  | Core / ink     | Obsidian    | #0E1116 |
  | Surface        | Slate 900   | #161A22 |
  | Muted          | Ash         | #8A94A6 |
  | Accent (awake) | Signal Cyan | #3DD3E0 |
  | Timed / idle   | Muted Teal  | #2FA3A0 |
  | Danger         | Coral       | #FF5C5C |
  | Paper          | Off-white   | #F4F6F8 |

- **Typography.** Display and wordmark: Space Grotesk. UI and body: Geist or Inter. Mono: Geist Mono
  or JetBrains Mono. Session labels render in mono; that is where the dev-tool identity lives.
- **Voice examples.** Empty: "Nothing's keeping you awake." Active: "Awake". Timed: a live
  countdown. Auto-release: "node exited. Wakehold let go."

## Git rules (hard)

- Micro-commits: every small, self-contained unit of work gets its own commit immediately (one
  type, one file group, one behavior, one doc update). Never batch unrelated changes into one
  commit. Commits must be small enough to review at a glance.
- Push cadence: commit locally as you go, push to origin main when a feature or a unit of work is
  complete. One push may carry multiple micro-commits.
- Everything goes directly to main. No branches, no PRs for now.
- Commit messages: conventional-commit style, `type(scope): summary`, imperative mood, lower case,
  no trailing period. Body only when the why is not obvious from the diff.
- Strictly forbidden in commits: co-author trailers, "Generated with", any mention of an AI, agent,
  assistant, or tool as author or contributor. The human is the sole author of record.
- Never force-push. Never rewrite pushed history.

## Definition of done

- Builds with no new warnings; `swift test` passes.
- No force-unwrap and no leftover TODO escape hatches.
- A new session type is one file conforming to `WakeSession`, wired through the registry, with the
  controller untouched.
- Comments and copy follow the rules above.
- Committed as micro-commits with the why in the body when it is not obvious.
