# Using Rendering Extensions

> New to Rendering Extensions, or unsure whether you need one at all? Start
> with [Understanding Rendering Extensions](../Extensions/UnderstandingRenderingExtensions.md)
> to see how a material-data change, a per-surface shader, and a full custom
> pass differ before diving into this API reference.

Rendering Extensions add optional render passes, shaders, pipelines, and owned
resources without modifying Untold Engine. There are two supported integration
styles:

| Use case | Integration | Registration |
| -------- | ----------- | ------------ |
| Rendering code belongs to one application | Application-local extension | `setRendering(.extensions(.register(...)))` |
| Rendering code is distributed as a Swift package or framework | Package plugin | A package-owned installation function such as `registerWaterRenderPlugin()` |

Both styles use the same `RenderExtension` API and can be active in the same
application. Choose the package plugin when another project or developer should
consume the extension as a dependency.

If you are creating your first distributable extension, follow
[Creating a Rendering Extension Plugin](../Extensions/CreatingRenderingExtensionPlugin.md)
first. This document is the API reference for capabilities and advanced
integration choices.

- [Step-by-step plugin tutorial](../Extensions/CreatingRenderingExtensionPlugin.md)
- [Rendering Extension examples](https://github.com/untoldengine/UntoldEngine/tree/develop/Examples/RenderingExtensions)
- [Application-local model-surface example](https://github.com/untoldengine/UntoldEngine/tree/develop/Examples/RenderingExtensions/ApplicationLocal)
- [Swift package plugin example](https://github.com/untoldengine/UntoldEngine/tree/develop/Examples/RenderingExtensions/SwiftPackagePlugin)
- [Rendering Extensions architecture](../Architecture/RenderingExtensions.md)

> The water package is an API acceptance fixture, not a production water renderer. Its shaders are intentionally minimal.

## Application-Local Extension

Use this workflow when the extension source and shaders live in the application
or one of its frameworks.

### 1. Implement `RenderExtension`

Every extension needs a stable, globally unique `id` and a `buildGraph` method.
The registration hooks have default no-op implementations; implement only the
ones your feature needs.

| Member | Implement when |
| ------ | -------------- |
| `id` | Always. Namespace it for collision avoidance and lifecycle ownership. |
| `registerShaderLibraries` | The extension supplies Metal functions. |
| `registerResources` | The extension owns textures or buffers. |
| `registerArgumentBuffers` | A model-surface fragment shader reads extension arguments. |
| `registerPipelines` | The extension creates a render pipeline. |
| `registerComputePipelines` | The extension dispatches compute work. |
| `buildGraph` | Always. Add the passes that perform the rendering work. |

A minimal resource-owning extension looks like this:

```swift
import Metal
import UntoldEngine

final class ReflectionRenderExtension: RenderExtension, @unchecked Sendable {
    let id = "com.example.reflection"

    private let reflectionID: RenderTextureResourceID =
        "com.example.reflection.color"

    func registerResources(_ registry: RenderResourceRegistry) {
        registry.registerTexture(
            RenderExtensionTextureDescriptor(
                id: reflectionID,
                label: "Reflection Color",
                size: .viewportScale(1.0),
                pixelFormat: .rgba16Float,
                usage: [.renderTarget, .shaderRead]
            )
        )
    }

    func buildGraph(
        _ builder: inout RenderGraphBuilder,
        context _: RenderGraphBuildContext
    ) {
        builder.addPass(
            id: "com.example.reflection.render",
            stage: .beforePostProcess,
            resources: [.texture(reflectionID, access: .renderTarget)]
        ) { context in
            guard let reflection = context.resources.texture(reflectionID) else {
                return
            }

            // Encode Metal commands targeting reflection.
        }
    }
}
```

### 2. Register Before Renderer Creation

```swift
setRendering(.extensions(.register(ReflectionRenderExtension())))
```

For the complete tint sample:

```swift
setRendering(.extensions(.register(TintSurfaceRenderExtension())))

let tint = createEntity()
setEntityMeshDirect(
    entityId: tint,
    meshes: BasicPrimitives.createPlane(),
    assetName: "tint"
)
registerComponent(entityId: tint, componentType: TintSurfaceComponent.self)
getEntityComponent(
    entityId: tint,
    componentType: TintSurfaceComponent.self
)?.color = SIMD4<Float>(0.95, 0.05, 0.0, 0.8)
```

Add both `TintSurfaceRenderExtension.swift` and `TintSurface.metal` from the
sample to the application target. Put the Metal file in the application's
Compile Sources build phase. The sample's default initializer loads the Metal
library from `Bundle.main`. A framework should pass its own bundle instead.

### 3. Remove or Replace

```swift
setRendering(.extensions(.unregister("com.example.reflection")))
setRendering(.extensions(.removeAll))
```

Registering another standalone extension with the same `id` replaces the
previous instance if the new registration succeeds. A failed replacement leaves
the previous extension active.

## Swift Package Plugin

Use a package plugin when the extension is a reusable product consumed through
Swift Package Manager or a framework dependency.

The complete buildable reference is
[`Examples/RenderingExtensions/SwiftPackagePlugin`](https://github.com/untoldengine/UntoldEngine/tree/develop/Examples/RenderingExtensions/SwiftPackagePlugin).
It contains the Swift extension, manifest, registration entry point, argument
buffer shader, declarations, tests, and bundled precompiled metallib. It also
contains a procedural triangle pass that uses no engine mesh: the package vertex
shader generates positions from `vertex_id`, while the pass consumes
`context.camera`, `context.renderPipelines`, and `context.sceneRenderTargets`
before issuing a depth-tested draw. This is the acceptance reference for custom
scene geometry and per-eye graph execution.

### 1. Declare the Engine Dependency

During local development, point the extension package to the engine checkout:

```swift
dependencies: [
    .package(path: "/path/to/UntoldEngine"),
]
```

For distribution, use the canonical engine repository URL and a compatible
release requirement. The plugin target depends on the engine product:

```swift
.target(
    name: "ExampleRenderPlugin",
    dependencies: [
        .product(name: "UntoldEngine", package: "UntoldEngine"),
    ],
    exclude: ["Shaders"],
    resources: [
        .copy("Resources/ExampleRenderPlugin.metallib"),
    ]
)
```

Dependency paths are resolved relative to the extension package's
`Package.swift`, not relative to the consuming application. SwiftPM copies Metal
source but does not compile it for this workflow. Build and bundle a compatible
metallib for every platform and SDK the package supports.

### 2. Add a Manifest and Factory

The package wraps one or more ordinary `RenderExtension` implementations:

```swift
public struct ExampleRenderPlugin: RenderExtensionPlugin {
    public let manifest = RenderExtensionPluginManifest(
        id: "com.example.rendering",
        displayName: "Example Rendering",
        version: RenderExtensionPluginVersion(major: 1, minor: 0, patch: 0)
    )

    public init() {}

    public func makeRenderExtensions() -> [any RenderExtension] {
        [ExampleSurfaceRenderExtension(shaderBundle: .module)]
    }
}
```

Plugin IDs must be dot-separated package namespaces. Every extension ID supplied
by a plugin must equal the plugin ID or begin with that ID followed by a dot.

Use `Bundle.module` from code inside the package target when constructing the
extension.

### 3. Export One Installation Function

```swift
@discardableResult
public func registerExampleRenderPlugin()
    -> RenderExtensionPluginInstallationResult
{
    RenderExtensionPluginRegistry.shared.install(ExampleRenderPlugin())
}
```

### 4. Install and Use It in the Application

Install the plugin once during application startup, before renderer creation:

```swift
import ExampleRenderPlugin
import UntoldEngine

switch registerExampleRenderPlugin() {
case .installed, .replaced:
    break

case let .rejected(failure):
    print("Plugin validation errors:", failure.validationErrors)
    print("Artifact conflicts:", failure.artifactConflicts)
    print("Graph errors:", failure.graphValidationErrors)
}
```

The package should expose any components or configuration types that consumers
need. After `registerWaterRenderPlugin()` returns `.installed` or `.replaced`,
the fixture component can be used like this:

```swift
import WaterRenderPlugin

let water = createEntity()
setEntityMeshDirect(
    entityId: water,
    meshes: BasicPrimitives.createPlane(),
    assetName: "water"
)
registerComponent(entityId: water, componentType: WaterSurfaceComponent.self)

if let surface = getEntityComponent(
    entityId: water,
    componentType: WaterSurfaceComponent.self
) {
    surface.tint = SIMD4<Float>(0.08, 0.38, 0.62, 1.0)
    surface.roughness = 0.08
    surface.waveStrength = 0.18
}
```

Do not also register the package's internal extension through `setRendering`.
The package entry point already registers it.

### 5. Query or Uninstall

```swift
let manifests = RenderExtensionPluginRegistry.shared.installedManifests()
let failure = RenderExtensionPluginRegistry.shared.failure(
    forPluginID: "com.example.rendering"
)

RenderExtensionPluginRegistry.shared.uninstall(id: "com.example.rendering")
RenderExtensionPluginRegistry.shared.removeAll()
```

Plugin `removeAll()` removes plugin-owned extensions only. It does not remove
standalone application-local extensions.

## Stable Render Stages

Add passes at stable stage anchors:

```swift
.frameStart
.beforeShadows
.afterOpaqueLighting
.beforeTransparency
.afterTransparency
.beforePostProcess
.afterPostProcess
.beforeComposite
.beforeLook
.beforeOutput
```

Choose the earliest stage that provides the inputs your pass needs. A surface
that should run before tone mapping can use `.beforePostProcess`; a final overlay
can use `.beforeOutput`. Use `.frameStart` for per-frame compute preparation and
`.beforeShadows` for work that must complete before the engine renders shadows.

When one extension pass must wait for another pass owned by the same extension,
use a typed dependency:

```swift
builder.addPass(
    id: "com.example.sim.sort",
    stage: .frameStart,
    dependencies: [.sameExtension("com.example.sim.update")]
) { context in
    // Encode commands.
}
```

Plugins may also depend on documented engine targets:

```swift
.engine(.sceneDepth)
.engine(.opaqueLighting)
.engine(.sceneComposite)
```

Do not depend on private built-in pass names or another plugin's pass IDs.
Invalid dependencies reject the extension's graph contribution.

## Pass Resource Access

A pass must declare every extension-owned texture and buffer it accesses:

```swift
builder.addPass(
    id: "com.example.water.simulation",
    stage: .beforePostProcess,
    resources: [
        .texture(colorTextureID, access: .write),
        .buffer(uniformsID, access: .read),
    ]
) { context in
    guard let color = context.resources.texture(colorTextureID),
          let uniforms = context.resources.buffer(uniformsID)
    else {
        return
    }

    // Encode commands.
}
```

Texture access supports `.read`, `.write`, and `.renderTarget`. Buffer access
supports `.read` and `.write`. Descriptor usage must support the declared pass
access: shader writes require `.shaderWrite`, and render-target access requires
`.renderTarget`.

## Textures and Buffers

Declare resources in `registerResources`:

```swift
func registerResources(_ registry: RenderResourceRegistry) {
    registry.registerTexture(
        RenderExtensionTextureDescriptor(
            id: "com.example.water.reflection",
            size: .viewportScale(1.0),
            pixelFormat: .rgba16Float,
            usage: [.renderTarget, .shaderRead]
        )
    )

    registry.registerBuffer(
        RenderExtensionBufferDescriptor(
            id: "com.example.water.uniforms",
            length: 256
        )
    )
}
```

Texture sizes can be fixed or viewport-relative. Viewport-relative textures are
recreated when their resolved size changes.

Outside a pass, query a resource or its state through the public API:

```swift
let texture = getRenderResource(.texture("com.example.water.reflection"))
let state = RenderResourceRegistry.shared.textureState(
    "com.example.water.reflection"
)
```

## Shader Libraries

An application target can use its default Metal library:

```swift
func registerShaderLibraries(_ registry: RenderShaderLibraryRegistry) {
    registry.registerDefaultLibrary(
        "com.example.water.shaders",
        bundle: .main
    )
}
```

A package should resolve its precompiled metallib from package-owned code:

```swift
func registerShaderLibraries(_ registry: RenderShaderLibraryRegistry) {
    registry.registerPlatformLibrary(
        "com.example.water.shaders",
        bundle: .module,
        baseResource: "WaterShaders",
        subdirectory: "Shaders"
    )
}
```

This selects `WaterShaders-macos`, `WaterShaders-ios`, `WaterShaders-iossim`,
`WaterShaders-xros`, `WaterShaders-xrossim`, `WaterShaders-tvos`, or
`WaterShaders-tvossim` for the current SDK.

Frameworks should pass their framework bundle. Missing or invalid libraries are
reported as registration failures.

## Compute and Render Pipelines

Register a compute pipeline from a registered shader library:

```swift
func registerComputePipelines(_ registry: ComputePipelineRegistry) {
    registry.registerComputePipeline(
        RenderExtensionComputePipelineDescriptor(
            id: "com.example.water.simulation",
            function: "waterSimulationKernel",
            shaderLibrary: .registered("com.example.water.shaders"),
            name: "Water Simulation"
        )
    )
}
```

Retrieve it from a pass:

```swift
guard let pipeline = context.computePipelines.pipeline(
    "com.example.water.simulation"
) else {
    return
}
```

Render pipelines use the symmetric lookup API:

```swift
guard let pipeline = context.renderPipelines.pipeline(
    "com.example.water.surface"
) else {
    return
}
```

Lookup returns `nil` for unknown IDs and after the owning extension or plugin is
removed. Access is read-only; registration, conflict handling, and cleanup stay
within the extension lifecycle.

`RenderPassContext` also identifies its stable `stage` and exposes a `camera`
snapshot containing the current eye's view, projection, view-projection, and
world position. On visionOS these values describe the eye whose graph is
currently executing.

The scene-target capability is available as `context.sceneRenderTargets`.
Scene geometry is compatible with `.afterOpaqueLighting`,
`.beforeTransparency`, `.afterTransparency`, and `.beforePostProcess`. Later
stages operate on post-processed or composite products and do not guarantee a
matching scene depth target; requesting a scene encoder there returns `nil`.

Create an encoder for custom scene geometry and always end it before returning
from the pass closure:

```swift
guard let encoder = context.sceneRenderTargets.makeRenderCommandEncoder(
    actions: .loadAndStore,
    label: "Custom Scene Geometry"
) else {
    return
}
defer { encoder.endEncoding() }

encoder.setRenderPipelineState(pipeline.pipelineState!)
encoder.setDepthStencilState(pipeline.depthState)
// Bind extension-owned buffers and issue draw calls.
```

The default actions load and store both scene color and depth. Custom actions
may use `.load`, `.clear`, or `.dontCare` and `.store` or `.dontCare`.
Multisample resolve store actions are rejected because this API targets the
resolved working scene attachments. Color and depth must both exist and have
matching dimensions and sample counts. The engine copies its descriptor before
applying these actions, so extension code cannot mutate engine descriptor state.

Register a custom-geometry pipeline without hard-coding platform attachment
formats:

```swift
func registerPipelines(_ registry: RenderPipelineRegistry) {
    registry.registerScenePipeline(
        "com.example.water.pool",
        vertexShader: "poolVertex",
        fragmentShader: "poolFragment",
        vertexShaderLibrary: .registered("com.example.water.shaders"),
        fragmentShaderLibrary: .registered("com.example.water.shaders"),
        vertexDescriptor: poolVertexDescriptor,
        depthCompareFunction: .lessEqual,
        depthEnabled: true,
        reverseZCompatible: true,
        blendMode: .none,
        name: "Pool Geometry"
    )
}
```

`registerScenePipeline` resolves the engine's working scene-color and depth
formats internally. Its vertex descriptor is optional, vertex and fragment
functions may come from different registered libraries, and the existing
extension ownership and cleanup rules apply. With `reverseZCompatible` enabled,
the engine reverses ordered depth comparisons when reverse-Z rendering is active.
`depthEnabled` controls depth writes; use `.always` when depth testing itself is
not required. Blend modes include none, straight alpha, premultiplied alpha, and
additive.

The lower-level `RenderExtensionRenderPipelineDescriptor` remains available for
pipelines targeting extension-owned attachments. Use the model-surface helper
when drawing normal engine meshes:

```swift
func registerPipelines(_ registry: RenderPipelineRegistry) {
    registry.registerModelSurfacePipeline(
        "com.example.water.surface",
        fragmentShader: "waterFragment",
        fragmentShaderLibrary: .registered("com.example.water.shaders"),
        name: "Water Surface",
        validation: .warn(
            argumentLayoutID: "com.example.water.surface.arguments"
        )
    )
}
```

## Model-Surface Argument Buffers

Model-surface extensions should pass custom textures, samplers, and buffers
through the engine extension argument buffer rather than raw Metal binding slots.

### Register the Layout

```swift
func registerArgumentBuffers(
    _ registry: RenderExtensionArgumentBufferRegistry
) {
    registry.registerArgumentBuffer(
        RenderExtensionArgumentBufferDescriptor(
            id: "com.example.water.surface.arguments",
            textures: [
                RenderExtensionArgumentTexture(
                    id: RenderExtensionModelSurfaceArgument.texture0
                ),
            ],
            samplers: [
                RenderExtensionArgumentSampler(
                    id: RenderExtensionModelSurfaceArgument.sampler0
                ),
            ],
            buffers: [
                RenderExtensionArgumentBuffer(
                    id: RenderExtensionModelSurfaceArgument.buffer0
                ),
            ]
        )
    )
}
```

### Bind Per-Entity Values

```swift
context.drawModelSurfaceEntities(
    pipeline: "com.example.water.surface",
    matching: [WaterComponent.self],
    label: "Water Surface",
    argumentLayoutID: "com.example.water.surface.arguments",
    bindArguments: { arguments, entityID, resources in
        guard let water = getEntityComponent(
            entityId: entityID,
            componentType: WaterComponent.self
        ) else {
            return
        }

        arguments.setTexture(
            resources.texture(water.colorTextureID),
            id: RenderExtensionModelSurfaceArgument.texture0
        )
        arguments.setSampler(
            water.sampler,
            id: RenderExtensionModelSurfaceArgument.sampler0
        )

        var uniforms = WaterSurfaceUniforms(component: water)
        arguments.setBytes(
            &uniforms,
            id: RenderExtensionModelSurfaceArgument.buffer0
        )
    }
)
```

Include every resource read through `resources` in the pass's `resources:`
declaration.

### Match the Metal Shader

```metal
#include <UntoldEngineShaderSupport/UntoldModelSurface.h>

using namespace metal;

fragment float4 waterFragment(
    UntoldModelSurfaceVertexOut in [[stage_in]],
    constant UntoldModelSurfaceExtensionArguments &arguments
        [[buffer(UntoldModelSurfaceExtensionArgumentBufferIndex)]]
) {
    constant float4 &tint =
        *reinterpret_cast<constant float4 *>(arguments.buffer0);
    return tint;
}
```

Use the named Swift and shader-support constants shown above instead of numeric
binding indices.

For a complete implementation, shader, and package compilation commands, use the
[application-local argument-buffer sample](https://github.com/untoldengine/UntoldEngine/tree/develop/Examples/RenderingExtensions/ApplicationLocal).

## Migrating a Raw-Slot Extension

1. Include `UntoldModelSurface.h` in the fragment shader.
2. Replace raw extension texture, sampler, and buffer parameters with
   `UntoldModelSurfaceExtensionArguments`.
3. Register the local member IDs under a namespaced argument-layout ID.
4. Pass that layout ID to pipeline validation and `drawModelSurfaceEntities`.
5. Encode values through `bindArguments` and remove equivalent raw encoder
   bindings.
6. Resolve every `.warn(argumentLayoutID:)` diagnostic before release.

The legacy raw-slot API remains available for migration. New model-surface
extensions should use argument buffers.

## Registration Errors and Diagnostics

Use direct standalone registration when the application needs a structured
result:

```swift
let result = RenderExtensionRegistry.shared.register(
    ReflectionRenderExtension()
)
```

Query registration diagnostics by extension ID:

```swift
let conflicts = RenderExtensionRegistry.shared.registrationConflicts(
    forExtensionID: "com.example.reflection"
)
let shaderErrors = RenderExtensionRegistry.shared.shaderLibraryErrors(
    forExtensionID: "com.example.reflection"
)
let pipelineErrors = RenderExtensionRegistry.shared.pipelineErrors(
    forExtensionID: "com.example.reflection"
)
let graphErrors = RenderExtensionRegistry.shared.graphValidationErrors(
    forExtensionID: "com.example.reflection"
)
let allocationErrors = RenderExtensionRegistry.shared.resourceAllocationErrors(
    forExtensionID: "com.example.reflection"
)
```

Package consumers receive plugin-wide failures from
`RenderExtensionPluginInstallationResult.rejected` and can query the latest
failure through `RenderExtensionPluginRegistry`.

## Authoring Checklist

- Register the extension or plugin once before renderer creation.
- Namespace every extension, plugin, pass, resource, library, pipeline, and
  argument-layout ID.
- Add passes only through stable stages.
- Declare every resource access on the pass that uses it.
- Use argument buffers for model-surface extension data.
- Keep `Bundle.module` inside the package target.
- Bundle one compatible metallib per supported platform and SDK.
- Handle registration rejection and inspect registration diagnostics.

For lifecycle, ownership, graph compilation, hazard scheduling, resource
planning, and failure-isolation details, see
[Rendering Extensions Architecture](../Architecture/RenderingExtensions.md).
