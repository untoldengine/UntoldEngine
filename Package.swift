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
            name: "CShaderTypes",
            path: "Sources/CShaderTypes",
            publicHeadersPath: ".",
            cSettings: [
                .headerSearchPath("."),
            ]
        ),
        .target(
            name: "UntoldEngine",
            dependencies: ["CShaderTypes"],
            path: "Sources/UntoldEngine",
            exclude: ["Shaders"],
            resources: [
                // Include all Metal files and other resources
                .copy("UntoldEngineKernels/UntoldEngineKernels.metallib"),
                .process("Resources/Models"),
                .process("Resources/Animations"),
                .process("Resources/HDR"),
            ],
            swiftSettings: [
                .unsafeFlags(["-framework", "Metal", "-framework", "Cocoa", "-framework", "QuartzCore"]),
            ]
        ),
        // Executable target for the demo game
        .executableTarget(
            name: "DemoGame",
            dependencies: ["UntoldEngine"],
            path: "Sources/DemoGame",
            swiftSettings: [
                .unsafeFlags(["-framework", "Metal", "-framework", "Cocoa", "-framework", "QuartzCore"]),
            ]
        ),
        // Executable target for the starter template
        .executableTarget(
            name: "StarterGame",
            dependencies: ["UntoldEngine"],
            path: "Sources/StarterGame",
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
