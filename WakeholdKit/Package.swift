// swift-tools-version: 6.0
import PackageDescription

// The non-UI core: session model, WakeController, IOKit assertion, session sources. Kept a
// separate module so it builds and tests without the app or SwiftUI (CONVENTIONS §9). The app
// and, later, the CLI both link this. Swift 5 language mode matches the app target for now.
let package = Package(
    name: "WakeholdKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "WakeholdKit", targets: ["WakeholdKit"]),
    ],
    targets: [
        .target(name: "WakeholdKit"),
        .testTarget(name: "WakeholdKitTests", dependencies: ["WakeholdKit"]),
    ],
    swiftLanguageModes: [.v5]
)
