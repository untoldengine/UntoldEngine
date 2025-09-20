// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "UntoldEngine",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        // .visionOS(.v1),
    ],
    products: [
        .library(name: "UntoldEngine", targets: ["UntoldEngine"]),
        .executable(name: "DemoGame", targets: ["DemoGame"]),
        .executable(name: "StarterGame", targets: ["StarterGame"]),
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
                .copy("UntoldEngineKernels/UntoldEngineKernels.metallib"),        // macOS
                .copy("UntoldEngineKernels/UntoldEngineKernels-ios.metallib"),    // iOS (device)
                // .copy("UntoldEngineKernels/UntoldEngineKernels-xros.metallib"), // visionOS (optional)
                .process("Resources/Models"),
                .process("Resources/HDR"),
                .process("Resources/ReferenceImages"),
                .process("Resources/textures"),
            ],

            linkerSettings: [
                // Common
                .linkedFramework("Metal"),
                .linkedFramework("QuartzCore", .when(platforms: [.macOS, .iOS/*, .visionOS*/])),

                // macOS UI stack
                .linkedFramework("AppKit", .when(platforms: [.macOS])),

                // iOS UI stack (only if some targets import UIKit)
                .linkedFramework("UIKit", .when(platforms: [.iOS])),
            ]
        ),

        // These executables are macOS-only
        .executableTarget(
            name: "DemoGame",
            dependencies: ["UntoldEngine"],
            path: "Sources/DemoGame",
            linkerSettings: [
                .linkedFramework("Metal"),
                .linkedFramework("QuartzCore", .when(platforms: [.macOS, .iOS])),
                .linkedFramework("AppKit", .when(platforms: [.macOS])),
            ]
        ),
        .executableTarget(
            name: "StarterGame",
            dependencies: ["UntoldEngine"],
            path: "Sources/StarterGame",
            linkerSettings: [
                .linkedFramework("Metal"),
                .linkedFramework("QuartzCore", .when(platforms: [.macOS, .iOS])),
                .linkedFramework("AppKit", .when(platforms: [.macOS])),
            ]
        ),

        .testTarget(name: "UntoldEngineTests", dependencies: ["UntoldEngine"], path: "Tests/UntoldEngineTests"),
        .testTarget(name: "UntoldEngineRenderTests", dependencies: ["UntoldEngine"], path: "Tests/UntoldEngineRenderTests"),
    ]
)

