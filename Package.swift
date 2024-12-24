// swift-tools-version:5.7

import PackageDescription

let package = Package(
    name: "UntoldEngine",
    platforms: [
        .macOS(.v10_15),
    ],
    products: [
        // Library product for the engine
        .library(
            name: "UntoldEngine",
            targets: ["UntoldEngine"]
        ),
        // Executable for testing
        .executable(
            name: "UntoldEngineTestApp",
            targets: ["UntoldEngineTestApp"]
        ),
        // Executable for the demo game
        .executable(
            name: "DemoGame",
            targets: ["DemoGame"]
        ),
        // Executable for the starter template
        .executable(
            name: "StarterGame",
            targets: ["StarterGame"]
        ),
    ],
    targets: [
        // Library target with the engine code
        .target(
            name: "UntoldEngine",
            dependencies: [],
            path: "Sources/UntoldEngine",
            exclude: [],
            resources: [
                // Include all Metal files and other resources
                .copy("UntoldEngineKernels/UntoldEngineKernels.metallib"),
                .process("Shaders"),
                .process("Resources/Models"),
                .process("Resources/HDR"),
            ],
            swiftSettings: [
                .unsafeFlags(["-framework", "Metal", "-framework", "Cocoa", "-framework", "QuartzCore"]),
            ]
        ),
        // Executable target for testing
        .executableTarget(
            name: "UntoldEngineTestApp",
            dependencies: ["UntoldEngine"],
            path: "Sources/UntoldEngineTestApp",
            swiftSettings: [
                .unsafeFlags(["-framework", "Metal", "-framework", "Cocoa", "-framework", "QuartzCore"]),
            ]
        ),
        // Executable target for the demo game
        .executableTarget(
            name: "DemoGame",
            dependencies: ["UntoldEngine"],
            path: "Sources/DemoGame",
            resources: [
                .process("Resources"), // Resources specific to the demo game
            ],
            swiftSettings: [
                .unsafeFlags(["-framework", "Metal", "-framework", "Cocoa", "-framework", "QuartzCore"]),
            ]
        ),
        // Executable target for the starter template
        .executableTarget(
            name: "StarterGame",
            dependencies: ["UntoldEngine"],
            path: "Sources/StarterGame",
            resources: [
                .process("Resources"), // Resources specific to the starter game
            ],
            swiftSettings: [
                .unsafeFlags(["-framework", "Metal", "-framework", "Cocoa", "-framework", "QuartzCore"]),
            ]
        ),
        // Test target for unit tests
        .testTarget(
            name: "UntoldEngineTests",
            dependencies: ["UntoldEngine"],
            path: "Tests/UntoldEngineTests"
        ),
    ]
)
