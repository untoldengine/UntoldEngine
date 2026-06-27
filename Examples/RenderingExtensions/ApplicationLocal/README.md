# Model-Surface Argument Buffer Sample

This sample is a complete Rendering Extension that draws selected model
entities with a per-entity tint. It demonstrates an extension-owned shader
library, argument layout, model-surface pipeline, staged pass, and argument
encoding.

This is an application-local example, not a requirement that extensions live in
the application target. The same `RenderExtension` implementation can live in a
framework or Swift package. For a complete distributable package with a plugin
manifest, bundled metallib, and public installation entry point, see the
[`SwiftPackagePlugin`](../SwiftPackagePlugin/README.md) fixture.

Application-local extensions and package plugins can be active together. Use
globally unique extension and artifact IDs, register both before renderer
creation, and do not attempt to share owner-private resources between them.

## Mental Model

A Rendering Extension declares what it owns, then adds one or more passes to
the render graph. Resource declarations are recorded immediately and allocated
when Metal and any required viewport are available. Shader and pipeline hooks
are materialized when Metal is ready. The engine invokes `buildGraph` when
constructing the graph and executes the pass closures during rendering.

Only `id` and `buildGraph` are required by `RenderExtension`. The other hooks
have default no-op implementations; implement only the capabilities the
extension uses.

| Extension member | When to implement it |
| --- | --- |
| `id` | Always. Use a globally unique, stable owner ID. |
| `registerShaderLibraries` | When shaders come from an application, framework, package, or custom metallib. |
| `registerArgumentBuffers` | When a model-surface fragment shader reads extension textures, samplers, or buffers. |
| `registerPipelines` | When the extension uses a custom render pipeline. |
| `registerComputePipelines` | When the extension dispatches compute work. |
| `registerResources` | When the extension owns render textures or buffers. |
| `buildGraph` | Always. Add the passes that perform the extension's work and declare every extension resource they access. |

For a model-surface extension, implement it in this order:

1. Define an opt-in component and any per-entity settings.
2. Write a fragment shader using `UntoldModelSurfaceExtensionArguments`.
3. Choose namespaced IDs for the extension, library, pipeline, layout, and pass.
4. Register the shader library, argument layout, and model-surface pipeline.
5. Add a graph pass, declare any extension resource usage, and call
   `drawModelSurfaceEntities` from its pass closure.
6. Bind per-entity values through `bindArguments`, using IDs that match Metal.
7. Register the extension before renderer creation and attach its component to
   each entity it should draw.

This tint sample does not declare pass resources because it uploads value bytes
and uses engine-owned model targets. A pass that reads an extension texture or
buffer must include it in `builder.addPass(..., resources:)`; undeclared lookups
return `nil`.

The sample's data flow is:

```text
TintSurfaceComponent.color
    -> bindArguments / buffer0
    -> UntoldModelSurfaceExtensionArguments.buffer0
    -> tintSurfaceFragment
```

## Xcode Application Target

Add `TintSurface.metal` to the application's Compile Sources build phase. Xcode
will include it in the application's default Metal library. The default
initializer loads that library from `Bundle.main`:

```swift
setRendering(.extensions(.register(TintSurfaceRenderExtension())))
```

For a framework target, pass that framework's bundle instead:

```swift
TintSurfaceRenderExtension(
    shaderBundle: Bundle(for: TintSurfaceRenderExtension.self)
)
```

## Swift Package Target

Swift Package Manager copies Metal source resources without compiling them, so
compile the shader for each deployment SDK and place the result beside
`TintSurface.metal`. For macOS:

```sh
xcrun -sdk macosx metal -c \
  -I <UntoldEngine>/Sources/UntoldEngineShaderSupport/include \
  Shaders/TintSurface.metal -o Shaders/TintSurface.air
xcrun -sdk macosx metallib \
  Shaders/TintSurface.air -o Shaders/TintSurface.metallib
```

Copy the shader directory as a resource:

```swift
.target(
    name: "TintSurfaceExtension",
    dependencies: [
        .product(name: "UntoldEngine", package: "UntoldEngine"),
        .product(name: "UntoldEngineShaderSupport", package: "UntoldEngine"),
    ],
    resources: [
        .copy("Shaders"),
    ]
)
```

Use the corresponding SDK and output library when building for iOS or visionOS.
The shader-support product supplies the shared ABI header; the explicit include
path makes it available to command-line Metal compilation.

Pass the package-only `Bundle.module` from code in that package target. The
engine resolves the metallib relative to that bundle:

```swift
let tintExtension = TintSurfaceRenderExtension(
    shaderBundle: .module,
    metallibResource: "TintSurface",
    metallibSubdirectory: "Shaders"
)
setRendering(.extensions(.register(tintExtension)))
```

Register the extension before renderer creation, then attach its component to
each entity that should use the pass:

```swift
let model = createEntity()
setEntityMesh(entityId: model, filename: "sample", withExtension: "untold")
registerComponent(entityId: model, componentType: TintSurfaceComponent.self)
getEntityComponent(
    entityId: model,
    componentType: TintSurfaceComponent.self
)?.color = SIMD4<Float>(0.15, 0.65, 1.0, 0.8)
```

The extension uses `buffer0`, but that ID is local to its argument buffer.
Another extension can independently use `buffer0`; each draw encodes and binds
a different argument buffer at the engine-owned outer slot.
