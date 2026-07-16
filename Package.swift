//
//  Package.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

// swift-tools-version: 6.0
import PackageDescription

let engineResources: [Resource] = {
    var resources: [Resource] = [
        .copy("UntoldEngineKernels/UntoldEngineKernels.metallib"), // macOS
        .copy("UntoldEngineKernels/UntoldEngineKernels-ios.metallib"), // iOS (device)
        .copy("UntoldEngineKernels/UntoldEngineKernels-iossim.metallib"), // iOS (simulator)
        .copy("UntoldEngineKernels/UntoldEngineKernels-tvos.metallib"), // tvOS (device)
        .copy("UntoldEngineKernels/UntoldEngineKernels-tvossim.metallib"), // tvOS (simulator)
        .copy("UntoldEngineKernels/UntoldEngineKernels-xros.metallib"), // visionOS (device)
        .copy("UntoldEngineKernels/UntoldEngineKernels-xrossim.metallib"), // visionOS (simulator)
    ]

    // Keep model resources optional so package builds still succeed when that folder is absent.
    if FileManager.default.fileExists(atPath: "Sources/UntoldEngine/Resources/Models") {
        resources.append(.process("Resources/Models"))
    }

    resources.append(contentsOf: [
        .process("Resources/HDR"),
        .process("Resources/textures"),
    ])

    return resources
}()

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

        .library(
            name: "UntoldEngineShaderSupport",
            targets: ["UntoldEngineShaderSupport"]
        ),

        .library(name: "UntoldEngineXR", targets: ["UntoldEngineXR"]),

        .library(name: "UntoldEngineAR", targets: ["UntoldEngineAR"]),

        // NOTE: Demo executables are intentionally NOT declared as products so they
        // stay hidden from consumers of the package. SwiftPM creates implicit
        // products for executable targets in the root package, so they remain
        // runnable during engine development via `swift run <TargetName>`,
        // e.g. `swift run ShowcaseDemo`.
    ],
    dependencies: [],
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
            name: "UntoldEngineShaderSupport",
            path: "Sources/UntoldEngineShaderSupport",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include"),
            ]
        ),
        .target(
            name: "UntoldEngine",
            dependencies: ["CShaderTypes"],
            path: "Sources/UntoldEngine",
            exclude: ["Shaders"],

            // 📦 Ship prebuilt metallibs for each platform; pick at runtime.
            resources: engineResources,
            swiftSettings: [
                // Compile engine stats collection only in debug by default.
                // Release builds can still opt in explicitly with -DENGINE_STATS_ENABLED.
                .define("ENGINE_STATS_ENABLED", .when(configuration: .debug)),
                .swiftLanguageMode(.v6),
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
                // Must mirror the engine flag so #if ENGINE_STATS_ENABLED blocks in this
                // target are active; without it, xrFrameStartTime is never declared and
                // finalizeXRStatsAndMonitors receives 0.0, producing garbage frameTotalMs.
                .define("ENGINE_STATS_ENABLED", .when(configuration: .debug)),
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
                .swiftLanguageMode(.v6),
            ],
            linkerSettings: [
                .linkedFramework("Metal", .when(platforms: [.iOS])),
                .linkedFramework("MetalKit", .when(platforms: [.iOS])),
                .linkedFramework("ARKit", .when(platforms: [.iOS])),
            ]
        ),
        .target(
            name: "DemoUtils",
            dependencies: ["UntoldEngine"],
            path: "Sources/Demos/DemoUtils",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        // These executables are macOS-only
        .executableTarget(
            name: "ShowcaseDemo",
            dependencies: ["UntoldEngine"],
            path: "Sources/Demos/ShowcaseDemo",
            swiftSettings: [.swiftLanguageMode(.v6)],
            linkerSettings: [
                .linkedFramework("Metal"),
                .linkedFramework("QuartzCore", .when(platforms: [.macOS, .iOS])),
                .linkedFramework("AppKit", .when(platforms: [.macOS])),
            ]
        ),
        .executableTarget(
            name: "StarterDemo",
            dependencies: ["UntoldEngine", "DemoUtils"],
            path: "Sources/Demos/StarterDemo",
            exclude: ["README.md"],
            swiftSettings: [.swiftLanguageMode(.v6)],
            linkerSettings: [
                .linkedFramework("Metal"),
                .linkedFramework("QuartzCore", .when(platforms: [.macOS, .iOS])),
                .linkedFramework("AppKit", .when(platforms: [.macOS])),
            ]
        ),
        .executableTarget(
            name: "LargeSceneStreamingDemo",
            dependencies: ["UntoldEngine", "DemoUtils"],
            path: "Sources/Demos/LargeSceneStreamingDemo",
            exclude: ["README.md"],
            swiftSettings: [.swiftLanguageMode(.v6)],
            linkerSettings: [
                .linkedFramework("Metal"),
                .linkedFramework("QuartzCore", .when(platforms: [.macOS, .iOS])),
                .linkedFramework("AppKit", .when(platforms: [.macOS])),
            ]
        ),
        .executableTarget(
            name: "InteractionGameplayDemo",
            dependencies: ["UntoldEngine", "DemoUtils"],
            path: "Sources/Demos/InteractionGameplayDemo",
            exclude: ["README.md"],
            swiftSettings: [.swiftLanguageMode(.v6)],
            linkerSettings: [
                .linkedFramework("Metal"),
                .linkedFramework("QuartzCore", .when(platforms: [.macOS, .iOS])),
                .linkedFramework("AppKit", .when(platforms: [.macOS])),
            ]
        ),
        .executableTarget(
            name: "RenderingQualityDemo",
            dependencies: ["UntoldEngine", "DemoUtils"],
            path: "Sources/Demos/RenderingQualityDemo",
            exclude: ["README.md"],
            swiftSettings: [.swiftLanguageMode(.v6)],
            linkerSettings: [
                .linkedFramework("Metal"),
                .linkedFramework("QuartzCore", .when(platforms: [.macOS, .iOS])),
                .linkedFramework("AppKit", .when(platforms: [.macOS])),
            ]
        ),
        .executableTarget(
            name: "ExporterPipelineDemo",
            dependencies: ["UntoldEngine", "DemoUtils"],
            path: "Sources/Demos/ExporterPipelineDemo",
            exclude: ["README.md"],
            swiftSettings: [.swiftLanguageMode(.v6)],
            linkerSettings: [
                .linkedFramework("Metal"),
                .linkedFramework("QuartzCore", .when(platforms: [.macOS, .iOS])),
                .linkedFramework("AppKit", .when(platforms: [.macOS])),
            ]
        ),
        .executableTarget(
            name: "LightingDemo",
            dependencies: ["UntoldEngine", "DemoUtils"],
            path: "Sources/Demos/LightingDemo",
            swiftSettings: [.swiftLanguageMode(.v6)],
            linkerSettings: [
                .linkedFramework("Metal"),
                .linkedFramework("QuartzCore", .when(platforms: [.macOS, .iOS])),
                .linkedFramework("AppKit", .when(platforms: [.macOS])),
            ]
        ),
        .executableTarget(
            name: "Sandbox",
            dependencies: ["UntoldEngine"],
            path: "Sources/Sandbox",
            swiftSettings: [.swiftLanguageMode(.v6)],
            linkerSettings: [
                .linkedFramework("Metal"),
                .linkedFramework("QuartzCore", .when(platforms: [.macOS, .iOS])),
                .linkedFramework("AppKit", .when(platforms: [.macOS])),
            ]
        ),
        // Test target for unit tests
        .testTarget(
            name: "UntoldEngineTests",
            dependencies: ["UntoldEngine", "UntoldEngineShaderSupport"],
            path: "Tests/UntoldEngineTests",
            swiftSettings: [.swiftLanguageMode(.v6)]
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
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
