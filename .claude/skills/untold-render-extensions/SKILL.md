---
name: untold-render-extensions
description: Use when adding custom per-frame or render-graph-contributing behavior that the built-in Untold Engine systems don't provide — a custom render pass/surface shader/effect (water, custom decals, a reflection pass), a non-rendering per-frame plugin (physics/audio/AI backend), or app-local gameplay logic that needs a frame hook. Covers choosing between RenderExtension, EngineExtension, and registerCustomSystem, the render-graph stage/resource model, and RenderExtension authoring (shaders, pipelines, argument buffers, plugin packaging). Triggers on "add a custom render pass", "write a water/reflection/decal effect", "register a per-frame plugin", "hook into the render graph". Not for runtime material/texture/color-grading edits on existing PBR materials (see untold-materials-color), one-off per-frame gameplay code with no distribution need (use registerCustomSystem directly, see §1), or engine-wide setting tweaks like anti-aliasing/postFX/LOD knobs (see untold-engine-config).
version: 0.1.0
---

# Rendering and Engine Extensions in Untold Engine

Use this when the built-in systems (materials, lights, post effects, scene channels) can't express what you need, and you have to add your own per-frame logic or render-graph pass. **Never write a custom render/update loop or call `draw(in:)` yourself** — the engine's `MTKViewDelegate` already drives the frame; everything here hooks *into* that loop, it doesn't replace it.

## 1. Decide which extension point to use

Three mechanisms exist, and they are not interchangeable:

| Mechanism | Use when | Registers with |
| --- | --- | --- |
| `registerCustomSystem(_:)` | App-local gameplay logic that needs a per-frame hook and doesn't need to be distributable | a closure — no protocol to implement |
| `EngineExtension` / `EngineExtensionRegistry` | A non-rendering per-frame plugin meant to be reusable/distributable (a physics backend, an audio system, an AI/steering backend) | `EngineExtensionRegistry` |
| `RenderExtension` / `RenderExtensionRegistry` (refines `EngineExtension`) | A plugin that contributes its own render-graph pass, shader, pipeline, or owned GPU resource (particles, custom surfaces, water, reflections, decals) | `RenderExtensionRegistry`, or `setRendering(.extensions(.register(...)))` |

**Register a given plugin type with exactly one of `EngineExtension` or `RenderExtension` — never both.** If you're not sure whether your logic touches the render graph at all, start with `registerCustomSystem(_:)`; only move to `RenderExtension` once you need to add a pass, shader, or GPU resource, and only move to `EngineExtension` once the logic needs to be a reusable, distributable plugin with no rendering involvement.

For straightforward per-frame gameplay logic in a single app, prefer `setupCallbacks`/`onUpdate(_:)` or `registerCustomSystem(_:)` over writing a full extension — a protocol implementation is overhead you don't need for app-local code.

## 2. The render-graph model (read this before writing a `RenderExtension`)

Rendering is a graph of passes built once per frame (`Sources/UntoldEngine/Renderer/UntoldEngine.swift`, `Systems/RenderingSystem.swift`). Opaque geometry uses tile-based deferred rendering: the model pass writes G-Buffer data into memoryless tile attachments, and the lighting shader reads them via framebuffer fetch in the same encoder — this is why a custom pass can't just "insert itself" anywhere; it must declare a stable stage and its resource reads/writes so the graph can schedule it safely.

Add passes only at these stable stage anchors — never invent a stage or depend on a private built-in pass name:

```swift
.frameStart            // per-frame compute preparation
.beforeShadows          // work that must complete before shadow rendering
.afterOpaqueLighting
.beforeTransparency
.afterTransparency
.beforePostProcess      // most custom surfaces/effects belong before tonemap
.afterPostProcess
.beforeComposite
.beforeLook
.beforeOutput           // final overlays
```

Choose the earliest stage that has the inputs your pass needs. Passes can depend on another pass from the *same* extension (`.sameExtension("id")`) or on documented engine targets (`.engine(.sceneDepth)`, `.engine(.opaqueLighting)`, `.engine(.sceneComposite)`) — never on another plugin's private pass ID.

## 3. Implement `RenderExtension`

```swift
final class ReflectionRenderExtension: RenderExtension, @unchecked Sendable {
    let id = "com.example.reflection"   // globally unique, namespaced

    private let reflectionID: RenderTextureResourceID = "com.example.reflection.color"

    func registerResources(_ registry: RenderResourceRegistry) {
        registry.registerTexture(
            RenderExtensionTextureDescriptor(
                id: reflectionID, label: "Reflection Color",
                size: .viewportScale(1.0), pixelFormat: .rgba16Float,
                usage: [.renderTarget, .shaderRead]
            )
        )
    }

    func buildGraph(_ builder: inout RenderGraphBuilder, context _: RenderGraphBuildContext) {
        builder.addPass(
            id: "com.example.reflection.render",
            stage: .beforePostProcess,
            resources: [.texture(reflectionID, access: .renderTarget)]
        ) { context in
            guard let reflection = context.resources.texture(reflectionID) else { return }
            // Encode Metal commands targeting reflection.
        }
    }
}
```

