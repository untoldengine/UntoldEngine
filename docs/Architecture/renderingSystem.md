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

These four compute dispatches run **before any render encoder is opened**. They prepare data that the render passes will consume.

### 3a. Frustum Culling → `performFrustumCulling(commandBuffer:)`

A compute shader tests every entity's axis-aligned bounding box (`EntityAABB`) against the camera's 6 frustum planes. Entities outside the frustum are excluded.

The result is written into `tripleVisibleEntities` — **for the next frame**. So culling is always one frame behind rendering. This is an intentional latency trade-off: GPU-driven culling is far faster than CPU culling, and one frame of lag is imperceptible.

In addition to writing the GPU visibility result, `executeFrustumCulling` stores the current-frame frustum in the module-level variable `currentFrameFrustum`. This frustum is the padded, CPU-side version built from the view-projection matrix. It is read later in the same frame by the batched render passes for **cluster-level AABB culling** of `BatchGroup`s (see [G-Buffer Passes](#g-buffer-passes-tbdr) and [Shadow Passes](#shadow-passes)).

For XR, a reduce-scan variant runs the test against both eyes simultaneously.

### 3b. Gaussian Frustum Culling → `executeGaussianFrustumCulling(commandBuffer)`

For entities carrying a `GaussianComponent` (3D Gaussian splat data), a compute pass culls splats against the camera frustum (and the previous frame's HZB) before the more expensive depth and sort passes run on them. Surviving splat indices are appended to a per-frame list with an atomic counter.

That counter lives at the front of a `GaussianVisibleSet` record (`ShaderTypes.h`), one per entity per in-flight frame. A one-thread `gaussianFinalizeVisibleSet` dispatch in the same encoder turns the final count into indirect dispatch and draw arguments, and every later pass of the frame — preprocess, radix sort and the splat draw — sizes itself from that record on the GPU. The CPU also reads the count back when the command buffer completes, but only for profiling and memory-budget accounting: with `maxInFlightCommandBuffers` frames overlapping, that readback is two or three frames old, and sizing the passes from it used to cut the tail of a visible list that had grown since (a hole that followed the camera and closed once it stood still).

**Chunk level first for `.untoldgs` entities.** A baked asset keeps its chunk table from the load (`GaussianChunkTable`: the 48-byte `GaussianChunkDecodeConstants` per chunk — centre AABB, log-scale range, first splat and count — plus the CPU-side `UntoldGSIndex`) and its 16-byte core records (`GaussianComponent.packedSplatData`), and nothing else per splat: no 48-byte encoded buffer and no per-slot visible-index buffers exist for it. Its cull runs on the same serial encoder as the whole-buffer entities' (`GaussianChunkCull.metal`, `GaussianWorkingSetBudget.metal`):

1. `gaussianChunkCull`, one thread per chunk, tests the chunk's centre AABB padded on every side by `kGaussianQuadSigma · exp(logScaleMax)` — the farthest the largest splat in the chunk can reach, so the box holds every rendered quad — against the same guard-banded clip volume the per-splat test uses (|x|, |y| ≤ w·1.25, −0.25·w ≤ z ≤ 1.25·w, w > 0). The box is rejected only when all eight corners lie beyond one plane, so a chunk containing any splat the per-splat test keeps always survives: the chunk stage can only remove work, never splats. When the previous frame's HZB is valid it also runs the mesh cull's occlusion test on the box (`HZBOcclusion.h`, shared with `hzbCullVisibleEntities`: projected rect, the mip whose texel covers it, 5×5 samples, 0.02 bias). Survivors are appended to a per-entity, per-in-flight-slot visible-chunk list (`GaussianVisibleChunk`: chunk index, splat count, quota) whose `GaussianVisibleSet`-shaped record `gaussianFinalizeVisibleChunks` completes — `threadgroupsPerGrid.x` the visible chunk count, `instanceCount` the visible chunks' splat total — and adds that total to the frame's `GaussianBudgetState.requestedSplats`.
2. **Budget and quotas**, once every entity's request is in. The shared working set is sized to a budget rather than to the resident total (`GaussianRuntimeLimits.workingSetSplats`, 1 M splats on visionOS/iOS/tvOS and 6 M on macOS, clamped so 3 × 72 B × budget stays within a quarter of `MemoryBudgetManager.geometryBudget`, overridable through `workingSetSplatsOverride`; `GaussianSharedWorkingSet.fitCapacity` never allocates more than the resident total, never less than the whole-buffer entities' resident total, and shrinks only when the budget itself drops — a change of capacity also forgets every in-flight slot's entity order, so a frame that reuses a stale slot behind the asset-loading gate does not draw an old count over the new buffers). Whole-buffer entities are not budgeted: each one's `gaussianFinalizeVisibleSet` is followed by `gaussianReserveBudgetSplats`, which adds its visible count to `GaussianBudgetState.reservedSplats`. `gaussianComputeBudgetScale` (one thread) then fits the chunked request to what is left — the target is 1 while `requested ≤ 0.98 × capacity − reserved`, else that room over the request, 0 when nothing is left — and applies the hysteresis against the previous frame's scale, kept in one persistent `GaussianBudgetState` buffer: a fall is taken at once (the set is already at its capacity, and a scale lagging above its target would grant more than the set holds and drop splats by arrival order for several frames), a rise is limited to max(10 % of the previous scale, 0.05) per frame, so a budget boundary never flickers and a climb from a quarter takes about fifteen frames. A frame that found no splat entity flags the state so the next frame with some takes its target as a first frame would (`GaussianSharedWorkingSet.noteFrameWithoutEntities`). `gaussianComputeChunkQuotas` (one threadgroup per entity, striding over its visible chunks) then grants each chunk `quota = floor(scale × splatCount)`, writes it into the visible-chunk entry and the quota sum into the record's `visibleCount`; because the bake orders every chunk by importance, a quota is a continuous per-chunk level of detail. Floor rather than ceil keeps the frame's quota sum at or below 98 % of the capacity less the reservation whatever the chunk size, so the fused pass cannot overflow the set; the finalize clamp of §3c stays as the safety net and any overflow it records is reported. `gaussianPublishBudgetState` copies the state into the frame's in-flight slot for the CPU readback (`GaussianSharedWorkingSet.lastBudgetState`, the profile line, tests). `GaussianDebugOptions.shared.disableWorkingSetBudget` sizes the set to the resident total and grants every chunk its whole count.

In a stereo frame the chunk test uses both eyes: each eye's view-projection is rebuilt at prep time from the raw per-eye view and projection `renderXR` last received (`renderInfo.xrEye0/1View`, `xrEye0/1Projection`) with the scene root of the frame being culled — not the composed `xrEye0/1ViewProjection` the mesh HZB cull reads, which carries the root of the frame that drew it and would test a different frustum than the per-splat pass on a frame the root moved (recentre, pinch-drag). A chunk is visible when **either** eye keeps it, and the fused pass of §3c tests each splat against the same two matrices, so a splat only one eye sees is drawn where the whole-buffer path culls it against the head-centre view. The HZB is the mono pyramid built from the last eye rendered (eye 1), so only eye 1's test — chunk and splat — samples it; eye 0's clip test alone decides for eye 0, else a splat in eye 0's margin would be tested against depth the other eye saw a few centimetres to the side. `GaussianDebugOptions.shared.disableChunkCull` appends every chunk (the fused pass then walks the whole asset through the same indirect path) for A/B runs. Entities without a chunk table — `.ply` files, `.untoldgs` decoded on the CPU or loaded while the per-chunk kernels were unavailable — keep the whole-buffer `gaussianFrustumCull` over their encoded buffer.

### 3c. Gaussian Preprocess → `executeGaussianPreprocess(commandBuffer)`

One dispatch per entity compacts the surviving splats into the frame's **shared working set** (`GaussianSharedWorkingSet`, one set per frame in flight, shared by every entity): for each splat it computes the screen footprint (conic and quad axes) and the colour (spherical harmonics for the head-centre view) once, appends a `GaussianWorkingSetSplat` record that also carries the entity index, and writes a depth key — eye-space depth of the centre in the high word, the record's slot in the low word. Two kernels do this:

- A whole-buffer entity runs `gaussianPreprocess`, one thread per entry of its cull list, indirect from its `GaussianVisibleSet`, reading its encoded buffer.
- A chunked entity runs the fused `gaussianChunkDecodePreprocess` (`GaussianChunkPreprocess.metal`): one threadgroup per visible chunk, indirect from its chunk record, threads = min(splats per chunk, `maxTotalThreadsPerThreadgroup`), each thread striding over the chunk's ranks `0 ..< quota`. For every rank it unpacks the 16-byte record with the chunk's constants exactly as the load-time `gaussianDecodeChunks` does (position, smallest-three rotation → covariance, log-scale, rgba; covariance and colour pass through half precision like `EncodedGaussianSplat`, so the numbers are the whole-buffer path's), runs the per-splat test — the whole-buffer kernel's arithmetic in mono, either eye's view-projection in stereo, with the HZB for eye 1 only — evaluates the spherical harmonics by original splat index, then projects and appends exactly as `gaussianPreprocess`. The **opacity band** keeps a moving cut from popping: in a truncated chunk (quota below the splat count) the ranks from 0.8 × quota up to the quota have their opacity scaled linearly from 1 down to one step above zero, so the splats a shrinking quota drops next are already nearly transparent. A chunk kept whole has no band. Because the pass reads at most `quota` records per chunk, the quotas are fitted below the capacity less the whole-buffer reservation, and the scale never lags above its target, the atomic slot reservation stays within the capacity.

A one-thread finalize clamps the shared count to the set's capacity, records any overflow, and derives the indirect arguments for the sort and the draw. The overflow is reported through `handleError` once per change.

### 3d. Radix Sort → `executeRadixSort(commandBuffer)`

One GPU radix sort over the shared key buffer orders every entity's splats **front-to-back** by depth, so overlapping entities blend in true depth order rather than entity order. The sort runs entirely on the GPU, sized by the shared count, and its output feeds the single instanced splat draw later in the graph: the vertex stage reads each key's record and projects its centre with a per-entity, per-eye matrix table (`GaussianEntityDrawConstants`), which is what lets one sort and one working set serve both eyes of a stereo frame.

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
                    └── pointShadow
                            └── spotShadow
                                    └── model ───────────────────── gaussian
                                    └── batchedModel                    │
                                            └── meshOccluderShell ──────┤
                                                    └── hzbDepthSource  │
                                                            └── ssao    │
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
shadow → batchedShadow → pointShadow → spotShadow
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

**Shadow softness:** CSM sampling uses a centered 16-tap Poisson PCF kernel. The default runtime softness is `nearRadiusTexels = 2.0`, `farRadiusTexels = 5.0`, with an `xrRadiusScale = 1.35` applied only in stereo XR. Use `setShadowSoftness(_:)` to tune this globally per scene.

The shadow map produced here is consumed by the TBDR light sub-pass inside `model`.

**Point shadows:** `pointShadow` renders a cube depth map for the first point light with `castsShadow(true)`. It renders six 90-degree faces from the point light's world position and samples the cube map only for the matching point-light index. Because this costs six depth renders, the current milestone intentionally supports one active shadowed point light.

**Spot shadows:** `spotShadow` renders a single perspective depth map for the first spot light with `castsShadow(true)`. Its view comes from the spot light's position and semantic emission direction, its field of view comes from the authored outer cone, and its far plane comes from the spot light radius. The opaque light shader samples this map only for the matching spot-light index, so unshadowed spot lights continue through the normal spot-light path.

### G-Buffer Passes (TBDR)

```
model → batchedModel → meshOccluderShell → hzbDepthSource → ssao → lightPass
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

`meshOccluderShell` runs in its own encoder on the resolved opaque depth: every mesh carrying a `MeshOccluderComponent` is drawn once more depth-only, pushed along its normals away from the camera by the component's margin. A mesh whose colour is switched off (`drawsColor == false`, e.g. while a captured splat twin stands in for it) draws nothing in `model`, so this shell is what keeps its depth continuous for the HZB copy, SSAO, transparency and the splat pass's occlusion snapshot; the unshrunk mesh keeps casting shadows through the shadow passes as before. The pass encodes nothing when no entity carries the component.

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
RenderPass(id: "gaussian", dependencies: ["model", "meshOccluderShell"])
```

Renders the back-to-front-sorted Gaussian splats using the indices produced by the bitonic sort. This pass **depends on "model"** and on the occluder shells because it snapshots the depth buffer they populated — splats use that depth to correctly composite against solid geometry, and a colour-off mesh's depth only exists in its shell.

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
[GPU compute] gaussianFrustumCulling → cull splats against frustum
[GPU compute] gaussianPreprocess → compact visible splats + depth keys into the shared working set
[GPU compute] radixSort        → sort every entity's splats front-to-back
        │
        ▼
[CPU] buildGameModeGraph()     → construct render pass DAG
[CPU] topologicalSortGraph()   → linearize pass order
        │
        ▼
[GPU render] environment/grid
[GPU render] shadow + batchedShadow   (depth from light POV)
[GPU render] model                    (opaque + batched geometry → memoryless G-Buffer, then TBDR lighting)
[GPU render] meshOccluderShell        (depth-only shrunk shells, MeshOccluderComponent)
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
