// swift-tools-version: 6.0

import PackageDescription

/// What games depend on. Sources/SamplePluginEditor is deliberately not a target: only the
/// editor compiles it, against its own engine, as untold-plugin.json tells it to.
///
/// The runtime defines a component and a kind of entity (the torus), so it needs the engine.
/// Here that is the checkout this sample sits in; a real plugin names the engine by URL, the
/// same one the games using it pin.
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
    dependencies: [
        .package(name: "UntoldEngine", path: "../../.."),
    ],
    targets: [
        .target(
            name: "SamplePlugin",
            dependencies: [
                .product(name: "UntoldEngine", package: "UntoldEngine"),
                .product(name: "UntoldComponentKit", package: "UntoldEngine"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
