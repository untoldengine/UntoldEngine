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

## Compute Pipelines

Extensions can register compute pipelines by function name when the engine Metal
library is available.

```swift
func registerComputePipelines(_ registry: ComputePipelineRegistry) {
    registry.registerComputePipeline(
        "water.simulation",
        functionName: "waterSimulationKernel",
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

## Model Surface Draws

Extensions that draw normal engine meshes can use the model-surface helper:

```swift
context.drawModelSurfaceEntities(
    pipeline: "water.surface",
    matching: [WaterComponent.self],
    label: "Water Surface"
) { encoder, entityId, resources in
    guard let water = getEntityComponent(
        entityId: entityId,
        componentType: WaterComponent.self
    ) else {
        return
    }

    encoder.setFragmentTexture(
        resources.texture(water.colorTextureID),
        index: RenderExtensionModelSurfaceSlot.fragmentTexture0
    )

    var uniforms = WaterSurfaceUniforms(component: water)
    encoder.setFragmentBytes(
        &uniforms,
        length: MemoryLayout<WaterSurfaceUniforms>.stride,
        index: RenderExtensionModelSurfaceSlot.fragmentBuffer0
    )
}
```

Extension fragment shaders should use the matching shader support constants:

```metal
#include <UntoldEngineShaderSupport/UntoldModelSurface.h>

fragment float4 waterFragment(
    UntoldModelSurfaceVertexOut in [[stage_in]],
    texture2d<float> waterColor
        [[texture(UntoldModelSurfaceExtensionFragmentTexture0)]],
    constant WaterSurfaceParams &params
        [[buffer(UntoldModelSurfaceExtensionFragmentBuffer0)]]
) {
    // Shade the model surface.
}
```

Do not bind extension model-surface resources to low fragment slots such as
`[[buffer(0)]]` or `[[texture(0)]]`. Those slots are used by the engine's model
draw helper for camera, material, and built-in texture state.

## Cleanup

Extensions are removed through the rendering API:

```swift
setRendering(.extensions(.unregister("water")))
setRendering(.extensions(.removeAll))
```

Unregistering an extension removes the textures and compute pipelines owned by
that extension. Render pipelines can be registered by extensions, but Phase 1
does not yet track render pipeline ownership for automatic removal.

## Current Limits

Phase 1 provides stable extension points for the current graph. It is not a
fully dynamic render graph API yet.

- Extensions can add staged passes, textures, render pipelines, and compute
  pipelines.
- Extensions cannot yet declare typed read/write resource dependencies.
- Extensions cannot reorder arbitrary built-in passes.
- Extensions should not assume pass execution beyond the stable stage anchors.
- Extension render pipelines are not currently removed automatically on
  unregister.
- Extension passes run in registration order within the same stage.

These limits are intentional for the first public extension surface. They keep
optional features possible now while leaving room for a stronger resource graph
and dependency model later.
