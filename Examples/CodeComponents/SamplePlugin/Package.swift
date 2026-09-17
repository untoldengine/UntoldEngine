// swift-tools-version: 6.0

import PackageDescription

/// What games depend on. Sources/SamplePluginEditor is deliberately not a target: only the
/// editor compiles it, against its own engine, as untold-plugin.json tells it to.
let package = Package(
    name: "SamplePlugin",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .visionOS(.v2),
    ],
    products: [
        .library(name: "SamplePlugin", targets: ["SamplePlugin"]),
    ],
    targets: [
        .target(
            name: "SamplePlugin",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
