// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Task3",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "__ENGINE_PATH__")
    ],
    targets: [
        .executableTarget(
            name: "Task3",
            dependencies: [.product(name: "UntoldEngine", package: "UntoldEngine")]
        )
    ]
)
