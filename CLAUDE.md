# Wakehold, Claude Code Context

A session-aware wake controller for macOS, written in Swift + SwiftUI. Menu-bar app + CLI +
local control endpoint. The machine stays awake exactly as long as a work session is alive
(process, port, command, Claude Code hook, or manual timer).

This is the project's always-loaded context. It holds only non-negotiable rules and pointers.
The full style and structure guide lives in `docs/CONVENTIONS.md`. Read it before writing code.

## Read before working

- `docs/PRODUCT.md`: what it is, feature phases, scope guardrails
- `docs/ARCHITECTURE.md`: WakeController / WakeSession model. Read first before touching wake logic
- `docs/CONVENTIONS.md`: code style, naming, structure, writing rules, design rules
- `docs/ROADMAP.md`: build order; do phases in sequence, don't skip ahead
- `docs/DECISIONS.md`: why things are the way they are; append new ADRs here
- `docs/BRAND.md`: identity, palette, voice (for UI and marketing work)
- `docs/RESEARCH.md`: market landscape and technical findings (July 2026) grounding the above

## Git rules (hard)

- Never commit or push without being asked. Stage and describe changes, then wait for approval.
- Commit messages describe the change only. Never add a co-author trailer, never mention an AI,
  agent, assistant, or tool as author or contributor. No "Generated with", no "Co-Authored-By".
- Conventional-commit style: `type(scope): summary`. Imperative mood, lower case, no trailing period.

## Platform rules (hard)

- Swift + SwiftUI, macOS 14+. Use `@Observable`, `MenuBarExtra`, `SMAppService`.
- Do NOT enable App Sandbox. Distributed outside the App Store; sandbox breaks process, port,
  and command features.
- `LSUIElement = true`: menu-bar only, no Dock icon.

## Architecture rules (hard)

- Two layers with a clean seam: the session service (registry + IOKit assertion + control
  endpoint) and the menu-bar UI (pure observer). Structure so the service could later split into
  an XPC or login-item helper. Do not split on day one.
- IOKit assertion logic lives only in `WakeController`. Views never touch IOKit.
- The wake assertion is a derived value: awake iff any session `isActive`. Never toggle the
  assertion from the UI. Mutate the session set and let the controller reconcile.
- Prefer event-driven over polling (`DispatchSource.makeProcessSource` over `kill(pid, 0)` loops).
- The assertion is released when the process dies. That is correct. Do not persist a "was awake"
  flag across launches; reconstruct intent from session sources.

## Writing rules (hard, apply everywhere: UI, comments, commits, docs)

- No em dashes. Use a comma, a colon, or rewrite. This applies to every character you emit.
- No emojis anywhere.
- No exclamation marks in UI text or copy.
- No filler adjectives: seamless, robust, comprehensive, powerful, cutting-edge, intuitive,
  innovative, next-level, world-class.
- No AI-flavored verbs: leverage, utilize, delve, explore, unlock, elevate.
- UI copy is short and direct. Prefer nouns over adjectives where space is tight.

## Comment rules (hard)

- Plain comments only. No decorative dividers, no rules, no ASCII art, no box borders.
- Comment only when the WHY is non-obvious: a hidden constraint, a subtle invariant, a workaround
  for a known bug. Never describe what the code does; well-named identifiers do that.
- If removing a comment would not confuse a future reader, do not write it.

## Conventions

- After any architectural decision, append an ADR to `docs/DECISIONS.md`.
- Tick roadmap boxes in `docs/ROADMAP.md` as phases complete.
- Session labels render in mono. UI voice is terse and technical (see `docs/BRAND.md`).
- Everything else: `docs/CONVENTIONS.md`.
