// swift-tools-version: 6.0
import PackageDescription

/// Standalone on purpose: it needs macOS 15 for `Synchronization.Mutex`, which is
/// above the engine's minimum, and it does not depend on the engine.
let package = Package(
    name: "ConcurrencyBench",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(name: "ConcurrencyBench", swiftSettings: [.swiftLanguageMode(.v5)]),
    ]
)
