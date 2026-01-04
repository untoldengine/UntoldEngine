// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "UntoldEngine",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .visionOS(.v2),
    ],
    products: [
        // Library product for the engine
        .library(
            name: "UntoldEngine",
            targets: ["UntoldEngine"]
        ),

        .library(name: "UntoldEngineXR", targets: ["UntoldEngineXR"]),

        .library(name: "UntoldEngineAR", targets: ["UntoldEngineAR"]),

        // Executable for the demo game
        .executable(
            name: "DemoGame",
            targets: ["DemoGame"]
        ),

        // CLI tool for project creation
        .executable(
            name: "untoldengine-create",
            targets: ["UntoldEngineCLI"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    ],
    targets: [
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

            // 📦 Ship prebuilt metallibs for each platform; pick at runtime.
            resources: [
                .copy("UntoldEngineKernels/UntoldEngineKernels.metallib"), // macOS
                .copy("UntoldEngineKernels/UntoldEngineKernels-ios.metallib"), // iOS (device)
                .copy("UntoldEngineKernels/UntoldEngineKernels-iossim.metallib"), // iOS (simulator)
                .copy("UntoldEngineKernels/UntoldEngineKernels-tvos.metallib"), // tvOS (device)
                .copy("UntoldEngineKernels/UntoldEngineKernels-tvossim.metallib"), // tvOS (simulator)
                .copy("UntoldEngineKernels/UntoldEngineKernels-xros.metallib"), // visionOS (device)
                .copy("UntoldEngineKernels/UntoldEngineKernels-xrossim.metallib"), // visionOS (simulator)
                .process("Resources/Models"),
                .process("Resources/HDR"),
                .process("Resources/textures"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ],
            linkerSettings: [
                // Common
                .linkedFramework("Metal"),
                .linkedFramework("QuartzCore", .when(platforms: [.macOS, .iOS /* , .visionOS */ ])),

                // macOS UI stack
                .linkedFramework("AppKit", .when(platforms: [.macOS])),

                // iOS UI stack (only if some targets import UIKit)
                .linkedFramework("UIKit", .when(platforms: [.iOS])),
            ]
        ),

        // Vision OS target
        .target(
            name: "UntoldEngineXR",
            dependencies: [
                "UntoldEngine",
            ],
            path: "Sources/UntoldEngineXR",
            swiftSettings: [
                // CompositorServices and ARKit only exist on visionOS
                .define("VISIONOS_AVAILABLE", .when(platforms: [.visionOS])),
                .swiftLanguageMode(.v6),
            ],
            linkerSettings: [
                .linkedFramework("Metal", .when(platforms: [.visionOS])),
                .linkedFramework("CompositorServices", .when(platforms: [.visionOS])),
                .linkedFramework("ARKit", .when(platforms: [.visionOS])),
            ]
        ),
        // iOS AR target
        .target(
            name: "UntoldEngineAR",
            dependencies: ["UntoldEngine"],
            path: "Sources/UntoldEngineAR",
            swiftSettings: [
                .define("AR_AVAILABLE", .when(platforms: [.iOS])),
                .swiftLanguageMode(.v5),
            ],
            linkerSettings: [
                .linkedFramework("Metal", .when(platforms: [.iOS])),
                .linkedFramework("MetalKit", .when(platforms: [.iOS])),
                .linkedFramework("ARKit", .when(platforms: [.iOS])),
            ]
        ),
        // These executables are macOS-only
        .executableTarget(
            name: "DemoGame",
            dependencies: ["UntoldEngine"],
            path: "Sources/DemoGame",
            swiftSettings: [.swiftLanguageMode(.v5)],
            linkerSettings: [
                .linkedFramework("Metal"),
                .linkedFramework("QuartzCore", .when(platforms: [.macOS, .iOS])),
                .linkedFramework("AppKit", .when(platforms: [.macOS])),
            ]
        ),
        // CLI tool target (macOS only)
        .executableTarget(
            name: "UntoldEngineCLI",
            dependencies: [
                "UntoldEngine",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/UntoldEngineCLI",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // Test target for unit tests
        .testTarget(
            name: "UntoldEngineTests",
            dependencies: ["UntoldEngine"],
            path: "Tests/UntoldEngineTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // Render-specific test target
        .testTarget(
            name: "UntoldEngineRenderTests",
            dependencies: ["UntoldEngine"],
            path: "Tests/UntoldEngineRenderTests",
            exclude: ["Resources/compare_psnr.py"],
            resources: [
                .copy("Resources/compare_psnr.py"),
                .process("Resources"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
