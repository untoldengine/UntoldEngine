# Creating a Rendering Extension Plugin

This tutorial builds a reusable Swift package that draws procedural geometry
into Untold Engine. The finished plugin owns its shader library, render pipeline,
and render-graph pass. It uses the engine camera and scene color/depth targets
without accessing private renderer state.

Use this tutorial when rendering code must be shared by more than one
application. For application-local code, start with
[Using Rendering Extensions](UsingRenderingExtensions.md). A complete buildable
package is available in
[Examples/RenderingExtensions/SwiftPackagePlugin](../../Examples/RenderingExtensions/SwiftPackagePlugin/README.md).

## What You Will Build

The plugin will:

1. load a package-owned precompiled Metal library;
2. register a pipeline using the engine's working scene formats;
3. add a pass at a stable render-graph stage;
4. read the current eye's camera matrices;
5. create a safe encoder for the scene color and depth targets;
6. issue a depth-tested triangle draw; and
7. install and uninstall as one owned plugin transaction.

## Prerequisites

- Xcode with the SDKs for every platform you intend to support;
- Swift 6;
- an Untold Engine checkout or released package dependency; and
- a reverse-DNS namespace owned by you.

The examples use `com.example.procedural`. Replace it with your own namespace.

## 1. Create the Package

From the directory that will contain the package:

```sh
mkdir ProceduralRenderPlugin
cd ProceduralRenderPlugin
swift package init --type library --name ProceduralRenderPlugin
```

Use this layout:

```text
ProceduralRenderPlugin/
├── Package.swift
├── Scripts/
│   └── build-metallib.sh
├── Sources/
│   └── ProceduralRenderPlugin/
│       ├── ProceduralRenderPlugin.swift
│       ├── ProceduralRenderExtension.swift
│       ├── Resources/
│       │   └── ProceduralShaders-macos.metallib
│       └── Shaders/
│           └── ProceduralShaders.metal
└── Tests/
    └── ProceduralRenderPluginTests/
        └── ProceduralRenderPluginTests.swift
```

## 2. Configure `Package.swift`

For local development, point SwiftPM at your engine checkout:

```swift
// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ProceduralRenderPlugin",
    platforms: [.macOS(.v14)],
    products: [
        .library(
            name: "ProceduralRenderPlugin",
            targets: ["ProceduralRenderPlugin"]
        ),
    ],
    dependencies: [
        .package(path: "/path/to/UntoldEngine"),
    ],
    targets: [
        .target(
            name: "ProceduralRenderPlugin",
            dependencies: [
                .product(name: "UntoldEngine", package: "UntoldEngine"),
            ],
            exclude: ["Shaders"],
            resources: [
                .copy("Resources/ProceduralShaders-macos.metallib"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "ProceduralRenderPluginTests",
            dependencies: [
                "ProceduralRenderPlugin",
                .product(name: "UntoldEngine", package: "UntoldEngine"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
```

The dependency path is resolved relative to this `Package.swift`. Use an
absolute path only for local development. A distributed plugin should use the
canonical engine repository URL and a compatible release requirement. The
application and plugin must resolve the same Untold Engine package identity and
version.

This workflow excludes Metal source from the target and copies a precompiled
library. It does not ask SwiftPM to compile the package shader.

## 3. Define Stable IDs

Create `ProceduralRenderPlugin.swift`:

```swift
import Foundation
import UntoldEngine

public enum ProceduralPluginContract {
    public static let pluginID = "com.example.procedural"
    public static let extensionID = "com.example.procedural.renderer"
    public static let shaderLibraryID: RenderShaderLibraryID =
        "com.example.procedural.shaders"
    public static let pipelineID: RenderPipelineType =
        "com.example.procedural.scene"
    public static let passID = "com.example.procedural.scene-pass"
}
```

IDs occupy engine-wide registries. Namespace shader libraries, pipelines,
passes, textures, buffers, and argument layouts. An extension supplied by a
plugin must equal the plugin ID or begin with the plugin ID followed by a dot.

