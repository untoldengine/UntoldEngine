# Rendering Extensions

Rendering extensions let an application add optional rendering work without editing
the engine's core render graph. They are intended for features such as water,
terrain overlays, fog, custom diagnostics, simulation buffers, and specialized
post-process effects.

The public setup API follows the engine settings style:

```swift
setRendering(.extensions(.register(WaterRenderExtension())))
setRendering(.extensions(.unregister("water")))
setRendering(.extensions(.removeAll))
```

In an application, the usual flow is to register the extension before creating
the renderer, then add the extension's component to entities that should use it:

```swift
setRendering(.extensions(.register(WaterRenderExtension())))

let water = createEntity()
setEntityMesh(entityId: water, filename: "waterPlane", withExtension: "untold")
setEntityWaterComponent(entityId: water)
```

Use extensions when a rendering feature needs its own pass, pipeline, compute
pipeline, or render texture, but should remain optional for the application.

## Extension Lifecycle

Every extension provides a stable `id` and implements `buildGraph`. The
registration hooks have default no-op implementations, so implement only the
capabilities the extension uses.

| Extension member | When to implement it |
| --- | --- |
| `id` | Always. It identifies the extension and scopes lifecycle-managed registrations; it must be globally unique. |
| `registerShaderLibraries` | When the extension supplies custom Metal functions. |
| `registerPipelines` | When the extension uses a custom render pipeline. |
| `registerComputePipelines` | When the extension dispatches compute work. |
| `registerResources` | When the extension owns render textures. |
| `registerArgumentBuffers` | When a model-surface shader reads extension arguments. |
| `buildGraph` | Always. Add the passes that perform the extension's work. |

Register extensions before renderer creation. The engine retains the extension,
registers its argument layouts, initializes its Metal-backed objects when the
renderer is ready, and calls `buildGraph` when constructing a render graph. A
pass closure added by `buildGraph` executes later during rendering.

## Minimal Extension

Create a type that conforms to `RenderExtension`.

```swift
import Metal
import UntoldEngine

final class WaterRenderExtension: RenderExtension, @unchecked Sendable {
    let id = "water"

    func registerResources(_ registry: RenderResourceRegistry) {
        registry.registerTexture(RenderExtensionTextureDescriptor(
            id: "water.reflection",
            label: "Water Reflection",
            size: .viewportScale(1.0),
            pixelFormat: .rgba16Float,
            usage: [.renderTarget, .shaderRead]
        ))
    }

    func buildGraph(
        _ builder: inout RenderGraphBuilder,
        context: RenderGraphBuildContext
    ) {
        builder.addPass(id: "water.render", stage: .beforePostProcess) { context in
            guard let reflection = context.resources.texture("water.reflection") else {
                return
            }

            // Encode Metal commands that render into, read from, or update
            // the extension texture.
        }
    }
}
```

Register it during renderer setup:

```swift
setRendering(.extensions(.register(WaterRenderExtension())))
```

The engine also includes `SampleRenderExtension`, a small opt-in reference
implementation that allocates a viewport-sized scratch texture and clears it
from a staged graph pass.

```swift
setRendering(.extensions(.register(SampleRenderExtension())))
```

## Stable Stages

Extensions insert passes at stable stage anchors instead of depending on
internal pass IDs.

```swift
.afterOpaqueLighting
.beforeTransparency
.afterTransparency
.beforePostProcess
.afterPostProcess
.beforeComposite
.beforeLook
.beforeOutput
```

Choose the earliest stage that has the inputs your feature needs. For example,
a water surface that should run before tone mapping and anti-aliasing can use
`.beforePostProcess`. A final diagnostic overlay can use `.beforeOutput`.

Do not depend on internal pass names such as `"lightPass"` or `"precomp"` in
application code. Those names are implementation details and may change.

## Texture Resources

Extensions can declare textures owned by the extension. The renderer creates
them when Metal is ready and recreates viewport-sized textures when the viewport
changes.

```swift
func registerResources(_ registry: RenderResourceRegistry) {
    registry.registerTexture(RenderExtensionTextureDescriptor(
        id: "water.reflection",
        size: .viewportScale(1.0),
        pixelFormat: .rgba16Float,
        usage: [.renderTarget, .shaderRead]
    ))

    registry.registerTexture(RenderExtensionTextureDescriptor(
        id: "water.history",
        size: .fixed(width: 1024, height: 1024),
        pixelFormat: .rgba16Float,
        usage: [.shaderRead, .shaderWrite]
    ))
}
```

