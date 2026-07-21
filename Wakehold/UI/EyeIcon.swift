// The menu-bar mark. Phase 0 uses SF Symbols, which are monochrome templates macOS tints, so
// open vs closed reads instantly at 18px. The custom almond-arc mark from BRAND.md replaces
// these names later without touching the scene, so the icon decision stays in one place.
enum EyeIcon {
    // `eye` for awake (open, watching), `eye.slash` for idle (resting).
    static func systemImageName(isAwake: Bool) -> String {
        isAwake ? "eye" : "eye.slash"
    }
}
