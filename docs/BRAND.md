# Brand, Wakehold

## Strategy
- **Name:** Wakehold: it holds the wake and lets go when the work ends. Hold and release are
  the product's own verbs (assertions, sessions, leases), so the name states the mechanism.
  Chosen after "Lidless" was found taken by a direct competitor (ADR-010); vetted clean
  across GitHub, App Store, Homebrew, web, and the wakehold.app domain (July 2026).
- **Positioning:** Reject the coffee/caffeine metaphor the whole category uses. Metaphor is
  **vigilance**: a watchful instrument that holds your machine open while work is alive.
- **Personality:** precise, quiet, watchful, faintly uncanny. Alert / minimal / dependable /
  unblinking. NOT playful, warm, chunky, or skeuomorphic.
- **Tagline:** "Holds. Then lets go." (alts: "Awake while it matters." / "Never closes.")

## The mark
The watchful-eye mark survives the rename: the eye is the *watcher* identity, not a pun on
the name. A lidless eye as pure geometry: never a rendered eyeball. One continuous almond outline +
a circular iris. Must survive as an 18px monochrome menu-bar template image.

States:
- **Open / active (awake):** full almond, iris centered/visible. Active iris glows accent color.
- **Closed / inactive:** the open eye with a diagonal slash through it (an "off" read). Chosen
  over a resting-arc: at 18px a single arc read as an eyebrow, the slashed eye reads instantly.
- **Timed (optional):** iris + thin arc/lash accent, signals countdown vs indefinite.

Construction: 24×24 grid, 2px inset safe area, ~2px stroke, iris ≈ ⅓ eye width. Menu-bar version
is monochrome template (macOS tints it). Colored iris only in app-icon / marketing versions.

Wordmark: lowercase `wakehold`, geometric grotesque. The counter of the `o` *is* the iris,
logotype and icon are the same idea.

## Color
Category is warm/brown; go cool/instrument to stand apart. One signal accent.

| Role            | Name        | Hex       |
|-----------------|-------------|-----------|
| Core / ink      | Obsidian    | #0E1116   |
| Surface         | Slate 900   | #161A22   |
| Muted           | Ash         | #8A94A6   |
| Accent (awake)  | Signal Cyan | #3DD3E0   |
| Accent alt      | Ember Amber | #F5A623   |
| Timed / idle    | Muted Teal  | #2FA3A0   |
| Danger          | Coral       | #FF5C5C   |
| Paper           | Off-white   | #F4F6F8   |

Chosen accent: **Signal Cyan** (differentiates from the warm category; "instrument on").
Amber is the fallback if you prefer literal "a light left on = awake".

## Typography
- Display / wordmark: **Space Grotesk** (technical character): or Hanken Grotesk.
- UI / body: **Geist** (or Inter).
- Mono (CLI, code, session labels): **Geist Mono** / JetBrains Mono. Session labels
  (`node · :3000`, `claude-code`) render in mono, that's where the dev-tool identity lives.

## Motion
One signature moment: a **blink** on toggle (~180ms ease-out): snap shut then open on activate,
open→close on deactivate. Everywhere else is still. NEVER idle-animate in the menu bar (annoying +
battery). At 18px, open vs closed must read instantly in pure monochrome, test that first.

## Voice
Terse, technical, faintly deadpan. It's a watcher.
- Empty: "Nothing's keeping you awake."
- Active: "Awake: 2 sessions" / "Awake · node, :3000"
- Timed: "Awake for 1:47:22"
- Auto-release notification: "node exited. Wakehold let go."

## Asset checklist
- Icon SVG master (24-grid): open / closed / timed
- Menu-bar template PNG/PDF @1x/2x/3x, open & closed
- App icon .icns (16→1024), colored iris
- Wordmark SVG: horizontal + stacked, light & dark
- Color tokens: CSS vars / Swift Color extension / JSON
- DMG background, GitHub social card 1280×640, README hero, favicon
- Clear space = iris diameter all sides; min mark 16px
