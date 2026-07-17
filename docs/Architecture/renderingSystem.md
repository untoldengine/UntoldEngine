# RenderingSystem — How It Works

The rendering system's job is to take the current set of visible entities and turn them into pixels on screen every frame. It does this in two distinct phases: **pre-render compute** (GPU culling and sorting) followed by **a render graph** — a dependency-ordered DAG of passes that each write into shared textures until the final image lands on the drawable.

The entry point is `UpdateRenderingSystem(in view: MTKView)`, called once per frame from the MTKView draw loop.

---

## Step 0: The Visible Entity List

Before any rendering begins, the system needs to know **which entities are visible**. This is managed through a triple-buffer called `tripleVisibleEntities`:

```swift
visibleEntityIds = tripleVisibleEntities.snapshotForRead(frame: cullFrameIndex)
```

The key insight here is that `visibleEntityIds` is **not rebuilt from scratch each frame**. It is the result of the *previous frame's* GPU frustum cull — a compute pass that ran last frame and wrote its output into the triple-buffer. The current frame reads that result and uses it immediately.

**Why triple-buffered?** The GPU may still be consuming last frame's cull output while the CPU is already preparing the next frame. Three slots prevent read/write races across overlapping frames.

**While loading:** When `AssetLoadingGate.shared.isLoadingAny` is true, the snapshot step is skipped entirely. The last-known-good `visibleEntityIds` is reused. This prevents reading from ECS storage while asset loading is mutating it on a background thread.

---

## Step 1: Command Buffer Slot Acquisition

```swift
commandBufferSemaphore.wait()
renderInfo.currentInFlightFrameSlot = acquireUniformFrameSlot()
```

The engine allows at most **3 command buffers in flight** at once (matching the triple-buffer count). The semaphore blocks the CPU if the GPU is still consuming all three slots.

`acquireUniformFrameSlot()` returns the index into the per-frame uniform buffer ring. Because the CPU writes entity transforms and camera matrices into these buffers while the GPU reads them, each in-flight frame needs its own slot to avoid corruption.

---

## Step 2: Root Transform Propagation

```swift
SceneRootTransform.shared.updateIfNeeded()
```

Before any uniforms are uploaded, dirty transforms are propagated down the scene graph. An entity whose parent moved needs its `WorldTransformComponent` updated before the model matrix is sent to the GPU. This runs lazily — only if something was marked dirty since the last frame.

---

## Step 3: Pre-Render Compute Passes

These three compute dispatches run **before any render encoder is opened**. They prepare data that the render passes will consume.

### 3a. Frustum Culling → `performFrustumCulling(commandBuffer:)`

A compute shader tests every entity's axis-aligned bounding box (`EntityAABB`) against the camera's 6 frustum planes. Entities outside the frustum are excluded.

The result is written into `tripleVisibleEntities` — **for the next frame**. So culling is always one frame behind rendering. This is an intentional latency trade-off: GPU-driven culling is far faster than CPU culling, and one frame of lag is imperceptible.

