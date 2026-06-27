// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "WaterRenderPlugin",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "WaterRenderPlugin", targets: ["WaterRenderPlugin"]),
    ],
    dependencies: [
        // This path works only while this fixture remains nested at
        // Examples/RenderingExtensions/SwiftPackagePlugin in the UntoldEngine
        // repository.
        //
        // If you copy this package elsewhere for local development, replace it
        // with the absolute or relative path to your UntoldEngine checkout:
        // .package(path: "/path/to/UntoldEngine")
        //
        // A distributed package should use the canonical repository URL and a
        // compatible release requirement instead:
        // .package(url: "https://example.com/UntoldEngine.git", from: "0.13.3")
        .package(path: "../../.."),
    ],
    targets: [
        .target(
            name: "WaterRenderPlugin",
            dependencies: [
                .product(name: "UntoldEngine", package: "UntoldEngine"),
            ],
            exclude: ["Shaders"],
            resources: [
                // SwiftPM does not compile Metal source in this fixture. Bundle
                // one precompiled metallib for every platform the package supports.
                .copy("Resources/WaterRenderPlugin.metallib"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "WaterRenderPluginTests",
            dependencies: [
                "WaterRenderPlugin",
                .product(name: "UntoldEngine", package: "UntoldEngine"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)