Inside a render pass, use the pass context:

```swift
let reflection = context.resources.texture("water.reflection")
```

Outside a render pass, use the public resource query API:

```swift
let reflection = getRenderResource(.texture("water.reflection"))
```

Resource IDs should be namespaced by feature or package, such as
`"water.reflection"` or `"myStudio.fog.history"`, to avoid collisions.

## Shader Libraries

Custom shader functions must be registered before a render or compute pipeline
can reference them. An Xcode application target can load the default Metal
library compiled into `Bundle.main`:

```swift
import Foundation

let waterShaderLibrary: RenderShaderLibraryID = "water.shaders"

func registerShaderLibraries(_ registry: RenderShaderLibraryRegistry) {
    registry.registerDefaultLibrary(waterShaderLibrary, bundle: .main)
}
```

Frameworks should pass their framework bundle. Swift packages can register a
bundled precompiled metallib with `registerLibrary(_:url:)`; see the
[complete sample](../Samples/ModelSurfaceArgumentBuffer/README.md) for both
packaging flows.

## Compute Pipelines

Extensions can register compute pipelines from the engine library or a
registered extension library.

```swift
func registerComputePipelines(_ registry: ComputePipelineRegistry) {
    registry.registerComputePipeline(
        "water.simulation",
        functionName: "waterSimulationKernel",
        shaderLibrary: .registered("water.shaders"),
        pipelineName: "Water Simulation"
    )
}
```

Use the pipeline from a staged pass:

```swift
builder.addPass(id: "water.simulation", stage: .beforePostProcess) { context in
    guard let pipeline = context.computePipelines.pipeline("water.simulation") else {
        return
    }

    // Encode compute commands.
}
```

## Render Pipelines

Extensions can also register render pipelines:

```swift
func registerPipelines(_ registry: RenderPipelineRegistry) {
    registry.registerRenderPipeline("water.surface") {
        CreatePipeline(
            vertexShader: "waterVertex",
            fragmentShader: "waterFragment",
            vertexShaderLibrary: .registered("water.shaders"),
            fragmentShaderLibrary: .registered("water.shaders"),
            vertexDescriptor: nil,
            colorFormats: [.rgba16Float],
            depthFormat: .depth32Float,
            name: "Water Surface"
        )
    }
}
```

This is an advanced hook. Prefer extension-owned pipeline IDs instead of
replacing built-in pipeline IDs unless the feature is intentionally overriding
engine behavior.

Model-surface extensions should use the model-surface pipeline helper and can
enable argument-buffer diagnostics during registration:

```swift
func registerPipelines(_ registry: RenderPipelineRegistry) {
    registry.registerModelSurfacePipeline(
        "water.surface",
        fragmentShader: "waterFragment",
        fragmentShaderLibrary: .registered("water.shaders"),
        name: "Water Surface",
        validation: .warn(argumentLayoutID: "water.surface.arguments")
    )
}
```

Validation warns when the fragment shader does not declare the extension
argument buffer at the engine-owned slot, when it still uses raw legacy
extension texture or buffer slots, or when the referenced argument layout has
not been registered.

## Model Surface Draws

Extensions that draw normal engine meshes can use the model-surface helper:

```swift
context.drawModelSurfaceEntities(
    pipeline: "water.surface",
    matching: [WaterComponent.self],
    label: "Water Surface",
    argumentLayoutID: "water.surface.arguments",
    bindArguments: { arguments, entityId, resources in
        guard let water = getEntityComponent(
            entityId: entityId,
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

Extension fragment shaders should use the matching shader support constants:

```metal
#include <UntoldEngineShaderSupport/UntoldModelSurface.h>

using namespace metal;

struct WaterSurfaceParams {
    float4 tint;
};