In addition to writing the GPU visibility result, `executeFrustumCulling` stores the current-frame frustum in the module-level variable `currentFrameFrustum`. This frustum is the padded, CPU-side version built from the view-projection matrix. It is read later in the same frame by the batched render passes for **cluster-level AABB culling** of `BatchGroup`s (see [G-Buffer Passes](#g-buffer-passes-tbdr) and [Shadow Passes](#shadow-passes)).

For XR, a reduce-scan variant runs the test against both eyes simultaneously.

### 3b. Gaussian Depth → `executeGaussianDepth(commandBuffer)`

For entities carrying a `GaussianComponent` (3D Gaussian splat data), a compute pass calculates the camera-space depth of each splat. This depth value is used as the sort key in the next step.

### 3c. Bitonic Sort → `executeBitonicSort(commandBuffer)`

A GPU bitonic sort reorders the Gaussian splats **back-to-front** by depth. Gaussian splats must be composited in this order for correct alpha blending. The sort runs entirely on the GPU and its output feeds directly into the Gaussian render pass later in the graph.

---

## Step 4: Building the Render Graph → `buildGameModeGraph()`

Rather than hard-coding a linear sequence of passes, the engine constructs a **directed acyclic graph (DAG)** of `RenderPass` nodes each frame:

```swift
struct RenderPass {
    let id: String
    var dependencies: [String]
    var execute: (MTLCommandBuffer) -> Void
}
```

Each engine pass declares which other passes must complete before it can run.
Before encoding, `buildExecutableGameModeGraph()` validates and compiles the
mutable builder output into an immutable `CompiledRenderGraph` with one
deterministic execution order. Frame encoding walks that snapshot rather than
sorting or reinterpreting mutable graph state.

Rendering Extensions contribute owner-scoped passes through stable stage anchors
before this compilation step. Their registration lifecycle, plugin transactions,
resource validation, hazard scheduling, argument-buffer isolation, lifetime
planning, and failure recovery are documented separately in
[Rendering Extensions Architecture](RenderingExtensions.md).

The full graph for a typical frame looks like this:

```
environment/grid
    └── shadow
            └── batchedShadow
                    └── model ──────────────────────────── gaussian
                            └── batchedModel                    │
                                    └── hzbDepthSource          │
                                            └── ssao            │
                                                    └── lightPass
                                                            └── transparency
                                                                    └── wireframe
                                                                            └── spatialDebug
                                                                                    └── [post-processing chain]
                                                                                                └── precomp ◄── (gaussian joins here)
                                                                                                        └── look
                                                                                                                └── [aa: fxaa / smaa×3 / none]
                                                                                                                            └── outputTransform
```

### Base Pass (environment or grid)

The graph always starts with a background pass whose type depends on the platform and rendering mode:

| Context | Pass | Purpose |
|---|---|---|
| macOS/iOS with HDR sky | `environment` | Renders the IBL skybox cubemap |
| macOS/iOS without HDR | `grid` | Renders the editor debug grid |
| XR passthrough (mixed) | *(none)* | Camera feed is the background |
| XR full immersion | `environment` | Skybox inside the headset |

This pass has **no dependencies** — it is always the root of the graph.

### Shadow Passes

```
shadow → batchedShadow
```

Both passes render scene geometry from the **directional light's point of view** into a shadow map depth texture. No color is written — only depth. The renderer checks `entityToBatch` and routes each entity to the appropriate pass:
- Regular entities → `shadowExecution`
- Batched entities → `batchedShadowExecution`

`batchedShadowExecution` uses **cluster-level frustum culling**: it calls `visibleBatchGroupsSnapshot()` which tests each `BatchGroup`'s precomputed world-space AABB against `currentFrameFrustum`. Only groups whose AABB intersects the frustum are submitted. This replaces the previous entity→batchId derivation and operates at batch-group granularity — one AABB test per group instead of one per entity.

**Cascaded Shadow Maps (CSM):** The shadow pass runs once per cascade (`csmCascadeCount`, default **2** for indoor scenes). Each cascade covers a sub-frustum slice of the camera's view:

- **Cascade 0** — near field (highest resolution)
- **Cascade 1** — far field (lower resolution, wider coverage)

The cascade count is 2 by default. Raise to 3 in `Globals.swift` for outdoor scenes that need a third far cascade beyond 40 m.

**Per-cascade shadow distance:** Each cascade only receives shadow casters within its own split distance (`shadowCascadeMaxDistance`). The effective limit is `min(maxShadowCastingDistance, cascadeSplitDistances[cascadeIdx])`. This prevents the near cascade from rendering distant objects that are only relevant to the far cascade, significantly reducing shadow draw calls in dense scenes.

The shadow map produced here is consumed by the TBDR light sub-pass inside `model`.

### G-Buffer Passes (TBDR)

```
model → batchedModel → hzbDepthSource → ssao → lightPass
```

This is the core of the tile-based deferred rendering (TBDR) pipeline. Opaque geometry and lighting are encoded inside one Metal render encoder through `combinedModelLightExecution`. Geometry first writes raw surface data into G-Buffer attachments:

- **Albedo** — base color
- **Normal** — world-space surface normal
- **World position** — world-space fragment position
- **Material** — roughness, metalness, emissive flags
- **Emissive** — emissive contribution data

Attachments 0-4 are memoryless G-Buffer targets. They stay in tile memory and are not stored as full-screen textures during normal lit rendering. Attachment 5 is the lit scene-color target.

Inside `combinedModelLightExecution`, the unbatched model phase iterates `visibleEntityIds`. For each entity that is not batched:
- Binds vertex/index buffers
- Uploads the model matrix, normal matrix, and camera uniforms into the current in-flight frame slot
- Issues a draw call per mesh submesh

Before encoding each draw, the renderer checks scene-channel visibility. Individual entities use `shouldHideSceneEntity(entityId:)`; batch groups use their stored channel mask. Hidden channels are skipped entirely rather than rendered transparently.

The batched opaque phase uses **cluster-level frustum culling**: it calls `visibleBatchGroupsSnapshot()` which tests each `BatchGroup`'s precomputed world-space AABB against `currentFrameFrustum` using `isAABBInFrustum`, then filters by scene-channel visibility. The result — groups whose AABB intersects the frustum and whose channels are visible — is cached for the frame and shared with later batch-aware passes. Opaque groups are submitted as a single draw call with their merged vertex and index buffers.

After the opaque draws finish, the light sub-pass runs a full-screen quad with `fragmentLightShaderTBDR`. The shader reads the G-Buffer attachments with framebuffer fetch (`[[color(N)]]`) and writes the lit result into attachment 5. Shadow maps and IBL lookup textures still come from normal Metal texture bindings, but albedo, normals, position, material, and emissive data are consumed directly from tile memory.

`hzbDepthSource` copies the opaque depth after all opaque geometry has been written. That stored depth texture feeds both the next-frame HZB build and the SSAO pass.

`ssaoOptimizedExecution` is now depth-only. It samples the stored opaque depth texture, produces a screen-space ambient occlusion texture, and handles the blur chain internally — no separate blur nodes appear in the graph. Because the TBDR light sub-pass already ran while the G-Buffer was live in tile memory, SSAO is applied later during `precomp` instead of inside `fragmentLightShaderTBDR`.

The graph still contains a `batchedModel` node and a `lightPass` node for dependency compatibility with transparency, post-processing, and tests. In the TBDR path both are ordering nodes: batched opaque geometry and lighting work already happened inside `model`, and `lightPass` waits for `ssao` so downstream passes see a stable ordering.

> **Why deferred?** Deferred rendering means the lighting cost scales with the number of lit pixels, not the number of geometry draw calls × number of lights. Complex scenes with many overlapping objects benefit greatly because each pixel is only shaded once, regardless of how many triangles projected onto it.

> **Why TBDR?** Keeping the G-Buffer in tile memory avoids storing and reloading several full-resolution render targets every frame. This is especially important on Apple GPUs, where framebuffer fetch and memoryless attachments let the renderer shade from G-Buffer data while it is still resident on the tile.

### Transparency Pass

```swift
RenderPass(id: "transparency", dependencies: ["lightPass"])
```

Transparent materials cannot go through the G-Buffer — they require alpha blending which deferred rendering cannot express per-fragment. These entities are rendered **forward** in a separate pass on top of the deferred lit scene color. They depend on `lightPass` being complete so they composite correctly against the opaque scene.

### Wireframe Pass

```swift
RenderPass(id: "wireframe", dependencies: ["transparency"])
```

Scene channels using `.wireframe` are skipped by the solid opaque and shadow passes, then redrawn here. Exported `.untold` meshes can carry architectural edge index buffers; the pass draws those as line primitives for a cleaner outline-style result. If a mesh or batch group does not have architectural edge data, the pass falls back to Metal triangle line fill mode using the normal mesh or batch index buffers.

The line shader supports distance fade through `WireframeRenderParams`, which reduces distant line opacity for large architectural scenes.

### Spatial Debug Pass

```swift
RenderPass(id: "spatialDebug", dependencies: ["wireframe"])
```

Draws wireframe AABB overlays for debug purposes. Runs last in the geometry chain so it draws on top of everything.

### Gaussian Pass

```swift
RenderPass(id: "gaussian", dependencies: ["model"])
```

Renders the back-to-front-sorted Gaussian splats using the indices produced by the bitonic sort. This pass **depends on "model"** because it needs the depth buffer that was populated during the G-Buffer model pass — splats use that depth to correctly composite against solid geometry.

Note that Gaussian **does not** depend on `lightPass`, `transparency`, or the post-processing chain. It runs in parallel with those in the dependency graph and merges back at `precomp`.

### Post-Processing Chain

```
spatialDebug → depthOfField → chromatic → bloomThreshold
    → blur_hor_1 → blur_ver_1 → blur_hor_2 → blur_ver_2
    → blur_hor_3 → blur_ver_3 → blur_hor_4 → blur_ver_4
    → bloomComposite → vignette
```

`postProcessingEffects()` builds this chain dynamically inside `buildGameModeGraph()`. Each effect reads from the previous pass's output texture and writes to its own.

**Fast path:** If every effect (`BloomThresholdParams`, `VignetteParams`, `ChromaticAberrationParams`, `DepthOfFieldParams`) is disabled, the entire chain is replaced by a single bypass pass that points the post-process descriptor at the deferred output texture directly. This avoids allocating ~142 MB of intermediate render targets that would be unused.

The number of blur iterations is driven by `BloomThresholdParams.shared.enabled` — when bloom is on, **four** horizontal/vertical pairs are dispatched using a 9-tap Gaussian kernel (radius 6); when off, zero. The loop that generates blur nodes in the graph is:

```swift
let blurPassCount = BloomThresholdParams.shared.enabled ? 4 : 0
for i in 0 ..< blurPassCount {
    // horizontal blur pass  (blur_pass_hor_pass{i+1})
    // vertical blur pass    (blur_pass_ver_pass{i+1})
}
```

So the graph topology literally changes based on whether bloom is enabled — from 0 blur nodes (disabled) to 8 blur nodes (4 hor + 4 ver, when enabled).

### Pre-Composite Pass

```swift
RenderPass(id: "precomp", dependencies: [postProcessID, gaussianPass.id])
```

This is the **convergence point** of the two parallel tracks. The post-processed scene color and the Gaussian splat render both arrive here and are composited into a single texture. This pass also applies the blurred depth-only SSAO texture to the lit scene color when SSAO is enabled. Neither track can be finalized without the other.

### Look Pass (Color Grading / G-Buffer Debug)

```swift
RenderPass(id: "look", dependencies: ["precomp"])
```

In normal rendering (`renderDebugViewMode == .lit`), applies exposure, lift/gamma/gain color correction, and optional color grading to the composited image.

When `renderDebugViewMode` is set to a G-Buffer visualization mode, the renderer stores the requested debug target and the look pass reads from that texture instead of the color-graded composite:

| `renderDebugViewMode` | Look pass source |
|---|---|
| `.lit`, `.fxaaEdgeDebug`, `.smaaEdges`, `.smaaBlend`, `.smaaDifference` | Color-graded composite (`sceneCompositeTexture`) |
| `.albedo` | G-Buffer albedo texture |
| `.normal` | G-Buffer normal texture |
| `.position` | G-Buffer world-position texture |
| `.depth` | Depth buffer (linearized, visualized as grayscale) |
| `.ssaoBlurred` | SSAO blur result texture |

The look texture is always the output — downstream passes (anti-aliasing, output transform) read from it regardless of which path ran.

### Anti-Aliasing Pass

After the look pass, the graph inserts an anti-aliasing pass whose topology depends on `antiAliasingMode`:

| `antiAliasingMode` | Passes added | Graph edges |
|---|---|---|
| `.fxaa` | `fxaa` | `look → fxaa → outputTransform` |
| `.smaa` | `smaaEdges`, `smaaBlendWeights`, `smaaNeighborhood` | `look → smaaEdges → smaaBlendWeights → smaaNeighborhood → outputTransform` |
| `.none` | *(none)* | `look → outputTransform` |

**FXAA** is a single-pass screen-space filter that attenuates aliased edges using local luma contrast.

**SMAA** (Subpixel Morphological Anti-Aliasing) is a three-pass chain:
1. **Edge detection** (`smaaEdges`) — identifies aliased edges from the look texture using luma and chroma gradients. Also detects diagonal patterns.
2. **Blend-weight calculation** (`smaaBlendWeights`) — computes per-pixel blend weights from the SMAA area and search look-up textures, accounting for corner patterns.
3. **Neighborhood blending** (`smaaNeighborhood`) — applies the blend weights to the look texture, producing the final anti-aliased image in `antiAliasingTexture`.

Both FXAA and SMAA write their result into `antiAliasingTexture`. The `outputTransform` pass reads from this texture when AA is active, or directly from `lookTexture` when `antiAliasingMode == .none`.

> **Debug views that expose AA internals:**
> - `renderDebugViewMode = .fxaaEdgeDebug` — shows the luma-gradient edge map computed by FXAA
> - `renderDebugViewMode = .smaaEdges` — shows the edge detection output (stops before blend weights)
> - `renderDebugViewMode = .smaaBlend` — shows the blend-weight texture (stops before neighborhood blend)
> - `renderDebugViewMode = .smaaDifference` — shows the difference between the original and SMAA-resolved image

### Output Transform Pass

```swift
RenderPass(id: "outputTransform", dependencies: [antiAliasingPassId])
```

Tone maps the HDR scene color into the display's color space (SDR or EDR depending on the target). This is the **terminal node** of the graph. Its source texture is `antiAliasingTexture` when AA is active, or `lookTexture` when `antiAliasingMode == .none`.

---

## Step 5: Graph Execution

With the graph assembled, the engine sorts and executes it:

```swift
let sortedPasses = try! topologicalSortGraph(graph: graph)
executeGraph(graph, sortedPasses, commandBuffer)
```

`topologicalSortGraph` performs a depth-first search over the dependency edges and returns a `[String]` of pass IDs in a valid execution order — every pass appears after all its dependencies.

`executeGraph` iterates that list and calls each pass's `execute` closure, encoding Metal render or compute commands into the shared `commandBuffer`. All passes share one command buffer, so Metal can pipeline them efficiently on the GPU.

---

## Step 6: HZB Depth Pyramid

```swift
buildHZBDepthPyramid(commandBuffer)
```

After the render graph finishes, the stored opaque depth source captured by `hzbDepthSource` is downsampled into a **hierarchical Z-buffer** mip pyramid. This feeds **next frame's** occlusion culling — a coarse depth mip level can quickly reject large occluded objects before the fine cull.

This is intentionally scheduled here, after the render graph and before `commit()`, so the HZB is built from the freshest depth available and ready for the next frame's culling compute dispatch.

---

## Step 7: Present and Commit

```swift
commandBuffer.present(drawable)
commandBuffer.commit()
```

The completion handler fires on the GPU thread when the command buffer finishes executing:

- `commandBufferSemaphore.signal()` — frees one slot, allowing the CPU to encode the next frame
- `needsFinalizeDestroys = true` — deferred ECS entity removal can proceed safely now that the GPU is done with this frame's data
- `MemoryBudgetManager.shared.markUsed(entityIds:)` — records which entities were rendered so the memory budget manager knows what to keep resident and what to evict

---

## The Full Frame in One Picture

```
[CPU] snapshotVisibleEntities (from last frame's cull)
[CPU] wait on semaphore / acquire uniform slot
[CPU] propagate dirty transforms
        │
        ▼
[GPU compute] frustumCulling   → writes next frame's visibleEntityIds
[GPU compute] gaussianDepth    → depth per splat
[GPU compute] bitonicSort      → sort splats back-to-front
        │
        ▼
[CPU] buildGameModeGraph()     → construct render pass DAG
[CPU] topologicalSortGraph()   → linearize pass order
        │
        ▼
[GPU render] environment/grid
[GPU render] shadow + batchedShadow   (depth from light POV)
[GPU render] model                    (opaque + batched geometry → memoryless G-Buffer, then TBDR lighting)
[GPU render] hzbDepthSource           (copy opaque depth for HZB/SSAO)
[GPU render] ssao                     (depth-only occlusion)
[GPU render] lightPass                (ordering stub; lighting already ran in model)
[GPU render] transparency             (forward-rendered alphas)
[GPU render] spatialDebug             (debug overlays)
[GPU render] gaussian                 (sorted splats)
[GPU render] post-processing chain    (DOF, bloom, vignette)
[GPU render] precomp                  (merge scene + splats)
[GPU render] look                     (color grading / G-Buffer debug)
[GPU render] anti-aliasing            (FXAA / SMAA 3-pass / skipped for .none)
[GPU render] outputTransform          (tone map → drawable)
[GPU compute] buildHZB                (depth pyramid for next frame)
        │
        ▼
[CPU] present drawable + commit
[GPU→CPU callback] signal semaphore, mark memory used
```

---

## Why a Render Graph Instead of a Fixed Pass Order?

A fixed sequence of `if` statements works fine until the graph needs to change — when post-processing is disabled, when XR changes the base pass, or when the number of bloom blur iterations varies based on settings. A render graph makes these variations **declarative**: each pass states what it needs, and the topology sorts itself. Adding a new pass means adding one `RenderPass` node with its dependency list — the rest of the system adapts automatically.

It also makes the dependency structure explicit and auditable. If a pass reads a texture produced by another pass, that relationship is encoded as a graph edge rather than buried in execution order assumptions.