## 4. Add the Plugin Manifest

Continue in `ProceduralRenderPlugin.swift`:

```swift
public struct ProceduralRenderPlugin: RenderExtensionPlugin {
    public static var bundledMetallibURL: URL? {
        Bundle.module.url(
            forResource: "ProceduralShaders-macos",
            withExtension: "metallib"
        )
    }

    public let manifest = RenderExtensionPluginManifest(
        id: ProceduralPluginContract.pluginID,
        displayName: "Procedural Rendering",
        version: RenderExtensionPluginVersion(major: 1, minor: 0, patch: 0)
    )

    public init() {}

    public func makeRenderExtensions() -> [any RenderExtension] {
        [ProceduralRenderExtension(shaderBundle: .module)]
    }
}

@discardableResult
public func registerProceduralRenderPlugin()
    -> RenderExtensionPluginInstallationResult
{
    RenderExtensionPluginRegistry.shared.install(ProceduralRenderPlugin())
}
```

The public installation function is the consumer entry point. Do not also
register the internal extension with `setRendering`; the plugin registry owns
its complete lifecycle.

## 5. Write the Metal Shader

Create `Shaders/ProceduralShaders.metal`:

```metal
#include <metal_stdlib>
using namespace metal;

struct ProceduralVertexOut {
    float4 position [[position]];
    float3 color;
};

vertex ProceduralVertexOut proceduralVertex(
    uint vertexID [[vertex_id]],
    constant float4x4 &viewProjection [[buffer(0)]])
{
    constexpr float3 positions[] = {
        float3(-0.75, 0.0, 0.0),
        float3( 0.75, 0.0, 0.0),
        float3( 0.0, 1.1, 0.0),
    };
    constexpr float3 colors[] = {
        float3(0.95, 0.15, 0.10),
        float3(0.10, 0.75, 0.35),
        float3(0.10, 0.35, 0.95),
    };

    ProceduralVertexOut out;
    out.position = viewProjection * float4(positions[vertexID], 1.0);
    out.color = colors[vertexID];
    return out;
}

fragment float4 proceduralFragment(ProceduralVertexOut in [[stage_in]]) {
    return float4(in.color, 1.0);
}
```

This shader uses `vertex_id`, so the first version needs no vertex buffer or
vertex descriptor.

## 6. Build and Bundle the Metal Library

Create `Scripts/build-metallib.sh`:

```sh
#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
package_root=$(CDPATH= cd -- "$script_dir/.." && pwd)
source_file="$package_root/Sources/ProceduralRenderPlugin/Shaders/ProceduralShaders.metal"
resource_dir="$package_root/Sources/ProceduralRenderPlugin/Resources"
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/ProceduralShaders.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT

mkdir -p "$resource_dir"
xcrun -sdk macosx metal -c "$source_file" \
    -fmodules-cache-path="$work_dir/ModuleCache" \
    -o "$work_dir/ProceduralShaders.air"
xcrun -sdk macosx metallib "$work_dir/ProceduralShaders.air" \
    -o "$resource_dir/ProceduralShaders-macos.metallib"
```

Then run:

```sh
chmod +x Scripts/build-metallib.sh
Scripts/build-metallib.sh
```

A metallib is SDK-specific. Before declaring iOS or visionOS support, also
compile and bundle libraries using `iphoneos`, `iphonesimulator`, `xros`, and
`xrsimulator` as applicable. Rebuild every library whenever shader code or
shared shader declarations change.

## 7. Implement the Extension

Create `ProceduralRenderExtension.swift`:

