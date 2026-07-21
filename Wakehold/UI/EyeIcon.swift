// The menu-bar mark: the custom lidless-eye template images from the asset catalog (BRAND). macOS
// tints the template, so open vs closed reads instantly in monochrome. Open when awake (almond +
// iris, watching), a flattened almond when idle (resting, no iris, never an X).
enum EyeIcon {
    static func imageName(isAwake: Bool) -> String {
        isAwake ? "EyeOpen" : "EyeClosed"
    }
}
