// swift-tools-version:5.7

import PackageDescription

let package = Package(
    name: "UntoldEngine",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        // Create a library product for the engine
        .library(
            name: "UntoldEngine",
            targets: ["UntoldEngine"]
        ),
        // Create an executable product for testing
        .executable(
            name: "UntoldEngineTestApp",
            targets: ["UntoldEngineTestApp"]
        )
    ],
    targets: [
        // Define the library target with the engine code
        .target(
            name: "UntoldEngine",
            dependencies: [],
            path: "Sources/UntoldEngine",
            exclude: [
            ],
            resources: [
                // Include all Metal files in the Shaders directory
                .copy("UntoldEngineKernels/UntoldEngineKernels.metallib"),
                .process("Shaders"), 
                .process("Resources/Models"),
                .process("Resources/HDR")
            ],
            swiftSettings: [
                .unsafeFlags(["-framework", "Metal", "-framework", "Cocoa", "-framework", "QuartzCore"])
            ]
        ),
        // Define the executable target for testing, which depends on the library
        .executableTarget(
            name: "UntoldEngineTestApp",
            dependencies: ["UntoldEngine"],
            swiftSettings: [
                .unsafeFlags(["-framework", "Metal", "-framework", "Cocoa", "-framework", "QuartzCore"])
            ]
        ),
    ]
)