```swift
import Foundation
import Metal
import simd
import UntoldEngine

final class ProceduralRenderExtension: RenderExtension, @unchecked Sendable {
    let id = ProceduralPluginContract.extensionID
    private let shaderBundle: Bundle

    init(shaderBundle: Bundle) {
        self.shaderBundle = shaderBundle
    }

    func registerShaderLibraries(_ registry: RenderShaderLibraryRegistry) {
        registry.registerLibrary(
            ProceduralPluginContract.shaderLibraryID,
            bundle: shaderBundle,
            resource: "ProceduralShaders-macos"
        )
    }

    func registerPipelines(_ registry: RenderPipelineRegistry) {
        registry.registerScenePipeline(
            ProceduralPluginContract.pipelineID,
            vertexShader: "proceduralVertex",
            fragmentShader: "proceduralFragment",
            vertexShaderLibrary: .registered(
                ProceduralPluginContract.shaderLibraryID
            ),
            fragmentShaderLibrary: .registered(
                ProceduralPluginContract.shaderLibraryID
            ),
            depthCompareFunction: .lessEqual,
            depthEnabled: true,
            reverseZCompatible: true,
            blendMode: .none,
            name: "Procedural Scene Geometry"
        )
    }

    func buildGraph(
        _ builder: inout RenderGraphBuilder,
        context _: RenderGraphBuildContext
    ) {
        builder.addPass(
            id: ProceduralPluginContract.passID,
            stage: .beforePostProcess
        ) { context in
            guard let pipeline = context.renderPipelines.pipeline(
                ProceduralPluginContract.pipelineID
            ), let pipelineState = pipeline.pipelineState,
               let encoder = context.sceneRenderTargets.makeRenderCommandEncoder(
                   actions: .loadAndStore,
                   label: "Procedural Scene Geometry"
               )
            else {
                return
            }
            defer { encoder.endEncoding() }

            var viewProjection = context.camera.viewProjectionMatrix
            encoder.setRenderPipelineState(pipelineState)
            if let depthState = pipeline.depthState {
                encoder.setDepthStencilState(depthState)
            }
            encoder.setVertexBytes(
                &viewProjection,
                length: MemoryLayout<simd_float4x4>.stride,
                index: 0
            )
            encoder.drawPrimitives(
                type: .triangle,
                vertexStart: 0,
                vertexCount: 3
            )
        }
    }
}
```

`registerScenePipeline` resolves the engine's working color and depth formats.
Do not hard-code drawable or depth attachment formats. With
`reverseZCompatible: true`, the engine adapts ordered depth comparisons to its
active convention.

The scene encoder is available only at `.afterOpaqueLighting`,
`.beforeTransparency`, `.afterTransparency`, and `.beforePostProcess`. Always
end it before the pass closure returns.

## 8. Install the Plugin in an Application

Add the package product to the application target and install it once before
creating the renderer:

```swift
import ProceduralRenderPlugin
import UntoldEngine

func installProceduralRendering() -> Bool {
    switch registerProceduralRenderPlugin() {
    case .installed, .replaced:
        return true
    case let .rejected(failure):
        print("Validation errors:", failure.validationErrors)
        print("Artifact conflicts:", failure.artifactConflicts)
        print("Graph errors:", failure.graphValidationErrors)
        return false
    }
}

guard installProceduralRendering() else {
    fatalError("Rendering extension installation failed")
}
let renderer = UntoldRenderer.create()
```

Do not ignore `.rejected`. It distinguishes manifest validation, artifact
conflicts, shader or pipeline failures, and graph errors.

## 9. Add Platform-Specific Libraries

For a multi-platform plugin, select the resource compiled for the current SDK
inside package-owned code:

```swift
private var shaderResourceName: String {
    #if os(visionOS)
        #if targetEnvironment(simulator)
            "ProceduralShaders-xrossim"
        #else
            "ProceduralShaders-xros"
        #endif
    #elseif os(iOS)
        #if targetEnvironment(simulator)
            "ProceduralShaders-iossim"
        #else
            "ProceduralShaders-ios"
        #endif
    #else
        "ProceduralShaders-macos"
    #endif
}
```

Copy each corresponding `.metallib` in `Package.swift`. Only declare platforms
for which the package contains compatible artifacts. Replace the hard-coded
`"ProceduralShaders-macos"` registration and URL helper with
`shaderResourceName` when enabling these additional platforms.

