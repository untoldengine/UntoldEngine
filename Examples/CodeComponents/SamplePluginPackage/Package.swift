// swift-tools-version: 6.0

import PackageDescription

/// A plugin package: a Swift package of its own that several projects can share, as opposed to
/// a project's plugins folder, which belongs to that one game.
///
/// This manifest is what games depend on. Sources/SampleEditorPluginPackage is deliberately not
/// a target: only the editor compiles it, against its own engine, as untold-package.json tells it to.
///
/// The runtime defines plugins that exist in the game (the torus, the spline path, the path
/// follower), so it needs the engine. Here that is the checkout this sample sits in; a real
/// package names the engine by URL, the same one the games using it pin.
let package = Package(
    name: "SamplePluginPackage",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .visionOS(.v2),
    ],
    products: [
        .library(name: "SamplePluginPackage", targets: ["SamplePluginPackage"]),
    ],
    dependencies: [
        .package(name: "UntoldEngine", path: "../../.."),
    ],
    targets: [
        .target(
            name: "SamplePluginPackage",
            dependencies: [
                .product(name: "UntoldEngine", package: "UntoldEngine"),
                .product(name: "UntoldComponentKit", package: "UntoldEngine"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
