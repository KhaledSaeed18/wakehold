# Conventions, Wakehold

The full style, naming, structure, and design guide. CLAUDE.md carries the non-negotiables and
points here. Where a rule is language-general it applies as written; where it is Swift-specific it
is marked. This project is a native macOS SwiftUI app, so web idioms (CSS, JS modules, Tailwind)
are translated to their Swift equivalents rather than copied.

---

## 1. Writing style (all text: UI, comments, commits, docs, README)

- No em dashes anywhere. Use a comma, a colon, parentheses, or rewrite the sentence.
- No emojis.
- No exclamation marks in UI copy.
- No filler adjectives: seamless, robust, comprehensive, powerful, cutting-edge, intuitive,
  innovative, next-level, world-class.
- No AI-flavored verbs: leverage, utilize, delve, explore, unlock, elevate. Use plain verbs:
  use, run, hold, release, watch, add, remove.
- UI copy is short and direct. Prefer nouns over adjectives where space is tight.
- Voice is terse, technical, faintly deadpan (see BRAND.md).

## 2. Comments

Plain only. No decorative dividers, horizontal rules, ASCII art, or box borders.

    // Wrong
    // --- Assertion lifecycle -----------------------------
    // === Session registry ===

    // Correct
    // Assertion lifecycle
    // Session registry

Write a comment only when the WHY is non-obvious: a hidden constraint, a subtle invariant, a
workaround for a known bug, a non-obvious ordering requirement. Never restate what the code does.
If deleting the comment would not confuse a future reader, delete it.

Use `// MARK:` for Xcode's navigation gutter (that is a tooling feature, not decoration). Do not
pad it into a banner.

    // MARK: - Session lifecycle        // acceptable, Xcode reads this
    // MARK: ────── Session ──────      // not acceptable, decorative

---

## 3. Swift code style

### Access control and finality
Swift has no export syntax; the equivalent of "named exports over default" is disciplined access
control plus final-by-default.

- Every type is `final` unless it is explicitly designed for subclassing. Reference types default
  to `final class`.
- Default to `private`. Widen to `fileprivate`, `internal`, or `public` only when a real caller
  needs it. The session service's public surface is small and deliberate.
- Never expose stored mutable state as `public var`. Expose `private(set)` and mutate through
  methods, so the assertion-reconcile invariant cannot be bypassed.

### Types and safety
- No force-unwrap (`!`) and no force-try (`try!`) in shipping code. Use `guard let`, `if let`,
  or typed errors. Force-unwrap is allowed only in tests and in `@main` bootstrap where failure
  is a programmer error that should crash loudly.
- Prefer `struct` over `class`. Use a `class` only when identity or reference semantics are
  required (`WakeController` is a class because it owns the assertion; sessions can be structs
  behind the `WakeSession` protocol).
- Model state with enums and associated values, not boolean flags. `SessionKind` is an enum, not
  a set of `isProcess`/`isPort` booleans. This is the Swift form of "explicit over implicit".
- Use typed `Error` enums, not string errors. One error enum per subsystem.

### Functions
- One function, one job. If the name needs "and", split it.
- Roughly 25 to 40 lines. If longer, extract into private helpers or an `extension`.
- Early returns via `guard`. Guard clauses at the top, happy path unindented at the bottom.
- Pure functions where possible. Side effects (IOKit calls, spawning processes, network) are
  isolated in named methods, never buried in a computed property or a view body.
- Prefer named functions and computed properties over long closures inside view bodies.

### Concurrency
- Use `async`/`await` and structured concurrency. No completion-handler pyramids for new code.
- Anything touching the assertion or the session set runs on the main actor; mark the controller
  `@MainActor`. Watchers deliver events, the controller mutates state on the main actor.
- `DispatchSource` and `NWListener` callbacks hop to the main actor before mutating shared state.

### SwiftUI
- Views are dumb. They read from an `@Observable` model and send intent. No IOKit, no `Process`,
  no networking in a view.
- Extract subviews when a `body` grows past a screen or nests more than two levels.
- No business logic in `body`. Compute in the model, expose a property, read it.

---

## 4. Architecture and separation of concerns

Every piece of code has one home. Never mix layers.

- **Core**: `WakeController`, `WakeSession`, `SessionKind`, the IOKit assertion wrapper. No UI,
  no SwiftUI import.
- **Sessions**: one file per session source (process, port, command, agent, calendar). Each
  conforms to `WakeSession` and reports liveness. Adding a feature means adding a file here, not
  editing the controller.
- **Service**: the control endpoint (a UDS listener on POSIX sockets, ADR-018), request routing,
  the session registry glue.
- **CLI**: a thin client over the service. No wake logic of its own.
- **UI**: `MenuBarExtra`, menu content, settings scene. Observes the controller only.
- **App**: `@main`, wiring, launch-at-login.

