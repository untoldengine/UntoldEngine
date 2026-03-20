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

Each pass declares which other passes must complete before it can run. `buildGameModeGraph()` assembles these nodes into a dictionary and returns it. Nothing executes yet — this is purely declarative.

The full graph for a typical frame looks like this:

```
environment/grid
    └── shadow
            └── batchedShadow
                    └── model ──────────────────────────── gaussian
                            └── batchedModel                    │
                                    ├── ssao                    │
                                    └── lightPass               │
                                            └── transparency    │
                                                    └── spatialDebug
                                                            └── [post-processing chain]
                                                                        └── precomp ◄── (gaussian joins here)
                                                                                └── look
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

The shadow map produced here is consumed later by `lightPass`.

### G-Buffer Passes (deferred rendering)

```
model → batchedModel → ssao → lightPass
```

This is the core of the deferred rendering pipeline. Entities do not produce a shaded color here — they write raw surface data into multiple render targets (the G-Buffer):

- **Albedo** — base color
- **Normal** — world-space surface normal
- **World position** — reconstructed from depth
- **Material** — roughness, metalness, emissive flags

`modelExecution` iterates `visibleEntityIds`. For each entity that is not batched:
- Binds vertex/index buffers
- Uploads the model matrix, normal matrix, and camera uniforms into the current in-flight frame slot
- Issues a draw call per mesh submesh

`batchedModelExecution` follows the same logic for entities managed by the `BatchingSystem`, using merged buffers instead of per-entity ones.

`ssaoOptimizedExecution` reads the G-Buffer normals and depth and produces a screen-space ambient occlusion texture. Blurring is handled internally — no separate blur nodes appear in the graph.

`lightExecution` is where the entity **first appears fully lit**. It reads all four G-Buffer textures plus the shadow map and SSAO texture and combines them into a single HDR scene color texture using the deferred lighting algorithm. This is a full-screen quad pass — geometry is never touched again after the G-Buffer step.

> **Why deferred?** Deferred rendering means the lighting cost scales with the number of lit pixels, not the number of geometry draw calls × number of lights. Complex scenes with many overlapping objects benefit greatly because each pixel is only shaded once, regardless of how many triangles projected onto it.

### Transparency Pass

```swift
RenderPass(id: "transparency", dependencies: ["lightPass"])
```

Transparent materials cannot go through the G-Buffer — they require alpha blending which deferred rendering cannot express per-fragment. These entities are rendered **forward** in a separate pass on top of the deferred lit scene color. They depend on `lightPass` being complete so they composite correctly against the opaque scene.

### Spatial Debug Pass

```swift
RenderPass(id: "spatialDebug", dependencies: ["transparency"])
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
    → bloomComposite → vignette
```

`postProcessingEffects()` builds this chain dynamically inside `buildGameModeGraph()`. Each effect reads from the previous pass's output texture and writes to its own.

**Fast path:** If every effect (`BloomThresholdParams`, `VignetteParams`, `ChromaticAberrationParams`, `DepthOfFieldParams`) is disabled, the entire chain is replaced by a single bypass pass that points the post-process descriptor at the deferred output texture directly. This avoids allocating ~142 MB of intermediate render targets that would be unused.

The number of blur iterations is driven by `BloomThresholdParams.shared.enabled` — when bloom is on, two horizontal/vertical pairs are dispatched; when off, zero. The loop that generates blur nodes in the graph is:

```swift
for i in 0 ..< blurPassCount {
    // horizontal blur pass
    // vertical blur pass
}
```

So the graph topology literally changes based on whether bloom is enabled.

### Pre-Composite Pass

```swift
RenderPass(id: "precomp", dependencies: [postProcessID, gaussianPass.id])
```

This is the **convergence point** of the two parallel tracks. The post-processed scene color and the Gaussian splat render both arrive here and are composited into a single texture. Neither track can be finalized without the other.

### Look Pass (Color Grading)

```swift
RenderPass(id: "look", dependencies: ["precomp"])
```

Applies lift/gamma/gain color correction and optional LUT-based grading to the composited image.

### Output Transform Pass

```swift
RenderPass(id: "outputTransform", dependencies: ["look"])
```

Tone maps the HDR scene color into the display's color space (SDR or EDR depending on the target). This is the **terminal node** of the graph — its output texture is what gets presented to the drawable.

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

After the render graph finishes, the depth texture produced during the G-Buffer model pass is downsampled into a **hierarchical Z-buffer** mip pyramid. This feeds **next frame's** occlusion culling — a coarse depth mip level can quickly reject large occluded objects before the fine cull.

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
[GPU render] model + batchedModel     (entity → G-Buffer)
[GPU render] ssao                     (occlusion from G-Buffer)
[GPU render] lightPass                (entity appears fully lit)
[GPU render] transparency             (forward-rendered alphas)
[GPU render] spatialDebug             (debug overlays)
[GPU render] gaussian                 (sorted splats)
[GPU render] post-processing chain    (DOF, bloom, vignette)
[GPU render] precomp                  (merge scene + splats)
[GPU render] look                     (color grading)
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