fragment float4 waterFragment(
    UntoldModelSurfaceVertexOut in [[stage_in]],
    constant UntoldModelSurfaceExtensionArguments &arguments
        [[buffer(UntoldModelSurfaceExtensionArgumentBufferIndex)]]
) {
    constant WaterSurfaceParams &params =
        *reinterpret_cast<constant WaterSurfaceParams *>(arguments.buffer0);
    float4 waterColor = arguments.texture0.sample(
        arguments.sampler0,
        in.uvCoords
    );

    float alpha = waterColor.a * params.tint.a;
    return float4(waterColor.rgb * params.tint.rgb * alpha, alpha);
}
```

The model-surface extension argument buffer is bound at one engine-owned
fragment buffer slot. Texture, sampler, and buffer IDs inside that argument
buffer are local to the extension shader, so two extensions can both use
`texture0` or `buffer0` without colliding.

Extensions can register an owned argument layout and select it when drawing:

```swift
func registerArgumentBuffers(_ registry: RenderExtensionArgumentBufferRegistry) {
    registry.registerArgumentBuffer(
        RenderExtensionArgumentBufferDescriptor(
            id: "water.surface.arguments",
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

Then pass that layout ID to the draw helper:

```swift
context.drawModelSurfaceEntities(
    pipeline: "water.surface",
    matching: [WaterComponent.self],
    label: "Water Surface",
    argumentLayoutID: "water.surface.arguments",
    bindArguments: { arguments, entityId, resources in
        // Bind texture0, sampler0, and buffer0 here.
    }
)
```

Registered argument layouts are owned by the extension ID. Unregistering an
extension removes only that extension's layouts, so independently developed
water and grass extensions can both use local IDs like `buffer0`.

The registered entries identify the members an extension uses and their access
requirements. They do not shrink `UntoldModelSurfaceExtensionArguments`; the
engine always encodes the complete fixed ABI declared by the shader-support
header.

The fixed local ID ranges are textures `0...7`, samplers `8...15`, and buffers
`16...31`. Use the named Swift and shader-support constants instead of numeric
literals. `setBytes` is convenient for small per-entity values; use `setBuffer`
for existing or larger buffers.

The complete [model-surface argument buffer sample](../Samples/ModelSurfaceArgumentBuffer/README.md)
includes the extension implementation, shader, package setup, and entity setup.

### Argument Isolation and Namespacing

Every model-surface extension pipeline uses the same engine-owned outer
fragment buffer slot, but only one pipeline and its argument buffer are active
for a draw. The IDs inside that buffer describe its local layout; they are not
global Metal texture or buffer slots. A water extension and a grass extension
can therefore both declare `texture0`, `sampler0`, and `buffer0` safely.

IDs used by engine registries are global and still need namespacing. Give each
extension, shader library, pipeline, argument layout, resource, and pass a
provider-specific prefix such as `com.example.water.surface`.

### Migrating a Raw-Slot Extension

1. Include `UntoldModelSurface.h` and accept
   `UntoldModelSurfaceExtensionArguments` at
   `UntoldModelSurfaceExtensionArgumentBufferIndex` in the fragment shader.
2. Move each raw `[[texture(n)]]`, `[[sampler(n)]]`, or `[[buffer(n)]]`
   declaration into a local argument ID from
   `RenderExtensionModelSurfaceArgument` and its matching shader constant.
3. Register the local IDs with `registerArgumentBuffers(_:)` under a namespaced
   layout ID.
4. Pass that layout ID to both pipeline validation and
   `drawModelSurfaceEntities`.
5. Encode per-entity values through `bindArguments:` and remove the equivalent
   raw `MTLRenderCommandEncoder` bindings from `bindEntity:`.
6. Run with `.warn(argumentLayoutID:)` enabled and resolve every extension
   argument warning before release.

The older raw-slot model-surface API remains available during migration, but
new extensions should prefer `bindArguments:`. Do not bind extension
model-surface resources to low fragment slots such as `[[buffer(0)]]` or
`[[texture(0)]]`; those slots are used by the engine's model draw helper for
camera, material, and built-in texture state.

## Cleanup

Extensions are removed through the rendering API:

```swift
setRendering(.extensions(.unregister("water")))
setRendering(.extensions(.removeAll))
```

Unregistering an extension removes its shader libraries, textures, compute
pipelines, and argument layouts. Render pipelines can be registered by
extensions, but Phase 1 does not yet track render pipeline ownership for
automatic removal.

## Current Limits

Phase 1 provides stable extension points for the current graph. It is not a
fully dynamic render graph API yet.

- Extensions can add staged passes, shader libraries, textures, argument
  layouts, render pipelines, and compute pipelines.
- Argument-buffer helpers currently target model-surface fragment shaders.
- Extensions cannot yet declare typed read/write resource dependencies.
- Extensions cannot reorder arbitrary built-in passes.
- Extensions should not assume pass execution beyond the stable stage anchors.
- Extension render pipelines are not currently removed automatically on
  unregister.
- Extension passes run in registration order within the same stage.

These limits are intentional for the first public extension surface. They keep
optional features possible now while leaving room for a stronger resource graph
and dependency model later.
