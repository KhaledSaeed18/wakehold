// swift-tools-version: 6.0
import PackageDescription

// The non-UI core: session model, WakeController, IOKit assertion, session sources. Kept a
// separate module so it builds and tests without the app or SwiftUI. The app and the CLI both
// link this. Swift 5 language mode matches the app target for now.
let package = Package(
    name: "WakeholdKit",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "WakeholdKit", targets: ["WakeholdKit"]),
        .executable(name: "wakehold", targets: ["wakehold"]),
    ],
    targets: [
        // The action titles and the grace notice are user-facing, so this target carries a String
        // Catalog and reads it through Bundle.module.
        .target(name: "WakeholdKit", resources: [.process("Resources/Localizable.xcstrings")]),
        .executableTarget(name: "wakehold", dependencies: ["WakeholdKit"]),
        .testTarget(name: "WakeholdKitTests", dependencies: ["WakeholdKit"]),
    ],
    swiftLanguageModes: [.v5]
)
