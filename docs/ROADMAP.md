# Roadmap, Wakehold

Build phases in order. Each phase teaches a distinct chunk of the macOS platform. Don't skip.

## Phase 0, Core loop
- [x] Xcode project, SwiftUI app, `LSUIElement = true`, macOS 14 target, no sandbox.
- [x] IOKit power-assertion wrapper (acquire/release, both System and Display variants).
- [x] `WakeController` (`@Observable`) + `WakeSession` protocol + `SessionKind`.
- [x] `MenuBarExtra` with open/closed eye states (template image).
- [x] Manual/duration sessions: 1h / 2h / 3h / ∞, `Date`-target countdown (compute remaining on
      tick, don't trust a naive Timer).
**Teaches:** assertion lifecycle, MenuBarExtra scene, the session→assertion derivation.

## Phase 1, State that survives
- [ ] `@AppStorage` for last-used duration + prefs.
- [ ] Launch-at-login via `SMAppService.mainApp.register()`.
- [ ] Settings scene (free ⌘, in SwiftUI).
**Teaches:** app lifecycle, settings surface.

## Phase 2, Watchers + the keystone endpoint
- [ ] Process session via `DispatchSource.makeProcessSource(... .exit)`, with PID-exists
      recheck after arming and start-time capture against PID reuse.
- [ ] Port session (connect-attempt poll, coarse interval, suspended when unused).
- [ ] **Local control endpoint** on a Unix domain socket (0600, `getpeereid` check):
      `/session/start`, `/session/renew`, `/session/end`, `/status`. Lease TTL expiry.
**Teaches:** GCD dispatch sources, Network.framework. UNLOCKS CLI + hooks + remote at once.

## Phase 3, Developer surface
- [ ] CLI client: `wakehold -- <cmd>`, `wakehold --keep <pid|:port>`, `wakehold status|off`.
- [ ] Command session (spawn via `Process`, release on `terminationHandler`).
- [ ] Power guardrails: auto-release guarded sessions on unplug, below a battery threshold,
      or in Low Power Mode (`IOPSNotificationCreateRunLoopSource`).
- [ ] Global hotkey (KeyboardShortcuts package by Sindre Sorhus).
- [ ] Live remaining-time in menu bar title (expect possible NSStatusItem refactor: see ADR-006).
**Teaches:** Process API, IOKit power-source callbacks, SwiftPM deps, MenuBarExtra limits.

## Phase 4, Integrations + end actions
- [ ] Claude Code hooks: SessionStart → /session/start, Stop/PostToolUse → /session/renew,
      SessionEnd → /session/end. Copy-paste snippet in README.
- [ ] Hook snippets for Codex CLI, Gemini CLI, Cursor (same contract).
- [ ] Post-session actions: notify, display sleep, system sleep (`IOPMSleepSystem`),
      shut down / restart (System Events AppleScript, `NSAppleEventsUsageDescription`).
      Armed per occasion, visible in menu bar, cancelable, grace countdown.
**Teaches:** hook wiring against your own endpoint, TCC/Automation consent, AppleScript bridge.

## Phase 5, Later sources + ship
- [ ] App sessions (NSWorkspace launch/terminate, bundle id).
- [ ] Calendar sessions via EventKit (stretch).
- [ ] Sign + notarize (Developer ID, hardened runtime, staple).
- [ ] GitHub Releases (DMG/zip) + personal Homebrew tap.
- [ ] README with per-tool hook snippets.
- [ ] Sparkle 2 updates (optional; `brew upgrade` is the v1 path).

## Phase 6, Category parity (post-1.0, each item optional)
- [ ] Thermal-pressure pause and charging-only mode guardrails.
- [ ] Closed-lid keep-awake via an optional privileged helper with watchdog (ADR-012
      amendment). Separate approval flow; core never depends on it.
- [ ] Amphetamine-style environment triggers where they earn their keep (external display,
      schedule) as session sources, never new wake code paths.
- [ ] AppleScript / Shortcuts surface over the same endpoint contract.
