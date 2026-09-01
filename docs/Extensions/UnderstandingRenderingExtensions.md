# Understanding Rendering Extensions

Untold Engine gives you three different ways to change how something looks,
and they are not interchangeable. Picking the wrong one means either fighting
the engine (trying to get shader code into a data-only system) or overbuilding
(standing up a full render-graph node for a plain color change). This document
is the decision layer: it tells you which mechanism fits your change and links
to the how-to for each one. It does not replace
[Using Rendering Extensions](../API/UsingRenderingExtensions.md) (the API
reference) or [Rendering Extensions Architecture](../Architecture/RenderingExtensions.md)
(how the graph compiles and executes) — read this first, then go there for
implementation detail.

## Start here: what are you changing?

| You want to... | Mechanism | Shader code required? | Engine source touched? |
| --- | --- | --- | --- |
| Change base color, roughness, metallic, emissive, or textures on existing PBR shading | Material data (`.untold` scene file / Blender export) | No | No |
| Give specific meshes custom fragment shading (toon shading, refraction, tri-planar blending, a distortion ripple) | `RenderExtension`, **model-surface path** | Yes (fragment only) | No |
| Add a new effect that is not tied to any one mesh's shading (post-process, procedural geometry, screen overlay, bloom, outline pass) | `RenderExtension`, **full custom pass path** | Yes (full pipeline) | No |

The first row is not a `RenderExtension` at all. Materials are fixed PBR
channels, not a runtime shader graph — a Blender node graph the engine can't
evaluate must be baked to flat textures with a third-party tool before
export, so there is no interpreted shading logic to hook into. See
[Using Materials](../API/UsingMaterials.md). If your change is "make this
look shinier/redder/rougher," stop here — you don't need anything below.

The other two rows both use the same `RenderExtension` protocol
(`registerShaderLibraries`, `registerPipelines`, `registerResources`,
`buildGraph`, ...). What differs is *how much of the draw you own*.

## Mental model 1: Surface shaders (model-surface path)

**Analogy:** the engine still drives the car — you're only swapping the
paint. The engine draws the mesh (vertex stage, skinning, transforms), and
your extension supplies just the fragment function that decides the final
pixel color for entities that opt in.

Use this when the effect is a property of one mesh's surface: a distortion
ripple on a water plane, toon shading on a character, a custom BRDF for one
material. It composes cleanly because you never touch geometry handling.

The shape of it, using the reference `WaterSurfaceRenderExtension`
(`Examples/RenderingExtensions/SwiftPackagePlugin/Sources/WaterRenderPlugin/WaterRenderPlugin.swift`):

1. **A marker component opts entities in.**
   ```swift
   public final class WaterSurfaceComponent: Component, @unchecked Sendable {
       public var tint = SIMD4<Float>(0.10, 0.45, 0.65, 1.0)
       public var waveStrength: Float = 0.18
       public required init() {}
   }
   ```
   Attach it to whichever entities should render with your shader. Everything
   else keeps rendering with the engine's default material shader.

2. **Register a model-surface pipeline** — you supply the fragment function
   only; the engine's vertex stage stays in charge:
   ```swift
   registry.registerModelSurfacePipeline(
       surfacePipelineID,
       fragmentShader: "waterFixtureSurfaceFragment",
       fragmentShaderLibrary: .registered(shaderLibraryID),
       validation: .warn(argumentLayoutID: argumentLayoutID)
   )
   ```

3. **Declare a small, fixed argument-buffer layout** (textures/buffers your
   fragment function expects at specific slots) via
   `registerArgumentBuffers`.

4. **Draw only the matching entities** in `buildGraph`:
   ```swift
   context.drawModelSurfaceEntities(
       pipeline: surfacePipelineID,
       matching: [WaterSurfaceComponent.self],
       argumentLayoutID: argumentLayoutID,
       bindArguments: { arguments, entityID, resources in
           // pack this entity's component values into the argument buffer
       }
   )
   ```

Total surface: one `.metal` fragment function, one marker component, a handful
of registration calls. No engine edits.

## Mental model 2: Full custom passes

**Analogy:** you own the whole assembly-line station — your textures, your
pipeline(s), your encoder. The engine only tells you *when* to run (which
`RenderStage`) and hands you scoped read access to whatever resources you
declared.