Implement only the lifecycle hooks the feature needs — `id` and `buildGraph` are always required; `registerShaderLibraries`/`registerResources`/`registerArgumentBuffers`/`registerPipelines`/`registerComputePipelines` have no-op defaults.

**A pass must declare every extension-owned texture/buffer it touches** in `resources:` — this is how the graph schedules hazards. Texture access is `.read`/`.write`/`.renderTarget`; buffer access is `.read`/`.write`.

## 4. Register before renderer creation

```swift
setRendering(.extensions(.register(ReflectionRenderExtension())))
setRendering(.extensions(.unregister("com.example.reflection")))
setRendering(.extensions(.removeAll))
```

Registering another extension under the same `id` replaces the previous instance only if the new registration succeeds — a failed replacement leaves the old one active. For a structured result instead of the settings-API shorthand:

```swift
let result = RenderExtensionRegistry.shared.register(ReflectionRenderExtension())
let conflicts = RenderExtensionRegistry.shared.registrationConflicts(forExtensionID: "com.example.reflection")
let graphErrors = RenderExtensionRegistry.shared.graphValidationErrors(forExtensionID: "com.example.reflection")
```

## 5. Shaders and pipelines

Application-local extensions use the app's default Metal library; package plugins resolve a precompiled, per-platform metallib:

```swift
func registerShaderLibraries(_ registry: RenderShaderLibraryRegistry) {
    registry.registerDefaultLibrary("com.example.water.shaders", bundle: .main)        // app-local
    // or, inside a package target:
    registry.registerPlatformLibrary("com.example.water.shaders", bundle: .module,
                                      baseResource: "WaterShaders", subdirectory: "Shaders")
}
```

Drawing a **normal engine mesh** with a custom fragment shader uses the model-surface pipeline helper, not a raw pipeline:

```swift
func registerPipelines(_ registry: RenderPipelineRegistry) {
    registry.registerModelSurfacePipeline(
        "com.example.water.surface",
        fragmentShader: "waterFragment",
        fragmentShaderLibrary: .registered("com.example.water.shaders"),
        name: "Water Surface",
        validation: .warn(argumentLayoutID: "com.example.water.surface.arguments")
    )
}
```

Pass custom textures/samplers/buffers to a model-surface fragment shader through the **engine's extension argument buffer**, never raw Metal binding slots — register a layout (`registerArgumentBuffers`), bind per-entity values via `context.drawModelSurfaceEntities(..., bindArguments:)`, and `#include <UntoldEngineShaderSupport/UntoldModelSurface.h>` in the shader. Drawing fully custom scene geometry (not an engine mesh) uses `registerScenePipeline` + `context.sceneRenderTargets.makeRenderCommandEncoder(...)` — always `defer { encoder.endEncoding() }`.

## 6. Distributable plugins (Swift package)

Wrap one or more `RenderExtension`s in a `RenderExtensionPlugin` with a namespaced manifest ID; every extension ID the plugin supplies must equal or be prefixed by the plugin ID. Export exactly one installation function:

```swift
public func registerExampleRenderPlugin() -> RenderExtensionPluginInstallationResult {
    RenderExtensionPluginRegistry.shared.install(ExampleRenderPlugin())
}
```

Call it once at app startup, before renderer creation, and handle `.rejected`. **Don't also register the plugin's internal extension through `setRendering`** — the installation function already does that.

## 7. Checklist / common mistakes

- Register once, before renderer creation.
- Namespace every extension/plugin/pass/resource/library/pipeline/argument-layout ID.
- Add passes only at stable stages — never a private engine pass name or another plugin's pass ID.
- Declare every resource access the pass actually touches.
- Use argument buffers for model-surface data, not raw slots, on new work.
- Never register the same plugin type as both `EngineExtension` and `RenderExtension`.
- Never write a custom MTKView/render loop to "make room" for your pass — hook the graph instead.

Full reference: `docs/API/UsingRenderingExtensions.md`, `docs/API/UsingRenderingSystem.md`, `docs/Architecture/RenderingExtensions.md`, `docs/Extensions/UnderstandingRenderingExtensions.md`, `docs/Extensions/CreatingRenderingExtensionPlugin.md`.
