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
        // Library product for the engine
        .library(
            name: "UntoldEngine",
            targets: ["UntoldEngine"]
        ),
        // Executable for the editor (macOS-only)
        .executable(
            name: "UntoldEngineEditor",
            targets: ["UntoldEngineEditor"]
        ),
        // Keep this sample if you still want a minimal showcase
        .executable(
            name: "SwiftUIDemo",
            targets: ["SwiftUIDemo"]
        ),
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
            resources: [
                // Prebuilt metallibs
                .copy("UntoldEngineKernels/UntoldEngineKernels.metallib"),
                .copy("UntoldEngineKernels/UntoldEngineKernels-ios.metallib"),
                .copy("UntoldEngineKernels/UntoldEngineKernels-iossim.metallib"),
                .copy("UntoldEngineKernels/UntoldEngineKernels-tvos.metallib"),
                .copy("UntoldEngineKernels/UntoldEngineKernels-tvossim.metallib"),
                .copy("UntoldEngineKernels/UntoldEngineKernels-xros.metallib"),
                .copy("UntoldEngineKernels/UntoldEngineKernels-xrossim.metallib"),
                // Engine sample assets
                .process("Resources/Models"),
                .process("Resources/HDR"),
                .process("Resources/ReferenceImages"),
                .process("Resources/textures"),
            ],
            linkerSettings: [
                .linkedFramework("Metal"),
                .linkedFramework("QuartzCore", .when(platforms: [.macOS, .iOS /* , .visionOS */ ])),
                .linkedFramework("AppKit", .when(platforms: [.macOS])),
                .linkedFramework("UIKit", .when(platforms: [.iOS])),
            ]
        ),

        // macOS-only Editor
        .executableTarget(
            name: "UntoldEngineEditor",
            dependencies: ["UntoldEngine"],
            path: "Sources/UntoldEngineEditor",
            linkerSettings: [
                .linkedFramework("Metal"),
                .linkedFramework("QuartzCore", .when(platforms: [.macOS])),
                .linkedFramework("AppKit", .when(platforms: [.macOS])),
            ]
        ),

        // Optional minimal app target you kept
        .executableTarget(
            name: "SwiftUIDemo",
            dependencies: ["UntoldEngine"],
            path: "Sources/SwiftUIDemo",
            linkerSettings: [
                .linkedFramework("Metal"),
                .linkedFramework("QuartzCore", .when(platforms: [.iOS, .macOS])),
                .linkedFramework("Cocoa", .when(platforms: [.macOS])),
                .linkedFramework("UIKit", .when(platforms: [.iOS])),
            ]
        ),

        // Tests
        .testTarget(
            name: "UntoldEngineTests",
            dependencies: ["UntoldEngine"],
            path: "Tests/UntoldEngineTests"
        ),
        .testTarget(
            name: "UntoldEngineRenderTests",
            dependencies: ["UntoldEngine"],
            path: "Tests/UntoldEngineRenderTests"
        ),
    ]
)