Use this when the effect isn't a property of one mesh's shading: a
post-process pass, procedural full-screen geometry, an outline pass, a
multi-step effect like bloom (threshold → blur → composite).

The shape of it:

1. **Own your textures.** `registerResources` declares any scratch textures
   the effect needs (e.g. a downsample chain for bloom), sized relative to
   the viewport. These are private to your extension.

2. **Own your pipeline(s).** `registerPipelines` / `registerComputePipelines`
   compile *both* vertex and fragment (or a compute kernel) from your own
   shader library — unlike the surface path, the engine contributes nothing
   to the draw itself.

3. **Compose passes in `buildGraph`.** Each `addPass(id:stage:resources:)` is
   one node. A multi-step effect just adds several, each declaring which of
   its own textures it reads/writes:
   ```swift
   builder.addPass(id: thresholdPass, stage: .beforePostProcess,
       resources: [.texture(bloomA, access: .write)]) { /* compute */ }

   builder.addPass(id: blurPass, stage: .beforePostProcess,
       resources: [.texture(bloomA, access: .read), .texture(bloomB, access: .write)]) { /* compute */ }

   builder.addPass(id: compositePass, stage: .beforePostProcess,
       resources: [.texture(bloomB, access: .read)]) { context in
           // draw into the scene via context.sceneRenderTargets
       }
   ```
   You do not order these manually — the graph compiler infers ordering from
   read/write hazards on your declared resources, plus registration order
   within a stage. See
   [Stable Render Stages](../API/UsingRenderingExtensions.md#stable-render-stages)
   for the full list of anchor points (`.frameStart` through `.beforeOutput`).

4. **Get pixels on screen.** `context.sceneRenderTargets.makeRenderCommandEncoder(...)`
   draws directly into the engine's live scene color/depth, but only at
   `.afterOpaqueLighting`, `.beforeTransparency`, `.afterTransparency`, or
   `.beforePostProcess` — see
   [Rendering Extensions Architecture § Staged Graph Contribution](../Architecture/RenderingExtensions.md#staged-graph-contribution).
   Alternatively, compute into your own owned texture if the effect feeds a
   later pass of yours instead of compositing immediately.

5. **Use frame context instead of hand-rolled state.** The pass closure
   receives `context.camera`, `context.deltaTime`, `context.frameIndex`, and
   `context.currentEye`/`isPrimaryEye`, so time- or camera-driven effects and
   XR eye handling don't need private frame counters.

For a full worked build (package layout, install/uninstall, a complete
procedural draw), follow
[Creating a Rendering Extension Plugin](CreatingRenderingExtensionPlugin.md).

## One boundary that applies to both models

Neither path can **sample the engine's already-composited frame as a texture
input** — extensions get a render-target *encoder* to draw on top of scene
color at a few stages, never a readable copy of what the engine has already
rendered. This is a documented boundary, not a bug:
"cross-extension resource exports or imports" are explicitly not provided
(see [Current Boundaries](../Architecture/RenderingExtensions.md#current-boundaries)).
In practice this means a *screen-wide* "grab what's already drawn and warp
it" effect isn't a first-class capability today — per-surface distortion
(mental model 1) is. If your effect needs to read back the full frame, that's
a gap to plan around, not a stage you're missing.

## Quick reference

| Mental model | Owns geometry/vertex stage? | Owns fragment/pixel logic? | Scoped to specific entities? | Reference implementation |
| --- | --- | --- | --- | --- |
| Material data | Engine | Engine (fixed PBR shader) | N/A — data only | [Using Materials](../API/UsingMaterials.md) |
| Surface shader (model-surface) | Engine | You | Yes, via marker component | `WaterSurfaceRenderExtension` (surface pass) |
| Full custom pass | You | You | No — pass-level, not entity-level | `WaterSurfaceRenderExtension` (procedural pass) |

## See also

- [Using Rendering Extensions](../API/UsingRenderingExtensions.md) — API reference and registration mechanics
- [Rendering Extensions Architecture](../Architecture/RenderingExtensions.md) — how the graph compiles, validates, and executes
- [Creating a Rendering Extension Plugin](CreatingRenderingExtensionPlugin.md) — step-by-step distributable-package tutorial
- [Rendering Extension examples](https://github.com/untoldengine/UntoldEngine/tree/develop/Examples/RenderingExtensions)