## 10. Understand visionOS Execution

`context.camera`, `context.currentEye`, and the scene targets describe the eye
currently being rendered. Scene geometry must normally draw for every eye.

Eye-independent work such as simulation or an offscreen map should run once per
XR frame when appropriate:

```swift
guard context.currentEye == 0 else { return }
```

Do not apply that guard to visible scene geometry. Doing so would omit the draw
from the other eye.

## 11. Add Resources and Compute Work Later

Once the procedural draw works, add advanced features incrementally:

- declare textures and buffers in `registerResources`;
- match texture usage to graph access declarations;
- register compute work through `registerComputePipelines`;
- retrieve declared resources only through `context.resources`;
- use `registerModelSurfacePipeline` for normal engine entity drawing; and
- use the lower-level pipeline descriptor for extension-owned offscreen targets.

See [Using Rendering Extensions](UsingRenderingExtensions.md) for these APIs and
the [package fixture](../../Examples/RenderingExtensions/SwiftPackagePlugin/README.md)
for compute, resources, argument buffers, model surfaces, and custom geometry in
one buildable package.

## 12. Test the Contract

At minimum, test manifest ownership and bundled shader functions:

```swift
import Metal
import UntoldEngine
@testable import ProceduralRenderPlugin
import XCTest

final class ProceduralRenderPluginTests: XCTestCase {
    func testManifestOwnsEveryExtension() {
        let plugin = ProceduralRenderPlugin()
        XCTAssertTrue(RenderExtensionPluginValidator.validate(plugin).isValid)
        XCTAssertTrue(plugin.makeRenderExtensions().allSatisfy {
            $0.id == plugin.manifest.id ||
                $0.id.hasPrefix(plugin.manifest.id + ".")
        })
    }

    func testBundledFunctionsExist() throws {
        let url = try XCTUnwrap(ProceduralRenderPlugin.bundledMetallibURL)
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let library = try device.makeLibrary(URL: url)
        XCTAssertNotNil(library.makeFunction(name: "proceduralVertex"))
        XCTAssertNotNil(library.makeFunction(name: "proceduralFragment"))
    }
}
```

Integration tests should also cover successful installation, unavailable IDs,
pipeline cleanup, shader-library cleanup, pass removal, camera context, scene
target access, depth state, and an actual encoded draw.

Run:

```sh
swift build
swift test
```

## Completion Checklist

- The plugin builds independently from the engine package.
- Every artifact ID is namespaced.
- Installation occurs before renderer creation and handles rejection.
- The package loads its own platform-compatible metallib through `Bundle.module`.
- Shader source is not added to the engine target.
- Scene pipelines use engine-resolved formats and reverse-Z compatibility.
- Visible XR geometry draws for every eye.
- Every encoder is ended before its pass returns.
- Every declared resource access matches its Metal usage.
- Uninstall removes pipelines, shader libraries, resources, and graph passes.

## Common Failures

| Symptom | Likely cause |
| --- | --- |
| Plugin installation is rejected | Invalid namespace, missing metallib or function, duplicate ID, or invalid graph declaration. |
| Pipeline lookup returns `nil` | Pipeline registration failed or registration and lookup IDs differ. |
| Scene encoder returns `nil` | The pass uses an incompatible stage or scene color/depth targets are unavailable. |
| Resource lookup returns `nil` | The pass did not declare that resource and access mode. |
| macOS works but visionOS fails | The package bundled the wrong SDK's metallib or skipped per-eye drawing. |
| Depth appears inverted | The pipeline disabled reverse-Z compatibility or used an unsuitable comparison. |
| Metal reports corrupt uniforms | Swift and Metal size, alignment, or field order differ. |

For API details, continue with [Using Rendering Extensions](UsingRenderingExtensions.md).
For engine internals, see
[Rendering Extensions Architecture](../Architecture/RenderingExtensions.md).