The seam between Service and UI is load-bearing (see ARCHITECTURE.md). The Service must be
buildable and testable without the UI.

---

## 5. DRY

The threshold is two. Two occurrences means extract into one shared place. Do not pre-abstract a
single use; extract when the second use appears. A shared assertion string, a repeated port-parse,
a duplicated date-format: extract on the second sighting.

---

## 6. Naming

- Types, protocols: UpperCamelCase (`WakeController`, `WakeSession`, `PortWatcher`).
- Methods, properties, cases: lowerCamelCase (`isActive`, `reconcile()`, `.process(pid:)`).
- Booleans read as assertions: `isActive`, `hasAssertion`, `shouldReleaseOnUnplug`.
- Files are named after their primary type: `WakeController.swift`, `ProcessSession.swift`.
- Protocols describe capability or role, not `IWakeSession` or `WakeSessionProtocol`. Just
  `WakeSession`.
- No abbreviations except well-known ones (`pid`, `url`, `id`).

---

## 7. Project structure

The non-UI layers live in a local Swift package, `WakeholdKit`, that the app (and later the CLI)
links; the SwiftUI app target stays thin (ADR-017). Suggested layout; keep folders, Xcode groups,
and package sources in sync.

    WakeholdKit/                      // local Swift package: builds and tests without the UI
      Package.swift
      Sources/WakeholdKit/
        Core/
          WakeController.swift        // @MainActor, owns the assertion, reconcile()
          WakeSession.swift           // protocol + SessionKind enum
          PowerAssertion.swift        // IOKit wrapper, the only IOKit caller
          WakeholdError.swift         // typed errors
          Log.swift                   // shared Logger factory
        Sessions/                     // ManualSession + ManualSessionController; process/port/... later
        Service/                      // (later) control endpoint, router, registry (UDS, ADR-011)
      Tests/WakeholdKitTests/         // reconcile invariant, session behavior; run with swift test

    Wakehold/                         // app target: SwiftUI, menu bar only
      App/
        WakeholdApp.swift             // @main, scene wiring
      UI/
        MenuBarView.swift
        EyeIcon.swift                 // open/closed/timed states; SessionRowView, SettingsView later
      Resources/
        Assets.xcassets               // menu-bar template icons, app icon
      Supporting/
        Info.plist                    // LSUIElement=true

    Wakehold.xcodeproj                // app target; links the WakeholdKit package

Keep files small and single-purpose. If `MenuBarView.swift` grows past a screen, extract rows and
sections into their own files. One type per file is the default.

---

## 8. Design rules (SwiftUI, translated from the web anti-patterns)

This app has almost no chrome: a menu-bar dropdown and a small settings pane. Keep it native and
plain. The following are the SwiftUI forms of the web anti-patterns to avoid.

- No gradient fills or gradient text (`LinearGradient`, `AngularGradient`) as decoration. Flat
  fills only. Gradients are allowed only inside the eye icon's active state if the brand mark
  calls for it, never in UI chrome.
- No glass or blur chrome. Use the system `Material` only where a menu or popover already uses it
  by default; do not add `.background(.ultraThinMaterial)` for effect.
- No fake depth: no inset/outset shadow illusions (neumorphism).
- No glow, neon, or bloom.
- No text shadows.
- No heavy or decorative shadows. At most a single subtle `.shadow(radius:)` for a real elevation
  cue on a floating element. Menu content needs none.
- No shimmer or animated-gradient loading states.
- No confetti, particle systems, or ambient background animation.
- Respect system light/dark automatically. Menu-bar icon is a monochrome template image; macOS
  tints it. Never hard-code the menu-bar icon color.
- One signature motion only: the blink on toggle (~180ms, ease-out). Everything else is still.
  Never idle-animate in the menu bar (annoyance and battery).
- Prefer SF Symbols and system controls over custom-drawn UI unless the brand mark requires it.
- Respect `reduce motion`: skip the blink when the accessibility setting is on.

---

## 9. Testing

- The Core and Service layers are unit-tested without the UI. That is the point of the seam.
- Test the reconcile invariant directly: adding an active session acquires the assertion, removing
  the last active session releases it, an inactive session never acquires.
- Session liveness is mockable: `WakeSession.isActive` behind the protocol lets tests drive state
  without real processes or ports.
- No UI snapshot tests required at this stage; focus on the wake logic and the control endpoint.

---

## 10. Definition of done (per feature)

- Builds with no warnings.
- No force-unwrap, no `any` escape hatches left as TODO.
- New session type is one file conforming to `WakeSession`, wired through the registry, with the
  controller untouched.
- Comments follow section 2; text follows section 1.
- Roadmap box ticked, ADR appended if a decision was made.
- Changes staged and described. Commit only after approval (see CLAUDE.md git rules).
