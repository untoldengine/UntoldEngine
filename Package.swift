// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "UntoldEngine",
    platforms: [
        .macOS(.v14),
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
                .process("UntoldEngineKernels/UntoldEngineKernels.air"),
                .process("UntoldEngineKernels/UntoldEngineKernels.metal"),
                .process("Resources/Models"),
                .process("Resources/Animations"),
                .process("Resources/HDR"),
                .process("Resources/ReferenceImages"),
                .process("Resources/textures"),
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
        // Render-specific test target
        .testTarget(
            name: "UntoldEngineRenderTests",
            dependencies: ["UntoldEngine"],
            path: "Tests/UntoldEngineRenderTests"
        ),
    ]
)
